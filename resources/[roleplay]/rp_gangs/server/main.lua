--[[
    rp_gangs/server/main.lua – gangdata, leden, grades, gangkas.

    Exports:
        exports.rp_gangs:GetGangId(src)   -> gang-id of nil
        exports.rp_gangs:GetGang(src)     -> { id, name, label, color, grade } of nil
        exports.rp_gangs:GetGradeLevel(src)
]]

Gang = {
    gangs   = {},   -- [id] = { id, name, label, color, bank }
    members = {},   -- [identifier] = { gang_id, grade, name }
    bySrc   = {},   -- [source] = identifier
    ready   = false,
}

local last = {}
function Gang.throttle(src, key, ms)
    local id = src .. ':' .. key
    local now = GetGameTimer()
    if (last[id] or -1e9) + ms > now then return false end
    last[id] = now
    return true
end

function Gang.coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

function Gang.dist(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

function Gang.near(src, target, maxDist)
    local c = Gang.coordsOf(src)
    return c ~= nil and Gang.dist(c, target) <= maxDist
end

function Gang.log(title, text, channel)
    exports.server_logs:Log(channel or 'gang', title, text)
end

---------------------------------------------------------------------------
-- Laden
---------------------------------------------------------------------------
function Gang.loadAll()
    local gangs = MySQL.query.await('SELECT id, name, label, color, bank FROM rp_gangs') or {}
    for _, g in ipairs(gangs) do Gang.gangs[g.id] = g end
    local members = MySQL.query.await('SELECT identifier, gang_id, grade, name FROM rp_gang_members') or {}
    for _, m in ipairs(members) do Gang.members[m.identifier] = m end
    Gang.ready = true
end

function Gang.refresh(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    Gang.bySrc[src] = xPlayer.identifier
    local m = Gang.members[xPlayer.identifier]
    local ok, bag = pcall(function() return Player(src).state end)
    if ok and bag then bag:set('gangId', m and m.gang_id or 0, true) end
end

--- gang + lidmaatschap van een speler
function Gang.of(src)
    local identifier = Gang.bySrc[src]
    if not identifier then
        Gang.refresh(src)
        identifier = Gang.bySrc[src]
    end
    local m = identifier and Gang.members[identifier]
    if not m then return nil end
    return Gang.gangs[m.gang_id], m
end

function Gang.can(src, perm)
    local gang, m = Gang.of(src)
    if not gang then return false end
    local grade = GangCfg.Grades[m.grade]
    return grade ~= nil and grade.perms[perm] == true
end

function Gang.onlineMembers(gangId)
    local out = {}
    for _, id in ipairs(ESX.GetPlayers()) do
        id = tonumber(id)
        local g = Gang.of(id)
        if g and g.id == gangId then out[#out + 1] = id end
    end
    return out
end

function Gang.notifyGang(gangId, kind, key, ...)
    for _, src in ipairs(Gang.onlineMembers(gangId)) do ServerCfg.Notify(src, kind, key, ...) end
end

function Gang.addBank(gangId, delta)
    local g = Gang.gangs[gangId]
    if not g then return false end
    if delta < 0 and g.bank + delta < 0 then return false end
    g.bank = g.bank + delta
    MySQL.update('UPDATE rp_gangs SET bank = ? WHERE id = ?', { g.bank, gangId })
    return true
end

local function memberCount(gangId)
    local n = 0
    for _, m in pairs(Gang.members) do if m.gang_id == gangId then n = n + 1 end end
    return n
end

local function gangCount()
    local n = 0
    for _ in pairs(Gang.gangs) do n = n + 1 end
    return n
end

local function pay(xPlayer, account, amount, reason)
    if account == 'money' then
        if xPlayer.getMoney() < amount then return false end
        xPlayer.removeMoney(amount, reason)
    else
        if xPlayer.getAccount(account).money < amount then return false end
        xPlayer.removeAccountMoney(account, amount, reason)
    end
    return true
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------
exports('GetGangId', function(src)
    local g = Gang.of(src)
    return g and g.id or nil
end)

exports('GetGang', function(src)
    local g, m = Gang.of(src)
    if not g then return nil end
    return { id = g.id, name = g.name, label = g.label, color = g.color, grade = m.grade }
end)

exports('GetGradeLevel', function(src)
    local _, m = Gang.of(src)
    return m and m.grade or nil
end)

---------------------------------------------------------------------------
-- Info
---------------------------------------------------------------------------
lib.callback.register('rp_gangs:getInfo', function(source)
    local gang, me = Gang.of(source)
    if not gang then
        return { inGang = false, cost = GangCfg.Creation.cost }
    end
    local members = {}
    local online = {}
    for _, id in ipairs(Gang.onlineMembers(gang.id)) do
        local x = ESX.GetPlayerFromId(id)
        if x then online[x.identifier] = id end
    end
    for identifier, m in pairs(Gang.members) do
        if m.gang_id == gang.id then
            members[#members + 1] = {
                identifier = identifier, name = m.name, grade = m.grade,
                gradeLabel = GangCfg.Grades[m.grade].label, online = online[identifier] ~= nil,
            }
        end
    end
    table.sort(members, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)
    local perms = GangCfg.Grades[me.grade].perms
    return {
        inGang = true, id = gang.id, label = gang.label, color = gang.color, bank = gang.bank,
        grade = me.grade, gradeLabel = GangCfg.Grades[me.grade].label, perms = perms,
        members = members, maxMembers = GangCfg.MaxMembers,
        territories = Gang.territoriesOf and Gang.territoriesOf(gang.id) or {},
        self = Gang.bySrc[source],
    }
end)

---------------------------------------------------------------------------
-- Oprichten
---------------------------------------------------------------------------
lib.callback.register('rp_gangs:create', function(source, name, color)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { ok = false, msg = 'gang.invalid' } end
    if not Gang.throttle(source, 'manage', GangCfg.Creation.cooldownMs) then return { ok = false, msg = 'gang.too_fast' } end
    if Gang.of(source) then return { ok = false, msg = 'gang.already_in' } end

    name = ServerCfg.Trim(tostring(name or ''))
    if #name < GangCfg.Creation.nameMin or #name > GangCfg.Creation.nameMax or not name:match('^[%w _%-]+$') then
        return { ok = false, msg = 'gang.name_invalid', param = GangCfg.Creation.nameMin }
    end
    color = tostring(color or '')
    if not color:match('^#%x%x%x%x%x%x$') then color = '#ff0000' end

    if gangCount() >= GangCfg.Creation.maxGangs then return { ok = false, msg = 'gang.max_gangs' } end
    local internal = name:lower():gsub('[^%w]', '_')
    for _, g in pairs(Gang.gangs) do
        if g.name == internal or g.label:lower() == name:lower() then return { ok = false, msg = 'gang.name_taken' } end
    end

    if not pay(xPlayer, GangCfg.Creation.account, GangCfg.Creation.cost, 'Gang oprichten') then
        return { ok = false, msg = 'gang.no_money', param = GangCfg.Creation.cost }
    end

    local ok, id = pcall(function()
        return MySQL.insert.await('INSERT INTO rp_gangs (name, label, color, bank, created_by) VALUES (?, ?, ?, 0, ?)',
            { internal, name, color, xPlayer.identifier })
    end)
    if not ok or not id then
        if GangCfg.Creation.account == 'money' then xPlayer.addMoney(GangCfg.Creation.cost, 'Gang oprichten terugbetaling')
        else xPlayer.addAccountMoney(GangCfg.Creation.account, GangCfg.Creation.cost, 'Gang oprichten terugbetaling') end
        return { ok = false, msg = 'gang.name_taken' }
    end

    Gang.gangs[id] = { id = id, name = internal, label = name, color = color, bank = 0 }
    local leaderName = xPlayer.getName()
    MySQL.insert.await('INSERT INTO rp_gang_members (identifier, gang_id, grade, name) VALUES (?, ?, ?, ?)',
        { xPlayer.identifier, id, GangCfg.LeaderGrade, leaderName })
    Gang.members[xPlayer.identifier] = { gang_id = id, grade = GangCfg.LeaderGrade, name = leaderName }
    Gang.refresh(source)

    Gang.log('Gang opgericht', ('%s richtte gang **%s** op (kosten €%d)'):format(
        exports.server_logs:Describe(source), name, GangCfg.Creation.cost))
    exports.server_logs:Log('money', 'Gang oprichtingskosten', ('%s betaalde €%d'):format(exports.server_logs:Describe(source), GangCfg.Creation.cost))
    return { ok = true, msg = 'gang.created', param = name }
end)

---------------------------------------------------------------------------
-- Leden beheren
---------------------------------------------------------------------------
lib.callback.register('rp_gangs:invite', function(source, targetId)
    local gang = Gang.of(source)
    if not gang or not Gang.can(source, 'invite') then return { ok = false, msg = 'gang.no_permission' } end
    if not Gang.throttle(source, 'manage', GangCfg.Creation.cooldownMs) then return { ok = false, msg = 'gang.too_fast' } end

    targetId = tonumber(targetId)
    local xTarget = targetId and ESX.GetPlayerFromId(targetId)
    if not xTarget or targetId == source then return { ok = false, msg = 'gang.no_target' } end
    local c = Gang.coordsOf(targetId)
    if not c or not Gang.near(source, c, GangCfg.Creation.inviteDistance) then return { ok = false, msg = 'gang.too_far' } end
    if Gang.of(targetId) then return { ok = false, msg = 'gang.target_in_gang' } end
    if memberCount(gang.id) >= GangCfg.MaxMembers then return { ok = false, msg = 'gang.full' } end

    local xSource = ESX.GetPlayerFromId(source)
    local accepted = lib.callback.await('rp_gangs:confirmInvite', targetId, gang.label, xSource.getName())
    if not accepted then return { ok = false, msg = 'gang.invite_declined' } end

    -- opnieuw controleren: er is tijd verstreken
    if Gang.of(targetId) or memberCount(gang.id) >= GangCfg.MaxMembers then return { ok = false, msg = 'gang.invalid' } end
    local name = xTarget.getName()
    MySQL.insert.await('INSERT INTO rp_gang_members (identifier, gang_id, grade, name) VALUES (?, ?, 0, ?)',
        { xTarget.identifier, gang.id, name })
    Gang.members[xTarget.identifier] = { gang_id = gang.id, grade = 0, name = name }
    Gang.refresh(targetId)
    Gang.notifyGang(gang.id, 'inform', 'gang.member_joined', name)
    Gang.log('Gang lid erbij', ('%s is lid geworden van %s (uitgenodigd door %s)'):format(
        exports.server_logs:Describe(targetId), gang.label, exports.server_logs:Describe(source)))
    return { ok = true, msg = 'gang.invited', param = name }
end)

local function removeMember(identifier)
    Gang.members[identifier] = nil
    MySQL.update('DELETE FROM rp_gang_members WHERE identifier = ?', { identifier })
    for src, id in pairs(Gang.bySrc) do
        if id == identifier then
            Gang.refresh(src)
            -- lid uit lopende gang-oorlog halen
            pcall(function() exports.combat_core:ForceLeave(src, 'combat.left_forced') end)
        end
    end
end

lib.callback.register('rp_gangs:kick', function(source, identifier)
    local gang, me = Gang.of(source)
    if not gang or not Gang.can(source, 'kick') then return { ok = false, msg = 'gang.no_permission' } end
    if not Gang.throttle(source, 'manage', GangCfg.Creation.cooldownMs) then return { ok = false, msg = 'gang.too_fast' } end
    local m = Gang.members[tostring(identifier)]
    if not m or m.gang_id ~= gang.id then return { ok = false, msg = 'gang.no_target' } end
    if m.grade >= me.grade then return { ok = false, msg = 'gang.grade_too_high' } end
    removeMember(identifier)
    Gang.log('Gang lid verwijderd', ('%s verwijderde %s uit %s'):format(exports.server_logs:Describe(source), m.name, gang.label))
    return { ok = true, msg = 'gang.kicked', param = m.name }
end)

lib.callback.register('rp_gangs:setGrade', function(source, identifier, grade)
    local gang, me = Gang.of(source)
    if not gang or not Gang.can(source, 'promote') then return { ok = false, msg = 'gang.no_permission' } end
    if not Gang.throttle(source, 'manage', GangCfg.Creation.cooldownMs) then return { ok = false, msg = 'gang.too_fast' } end
    grade = math.floor(tonumber(grade) or -1)
    local m = Gang.members[tostring(identifier)]
    if not m or m.gang_id ~= gang.id or not GangCfg.Grades[grade] then return { ok = false, msg = 'gang.invalid' } end
    -- je mag alleen leden onder jezelf beheren en niemand tot jouw niveau of hoger verheffen
    if m.grade >= me.grade or grade >= me.grade then return { ok = false, msg = 'gang.grade_too_high' } end
    m.grade = grade
    MySQL.update('UPDATE rp_gang_members SET grade = ? WHERE identifier = ?', { grade, identifier })
    Gang.log('Gang grade gewijzigd', ('%s zette %s op grade %d (%s)'):format(
        exports.server_logs:Describe(source), m.name, grade, GangCfg.Grades[grade].label))
    return { ok = true, msg = 'gang.grade_set', param = GangCfg.Grades[grade].label }
end)

lib.callback.register('rp_gangs:leave', function(source)
    local gang, me = Gang.of(source)
    if not gang then return { ok = false, msg = 'gang.not_in' } end
    if me.grade >= GangCfg.LeaderGrade and memberCount(gang.id) > 1 then
        return { ok = false, msg = 'gang.leader_cannot_leave' }
    end
    local identifier = Gang.bySrc[source]
    removeMember(identifier)
    if memberCount(gang.id) == 0 then Gang.disbandData(gang.id) end
    Gang.log('Gang verlaten', ('%s verliet %s'):format(exports.server_logs:Describe(source), gang.label))
    return { ok = true, msg = 'gang.left' }
end)

--- Verwijder gang volledig (leden zijn al weg of worden hier verwijderd). Gangkas → leider.
function Gang.disbandData(gangId)
    for identifier, m in pairs(Gang.members) do
        if m.gang_id == gangId then removeMember(identifier) end
    end
    MySQL.update('DELETE FROM rp_gangs WHERE id = ?', { gangId })
    MySQL.update('UPDATE rp_gang_territories SET gang_id = NULL WHERE gang_id = ?', { gangId })
    Gang.gangs[gangId] = nil
    if Gang.releaseTerritories then Gang.releaseTerritories(gangId) end
end

lib.callback.register('rp_gangs:disband', function(source)
    local gang = Gang.of(source)
    if not gang or not Gang.can(source, 'disband') then return { ok = false, msg = 'gang.no_permission' } end
    local xPlayer = ESX.GetPlayerFromId(source)
    -- gangkas wordt uitbetaald aan de leider (bank)
    if gang.bank > 0 then
        xPlayer.addAccountMoney('bank', gang.bank, 'Gangkas bij opheffen')
        exports.server_logs:Log('money', 'Gangkas uitbetaald', ('%s ontving €%d van de gangkas van %s'):format(
            exports.server_logs:Describe(source), gang.bank, gang.label))
    end
    Gang.log('Gang opgeheven', ('%s heeft %s opgeheven'):format(exports.server_logs:Describe(source), gang.label))
    Gang.disbandData(gang.id)
    return { ok = true, msg = 'gang.disbanded' }
end)

---------------------------------------------------------------------------
-- Gangkas
---------------------------------------------------------------------------
lib.callback.register('rp_gangs:deposit', function(source, amount)
    local gang = Gang.of(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not gang or not xPlayer or not Gang.can(source, 'bank_deposit') then return { ok = false, msg = 'gang.no_permission' } end
    if not Gang.throttle(source, 'bank', 1000) then return { ok = false, msg = 'gang.too_fast' } end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > 10000000 then return { ok = false, msg = 'gang.amount_invalid' } end
    if xPlayer.getMoney() < amount then return { ok = false, msg = 'gang.no_cash' } end
    xPlayer.removeMoney(amount, 'Gangkas storting')
    Gang.addBank(gang.id, amount)
    exports.server_logs:Log('money', 'Gangkas storting', ('%s stortte €%d in de kas van %s (saldo €%d)'):format(
        exports.server_logs:Describe(source), amount, gang.label, gang.bank))
    return { ok = true, msg = 'gang.deposited', param = amount }
end)

lib.callback.register('rp_gangs:withdraw', function(source, amount)
    local gang = Gang.of(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not gang or not xPlayer or not Gang.can(source, 'bank_withdraw') then return { ok = false, msg = 'gang.no_permission' } end
    if not Gang.throttle(source, 'bank', 1000) then return { ok = false, msg = 'gang.too_fast' } end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > GangCfg.BankWithdrawMaxPerAction then return { ok = false, msg = 'gang.amount_invalid' } end
    if not Gang.addBank(gang.id, -amount) then return { ok = false, msg = 'gang.bank_low' } end
    xPlayer.addMoney(amount, 'Gangkas opname')
    exports.server_logs:Log('money', 'Gangkas opname', ('%s nam €%d op uit de kas van %s (saldo €%d)'):format(
        exports.server_logs:Describe(source), amount, gang.label, gang.bank))
    return { ok = true, msg = 'gang.withdrawn', param = amount }
end)

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
AddEventHandler('esx:playerLoaded', function(playerId)
    if Gang.ready then Gang.refresh(playerId) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Gang.bySrc[src] = nil
    local prefix = src .. ':'
    for k in pairs(last) do if k:sub(1, #prefix) == prefix then last[k] = nil end end
end)

CreateThread(function()
    Wait(0) -- laat eerst alle serverbestanden laden (territory.lua zet Gang.onReady)
    local ok = pcall(function() MySQL.scalar.await('SELECT 1 FROM rp_gangs LIMIT 1') end)
    if not ok then
        print('^1[rp_gangs]^7 Tabellen ontbreken. Importeer sql/01_core.sql en herstart de resource.')
        return
    end
    Gang.loadAll()
    for _, id in ipairs(ESX.GetPlayers()) do Gang.refresh(tonumber(id)) end
    if Gang.onReady then Gang.onReady() end
    print(('^2[rp_gangs]^7 %d gang(s) geladen.'):format(gangCount()))
end)
