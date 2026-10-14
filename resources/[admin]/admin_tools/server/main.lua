--[[
    admin_tools/server/main.lua
    Rechten: ESX-groep van de speler (xPlayer.getGroup()) → niveau uit ServerCfg.Admin.groups.
    De server controleert ELKE actie opnieuw; het adminmenu aan clientzijde is alleen een UI.
]]

local A = ServerCfg.Admin
local last = {}

local function throttle(src, key, ms)
    local id = src .. ':' .. key
    local now = GetGameTimer()
    if (last[id] or -1e9) + ms > now then return false end
    last[id] = now
    return true
end

---------------------------------------------------------------------------
-- Rechten
---------------------------------------------------------------------------
local function level(src)
    if src == 0 then return 99 end -- serverconsole
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return 0 end
    return A.groups[xPlayer.getGroup()] or 0
end

local function has(src, action)
    return level(src) >= (A.levels[action] or 99)
end

exports('IsAdmin', function(src, action) return has(src, action or 'menu') end)

local function say(src, kind, key, ...)
    if src == 0 then
        print(('[admin_tools] %s'):format(ServerCfg.T(key, ...)))
    else
        ServerCfg.Notify(src, kind, key, ...)
    end
end

local function describe(src)
    if src == 0 then return 'Console' end
    return exports.server_logs:Describe(src)
end

local function adminName(src)
    if src == 0 then return 'Console' end
    local x = ESX.GetPlayerFromId(src)
    return x and x.getName() or GetPlayerName(src) or ('#' .. src)
end

---------------------------------------------------------------------------
-- Identifiers
---------------------------------------------------------------------------
local function identifiersOf(src)
    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        local kind = id:match('^(%a+):')
        if kind == 'license' or kind == 'discord' or kind == 'fivem' or kind == 'steam' then ids[kind] = id end
    end
    return ids
end

local function target(src, arg)
    local id = tonumber(arg)
    if not id or not GetPlayerName(id) then
        say(src, 'error', 'admin.no_player')
        return nil
    end
    return id
end

---------------------------------------------------------------------------
-- Acties
---------------------------------------------------------------------------
local function cleanReason(reason)
    reason = ServerCfg.Trim(tostring(reason or ''))
    reason = reason:gsub('%c', ' ')
    if reason == '' then reason = ServerCfg.T('admin.default_reason') end
    return reason:sub(1, A.reasonMaxLength)
end

local function doKick(src, tid, reason)
    reason = cleanReason(reason)
    local who = describe(tid)
    DropPlayer(tid, ServerCfg.T('admin.kicked_msg', reason))
    exports.server_logs:Log('admin', 'Kick', ('%s kickte %s – %s'):format(describe(src), who, reason))
    say(src, 'success', 'admin.kicked', who)
end

local function parseDuration(text)
    text = tostring(text or ''):lower()
    if text == 'perm' or text == 'permanent' then return 0 end
    local n, unit = text:match('^(%d+)([mhd])$')
    n = tonumber(n)
    if not n or n < 1 then return nil end
    if unit == 'm' then return n / 60 end
    if unit == 'h' then return n end
    return n * 24
end

local function doBan(src, tid, hours, reason)
    reason = cleanReason(reason)
    if hours == 0 and level(src) < A.permBanLevel then
        say(src, 'error', 'admin.perm_not_allowed')
        return
    end
    if hours > A.maxBanHours then hours = A.maxBanHours end

    local ids = identifiersOf(tid)
    if not ids.license then say(src, 'error', 'admin.no_license') return end
    local name = GetPlayerName(tid) or '?'
    local by = adminName(src)

    local id
    if hours == 0 then
        id = MySQL.insert.await(
            'INSERT INTO admin_bans (license, discord, fivem, steam, name, reason, banned_by, expires_at, active) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 1)',
            { ids.license, ids.discord or '', ids.fivem or '', ids.steam or '', name, reason, by })
    else
        id = MySQL.insert.await(
            'INSERT INTO admin_bans (license, discord, fivem, steam, name, reason, banned_by, expires_at, active) VALUES (?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), 1)',
            { ids.license, ids.discord or '', ids.fivem or '', ids.steam or '', name, reason, by, os.time() + math.floor(hours * 3600) })
    end
    local duration = hours == 0 and ServerCfg.T('admin.permanent') or ServerCfg.T('admin.hours', hours)
    DropPlayer(tid, ServerCfg.T('admin.banned_msg', reason, duration, id or 0))
    exports.server_logs:Log('admin', 'Ban', ('%s verbande %s (%s) – %s [ban #%s]'):format(describe(src), name, duration, reason, tostring(id)))
    say(src, 'success', 'admin.banned', name, tostring(id))
end

local function doWarn(src, tid, reason)
    reason = cleanReason(reason)
    local ids = identifiersOf(tid)
    if not ids.license then say(src, 'error', 'admin.no_license') return end
    local name = GetPlayerName(tid) or '?'
    MySQL.insert.await('INSERT INTO admin_warnings (license, name, reason, warned_by) VALUES (?, ?, ?, ?)',
        { ids.license, name, reason, adminName(src) })
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM admin_warnings WHERE license = ?', { ids.license }) or 1
    ServerCfg.Notify(tid, 'error', 'admin.warned_msg', reason, count)
    exports.server_logs:Log('admin', 'Waarschuwing', ('%s waarschuwde %s (#%d) – %s'):format(describe(src), name, count, reason))
    say(src, 'success', 'admin.warned', name, count)

    if A.warnBanThreshold > 0 and count % A.warnBanThreshold == 0 then
        doBan(0, tid, A.warnBanHours, ServerCfg.T('admin.auto_ban_reason', count))
    end
end

local function doRevive(src, tid)
    TriggerClientEvent('rp_jobs:revived', tid, 200)
    exports.server_logs:Log('admin', 'Admin revive', ('%s reanimeerde %s'):format(describe(src), describe(tid)))
    say(src, 'success', 'admin.revived', GetPlayerName(tid))
end

local function doGoto(src, tid)
    if src == 0 then return end
    local c = GetEntityCoords(GetPlayerPed(tid))
    SetEntityCoords(GetPlayerPed(src), c.x, c.y, c.z, false, false, false, false)
    exports.server_logs:Log('admin', 'Teleport', ('%s ging naar %s'):format(describe(src), describe(tid)))
end

local function doBring(src, tid)
    if src == 0 then return end
    local c = GetEntityCoords(GetPlayerPed(src))
    SetEntityCoords(GetPlayerPed(tid), c.x, c.y, c.z, false, false, false, false)
    exports.server_logs:Log('admin', 'Teleport', ('%s haalde %s naar zich toe'):format(describe(src), describe(tid)))
end

local function doCombatKick(src, tid)
    local ok = false
    pcall(function() ok = exports.combat_core:ForceLeave(tid, 'combat.left_forced') end)
    exports.server_logs:Log('admin', 'Uit PvP gehaald', ('%s haalde %s uit de PvP'):format(describe(src), describe(tid)))
    say(src, ok and 'success' or 'inform', ok and 'admin.pvp_removed' or 'admin.not_in_pvp')
end

local function checkPlayer(src, tid)
    local x = ESX.GetPlayerFromId(tid)
    if not x then say(src, 'error', 'admin.no_player') return end
    local ids = identifiersOf(tid)
    local lines = {
        ('**%s** [%d]  \n'):format(x.getName(), tid),
        ('Steam/Cfx: `%s`  \nLicense: `%s`  \nDiscord: `%s`  \n'):format(ids.fivem or '-', ids.license or '-', ids.discord or '-'),
        ('Groep: %s  \nJob: %s (grade %s)  \n'):format(x.getGroup(), x.job.name, tostring(x.job.grade)),
        ('Contant: €%d • Bank: €%d • Zwart: €%d  \n'):format(x.getMoney(), x.getAccount('bank').money, (x.getAccount('black_money') or { money = 0 }).money),
    }
    local okG, gang = pcall(function() return exports.rp_gangs:GetGang(tid) end)
    if okG and gang then lines[#lines + 1] = ('Gang: %s (grade %d)  \n'):format(gang.label, gang.grade) end
    local okS, st = pcall(function() return exports.combat_stats:Get(tid) end)
    if okS and st then
        lines[#lines + 1] = ('Combat: %d kills • %d deaths • K/D %.2f • level %d • vandaag verdiend €%d  \n'):format(
            st.kills, st.deaths, st.kd, st.level, st.earned_today)
    end
    local okC, zone = pcall(function() return exports.combat_core:GetPlayerZone(tid) end)
    if okC and zone then lines[#lines + 1] = ('In PvP-zone: %s  \n'):format(zone) end
    if ids.license then
        local warns = MySQL.scalar.await('SELECT COUNT(*) FROM admin_warnings WHERE license = ?', { ids.license }) or 0
        lines[#lines + 1] = ('Waarschuwingen: %d  \n'):format(warns)
    end
    if src == 0 then print(table.concat(lines)) return end
    TriggerClientEvent('admin_tools:showInfo', src, table.concat(lines))
    exports.server_logs:Log('admin', 'Spelercontrole', ('%s controleerde %s'):format(describe(src), describe(tid)))
end

local function listWarnings(src, tid)
    local ids = identifiersOf(tid)
    if not ids.license then return end
    local rows = MySQL.query.await('SELECT reason, warned_by, UNIX_TIMESTAMP(created_at) AS t FROM admin_warnings WHERE license = ? ORDER BY id DESC LIMIT 10', { ids.license }) or {}
    local lines = { ('**%s** – %d recente waarschuwing(en)  \n'):format(GetPlayerName(tid), #rows) }
    for _, r in ipairs(rows) do
        lines[#lines + 1] = ('%s – %s (door %s)  \n'):format(os.date('%d-%m-%Y', tonumber(r.t)), r.reason, r.warned_by)
    end
    if src == 0 then print(table.concat(lines)) return end
    TriggerClientEvent('admin_tools:showInfo', src, table.concat(lines))
end

---------------------------------------------------------------------------
-- Commando's
---------------------------------------------------------------------------
local function guard(src, action)
    if not has(src, action) then
        say(src, 'error', 'admin.no_permission')
        return false
    end
    return true
end

local function command(name, action, handler)
    RegisterCommand(name, function(source, args)
        if not guard(source, action) then return end
        if source ~= 0 and not throttle(source, 'cmd', 500) then return end
        handler(source, args)
    end, false)
end

command('kick', 'kick', function(src, args)
    local tid = target(src, args[1])
    if tid then doKick(src, tid, table.concat(args, ' ', 2)) end
end)

command('ban', 'ban', function(src, args)
    local tid = target(src, args[1])
    if not tid then return end
    local hours = parseDuration(args[2])
    if not hours then say(src, 'error', 'admin.duration_invalid') return end
    doBan(src, tid, hours, table.concat(args, ' ', 3))
end)

command('unban', 'unban', function(src, args)
    local id = tonumber(args[1])
    if not id then say(src, 'error', 'admin.ban_id_invalid') return end
    local affected = MySQL.update.await('UPDATE admin_bans SET active = 0 WHERE id = ? AND active = 1', { id })
    if affected and affected > 0 then
        exports.server_logs:Log('admin', 'Unban', ('%s hief ban #%d op'):format(describe(src), id))
        say(src, 'success', 'admin.unbanned', id)
    else
        say(src, 'error', 'admin.ban_not_found')
    end
end)

command('warn', 'warn', function(src, args)
    local tid = target(src, args[1])
    if tid then doWarn(src, tid, table.concat(args, ' ', 2)) end
end)

command('warnings', 'warnings', function(src, args)
    local tid = target(src, args[1])
    if tid then listWarnings(src, tid) end
end)

command('checkplayer', 'check', function(src, args)
    local tid = target(src, args[1])
    if tid then checkPlayer(src, tid) end
end)

command('arevive', 'revive', function(src, args)
    local tid = target(src, args[1])
    if tid then doRevive(src, tid) end
end)

command('goto', 'teleport', function(src, args)
    local tid = target(src, args[1])
    if tid then doGoto(src, tid) end
end)

command('bring', 'bring', function(src, args)
    local tid = target(src, args[1])
    if tid then doBring(src, tid) end
end)

command('pvpkick', 'kick', function(src, args)
    local tid = target(src, args[1])
    if tid then doCombatKick(src, tid) end
end)

command('announce', 'announce', function(src, args)
    local text = cleanReason(table.concat(args, ' '))
    TriggerClientEvent('chat:addMessage', -1, { color = { 255, 106, 0 }, multiline = true, args = { ('[%s]'):format(ServerCfg.Server.shortName), text } })
    exports.server_logs:Log('admin', 'Aankondiging', ('%s: %s'):format(describe(src), text))
end)

---------------------------------------------------------------------------
-- Adminmenu (UI) – callbacks met server-side rechtencontrole
---------------------------------------------------------------------------
lib.callback.register('admin_tools:can', function(source, action)
    return has(source, action or 'menu')
end)

lib.callback.register('admin_tools:getPlayers', function(source)
    if not has(source, 'menu') then return nil end
    local list = {}
    for _, id in ipairs(ESX.GetPlayers()) do
        id = tonumber(id)
        local x = ESX.GetPlayerFromId(id)
        if x then
            list[#list + 1] = { id = id, name = x.getName(), job = x.job.name, group = x.getGroup(), ping = GetPlayerPing(id) }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

lib.callback.register('admin_tools:action', function(source, action, targetId, extra)
    if type(action) ~= 'string' then return false end
    if not throttle(source, 'menu', 600) then return false end
    local needed = ({ kick = 'kick', ban = 'ban', warn = 'warn', warnings = 'warnings', check = 'check',
        revive = 'revive', ['goto'] = 'teleport', bring = 'bring', pvpkick = 'kick' })[action]
    if not needed or not has(source, needed) then
        say(source, 'error', 'admin.no_permission')
        return false
    end
    local tid = tonumber(targetId)
    if not tid or not GetPlayerName(tid) then say(source, 'error', 'admin.no_player') return false end
    extra = type(extra) == 'table' and extra or {}

    if action == 'kick' then doKick(source, tid, extra.reason)
    elseif action == 'ban' then
        local hours = parseDuration(extra.duration)
        if not hours then say(source, 'error', 'admin.duration_invalid') return false end
        doBan(source, tid, hours, extra.reason)
    elseif action == 'warn' then doWarn(source, tid, extra.reason)
    elseif action == 'warnings' then listWarnings(source, tid)
    elseif action == 'check' then checkPlayer(source, tid)
    elseif action == 'revive' then doRevive(source, tid)
    elseif action == 'goto' then doGoto(source, tid)
    elseif action == 'bring' then doBring(source, tid)
    elseif action == 'pvpkick' then doCombatKick(source, tid) end
    return true
end)

---------------------------------------------------------------------------
-- Bans controleren bij verbinden
---------------------------------------------------------------------------
AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(ServerCfg.T('admin.checking_ban'))

    local ids = identifiersOf(src)
    local clauses, params = {}, {}
    for _, kind in ipairs({ 'license', 'discord', 'fivem', 'steam' }) do
        if ids[kind] then
            clauses[#clauses + 1] = kind .. ' = ?'
            params[#params + 1] = ids[kind]
        end
    end
    -- Een legitieme client heeft altijd een Rockstar-license; zonder kan een ban worden ontweken.
    if not ids.license then
        deferrals.done(ServerCfg.T('admin.no_license_connect'))
        return
    end

    local ok, ban = pcall(function()
        return MySQL.single.await(
            'SELECT id, reason, UNIX_TIMESTAMP(expires_at) AS expires FROM admin_bans WHERE active = 1 ' ..
            'AND (expires_at IS NULL OR expires_at > NOW()) AND (' .. table.concat(clauses, ' OR ') .. ') ORDER BY id DESC LIMIT 1',
            params)
    end)
    if not ok then
        -- database onbereikbaar: veilig beleid = laten verbinden maar loggen
        print('^1[admin_tools]^7 Bancontrole mislukt (database?).')
        deferrals.done()
        return
    end
    if ban then
        local duration = ban.expires and ServerCfg.T('admin.until', os.date('%d-%m-%Y %H:%M', tonumber(ban.expires))) or ServerCfg.T('admin.permanent')
        exports.server_logs:Log('admin', 'Verbinding geweigerd (ban)', ('%s probeerde te verbinden – ban #%d'):format(name, ban.id))
        deferrals.done(ServerCfg.T('admin.banned_msg', ban.reason, duration, ban.id))
        return
    end
    deferrals.done()
end)

AddEventHandler('playerDropped', function()
    local prefix = source .. ':'
    for k in pairs(last) do if k:sub(1, #prefix) == prefix then last[k] = nil end end
end)
