--[[
    Test-harnas: mockt de FiveM/ESX/ox_lib/oxmysql-API zodat de SERVER-lua van onze resources
    buiten FiveM kan draaien. Draait onder Lua 5.4 (zelfde versie als FiveM `lua54 'yes'`).
]]

Mock = {
    time = 100000,            -- GetGameTimer() in ms
    currentResource = 'harness',
    events = {},              -- log van TriggerClientEvent: { name=, target=, args={} }
    handlers = {},            -- [event] = { fn, ... }
    callbacks = {},           -- ox_lib callbacks
    registry = {},            -- exports per resource
    players = {},             -- [src] = { coords=, health=, vehicle=, name=, identifiers={}, selectedWeapon=, state={} }
    xPlayers = {},            -- [src] = xPlayer mock
    timeouts = {},
    threads = {},
    logs = {},                -- server_logs:Log aanroepen
    db = { combat_stats = {}, combat_kill_log = {}, admin_bans = {}, admin_warnings = {} },
    convars = {},
    commands = {},
    http = {},
}

---------------------------------------------------------------------------
-- joaat (echte Jenkins one-at-a-time, lowercase)
---------------------------------------------------------------------------
function joaat(s)
    s = tostring(s):lower()
    local h = 0
    for i = 1, #s do
        h = (h + s:byte(i)) & 0xFFFFFFFF
        h = (h + (h << 10)) & 0xFFFFFFFF
        h = (h ~ (h >> 6)) & 0xFFFFFFFF
    end
    h = (h + (h << 3)) & 0xFFFFFFFF
    h = (h ~ (h >> 11)) & 0xFFFFFFFF
    h = (h + (h << 15)) & 0xFFFFFFFF
    return h
end
GetHashKey = joaat

function vec3(x, y, z) return { x = x + 0.0, y = y + 0.0, z = z + 0.0 } end
function vec4(x, y, z, w) return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = w + 0.0 } end
vector3, vector4 = vec3, vec4

function IsDuplicityVersion() return true end
function GetCurrentResourceName() return Mock.currentResource end
function GetGameTimer() return Mock.time end
function Wait()
    if coroutine.isyieldable() then coroutine.yield() end
end
function CreateThread(fn)
    local co = coroutine.create(fn)
    Mock.threads[#Mock.threads + 1] = co
    local ok, err = coroutine.resume(co)
    if not ok then error('thread-fout: ' .. tostring(err)) end
end
--- Laat elke draaiende thread één iteratie doorlopen (voorbij zijn volgende Wait)
function Mock.stepThreads()
    for _, co in ipairs(Mock.threads) do
        if coroutine.status(co) == 'suspended' then
            local ok, err = coroutine.resume(co)
            if not ok then error('thread-fout: ' .. tostring(err)) end
        end
    end
end
Citizen = { CreateThread = CreateThread, Wait = Wait }
function SetTimeout(ms, fn) Mock.timeouts[#Mock.timeouts + 1] = { at = Mock.time + ms, fn = fn } end
function GetConvar(name, default) return Mock.convars[name] or default end

json = {
    encode = function(v) return '<json>' end,
    decode = function() return {} end,
}

function PerformHttpRequest(url, cb, method, body, headers)
    Mock.http[#Mock.http + 1] = { url = url, body = body }
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function RegisterNetEvent(name, fn)
    if fn then AddEventHandler(name, fn) end
end

function AddEventHandler(name, fn)
    Mock.handlers[name] = Mock.handlers[name] or {}
    table.insert(Mock.handlers[name], fn)
end

--- Simuleer een net-event van een speler (client → server)
function Mock.fire(name, src, ...)
    source = src
    for _, fn in ipairs(Mock.handlers[name] or {}) do fn(...) end
end

--- Zelfde, maar met `source` gezet voor server-events die ESX zou vuren (esx:setJob e.d.)
function TriggerEvent(name, ...)
    for _, fn in ipairs(Mock.handlers[name] or {}) do fn(...) end
end

function TriggerClientEvent(name, target, ...)
    Mock.events[#Mock.events + 1] = { name = name, target = target, args = { ... } }
end

function Mock.eventsNamed(name, target)
    local out = {}
    for _, e in ipairs(Mock.events) do
        if e.name == name and (target == nil or e.target == target) then out[#out + 1] = e end
    end
    return out
end

function Mock.clearEvents() Mock.events = {} end

function RegisterCommand(name, fn, restricted) Mock.commands[name] = fn end
function CancelEvent() Mock.cancelled = true end

---------------------------------------------------------------------------
-- exports
---------------------------------------------------------------------------
exports = setmetatable({}, {
    __call = function(_, name, fn)
        Mock.registry[Mock.currentResource] = Mock.registry[Mock.currentResource] or {}
        Mock.registry[Mock.currentResource][name] = fn
    end,
    __index = function(_, resource)
        return setmetatable({}, {
            __index = function(_, fname)
                return function(_, ...)
                    local reg = Mock.registry[resource]
                    if not reg or not reg[fname] then
                        error(('export %s:%s bestaat niet'):format(resource, fname))
                    end
                    return reg[fname](...)
                end
            end,
        })
    end,
})

-- server_logs mock (de echte wordt apart getest)
Mock.registry.server_logs = {
    Log = function(channel, title, desc, fields)
        Mock.logs[#Mock.logs + 1] = { channel = channel, title = title, desc = desc }
    end,
    Describe = function(src) return ('Speler#%s'):format(tostring(src)) end,
}

function Mock.logsOf(channel)
    local out = {}
    for _, l in ipairs(Mock.logs) do if l.channel == channel then out[#out + 1] = l end end
    return out
end

---------------------------------------------------------------------------
-- ox_lib
---------------------------------------------------------------------------
lib = {
    callback = {
        register = function(name, fn) Mock.callbacks[name] = fn end,
    },
}
function Mock.callback(name, src, ...)
    assert(Mock.callbacks[name], 'callback bestaat niet: ' .. name)
    return Mock.callbacks[name](src, ...)
end

---------------------------------------------------------------------------
-- Natives
---------------------------------------------------------------------------
function GetPlayerPed(src)
    if Mock.players[src] then return 1000 + src end
    return 0
end
local function playerOfPed(ped) return Mock.players[ped - 1000] end

function GetEntityCoords(ped) return playerOfPed(ped).coords end
function GetEntityHealth(ped) return playerOfPed(ped).health or 200 end
function GetVehiclePedIsIn(ped) return playerOfPed(ped).vehicle or 0 end
function GetSelectedPedWeapon(ped) return playerOfPed(ped).selectedWeapon or joaat('WEAPON_UNARMED') end
function RemoveWeaponFromPed(ped, hash) playerOfPed(ped).removedWeapon = hash end
function GetPlayerName(src) return Mock.players[src] and Mock.players[src].name or nil end
function GetPlayerIdentifiers(src) return Mock.players[src] and Mock.players[src].identifiers or {} end
function DoesEntityExist() return true end
function GetEntityType() return 1 end
function NetworkGetEntityFromNetworkId(id) return id end
function NetworkGetEntityOwner(e) return e - 1000 end

function Player(src)
    local p = Mock.players[src]
    p.state = p.state or setmetatable({}, { __index = {
        set = function(self, k, v) rawset(self, k, v) end,
    } })
    return { state = p.state }
end

---------------------------------------------------------------------------
-- ESX
---------------------------------------------------------------------------
ESX = {
    GetPlayerFromId = function(src) return Mock.xPlayers[src] end,
    GetPlayers = function()
        local list = {}
        for src in pairs(Mock.xPlayers) do list[#list + 1] = src end
        table.sort(list)
        return list
    end,
}

--- Maak een speler (mock) met ESX-achtige xPlayer.
function Mock.addPlayer(src, opts)
    opts = opts or {}
    Mock.players[src] = {
        coords = opts.coords or { x = 0.0, y = 0.0, z = 30.0 },
        health = 200, name = opts.name or ('Speler' .. src),
        identifiers = { 'license:lic' .. src, 'discord:dis' .. src },
        ip = '127.0.0.' .. src,
    }
    local xp = {
        source = src, identifier = opts.identifier or ('license:lic' .. src),
        job = { name = opts.job or 'unemployed', grade = opts.grade or 0 },
        money = opts.money or 1000,
        accounts = { bank = opts.bank or 5000, black_money = 0 },
        loadout = opts.loadout or {},
        group = opts.group or 'user',
        inventory = {},
        notified = {},
    }
    function xp.getName() return opts.name or ('Speler' .. src) end
    function xp.getMoney() return xp.money end
    function xp.addMoney(n) xp.money = xp.money + n end
    function xp.removeMoney(n) xp.money = xp.money - n end
    function xp.getAccount(name) return { name = name, money = xp.accounts[name] or 0 } end
    function xp.addAccountMoney(name, n) xp.accounts[name] = (xp.accounts[name] or 0) + n end
    function xp.removeAccountMoney(name, n) xp.accounts[name] = (xp.accounts[name] or 0) - n end
    function xp.getJob() return xp.job end
    function xp.setJob(name, grade) local last = xp.job; xp.job = { name = name, grade = grade or 0 }; TriggerEvent('esx:setJob', src, xp.job, last) end
    function xp.getGroup() return xp.group end
    function xp.getLoadout() local c = {}; for i, w in ipairs(xp.loadout) do c[i] = { name = w.name, ammo = w.ammo, components = w.components or {}, tintIndex = w.tintIndex or 0 } end return c end
    function xp.updateWeaponAmmo(name, ammo) for _, w in ipairs(xp.loadout) do if w.name == name then w.ammo = ammo end end end
    function xp.hasWeapon(name) for _, w in ipairs(xp.loadout) do if w.name == name then return true end end return false end
    function xp.showNotification(msg) xp.notified[#xp.notified + 1] = msg end
    function xp.getInventoryItem(name) return { name = name, count = xp.inventory[name] or 0 } end
    function xp.addInventoryItem(name, n) xp.inventory[name] = (xp.inventory[name] or 0) + n end
    function xp.removeInventoryItem(name, n) xp.inventory[name] = (xp.inventory[name] or 0) - n end
    function xp.canCarryItem() return true end
    function xp.set() end
    function xp.get() return nil end
    Mock.xPlayers[src] = xp
    return xp
end

function Mock.removePlayer(src)
    source = src
    for _, fn in ipairs(Mock.handlers['playerDropped'] or {}) do fn('weg') end
    Mock.players[src] = nil
    Mock.xPlayers[src] = nil
end

function Mock.advance(ms) Mock.time = Mock.time + ms end

function Mock.runTimeouts()
    local keep = {}
    local due = {}
    for _, t in ipairs(Mock.timeouts) do
        if t.at <= Mock.time then due[#due + 1] = t else keep[#keep + 1] = t end
    end
    Mock.timeouts = keep
    for _, t in ipairs(due) do t.fn() end
end

---------------------------------------------------------------------------
-- oxmysql (in-memory, alleen de queries die onze resources gebruiken)
---------------------------------------------------------------------------
local function row_copy(r) if not r then return nil end local c = {} for k, v in pairs(r) do c[k] = v end return c end

local MySQLimpl = {}
function MySQLimpl.single(q, p)
    if q:find('FROM combat_stats WHERE identifier') then return row_copy(Mock.db.combat_stats[p[1]]) end
    return nil
end
function MySQLimpl.scalar(q, p)
    if q:find('SELECT 1 FROM') then return 1 end
    return nil
end
function MySQLimpl.insert(q, p)
    if q:find('INSERT INTO combat_stats') then
        Mock.db.combat_stats[p[1]] = { identifier = p[1], name = p[2], kills = 0, deaths = 0, best_streak = 0, xp = 0, earned_today = 0, earned_date = p[3] }
        return 1
    elseif q:find('INSERT INTO combat_kill_log') then
        table.insert(Mock.db.combat_kill_log, { killer = p[1], victim = p[2], zone = p[3], weapon = p[4], money = p[5], xp = p[6] })
        return #Mock.db.combat_kill_log
    elseif q:find('INSERT INTO admin_bans') then
        table.insert(Mock.db.admin_bans, { id = #Mock.db.admin_bans + 1, params = p, active = 1 })
        return #Mock.db.admin_bans
    elseif q:find('INSERT INTO admin_warnings') then
        table.insert(Mock.db.admin_warnings, { license = p[1], name = p[2], reason = p[3], warned_by = p[4] })
        return #Mock.db.admin_warnings
    end
    return 1
end
function MySQLimpl.update(q, p)
    if q:find('UPDATE combat_stats SET') then
        local r = Mock.db.combat_stats[p[8]]
        if r then
            r.name, r.kills, r.deaths, r.best_streak, r.xp, r.earned_today, r.earned_date = p[1], p[2], p[3], p[4], p[5], p[6], p[7]
        end
        return 1
    end
    return 0
end
function MySQLimpl.query(q, p)
    if q:find('FROM combat_stats') then
        local rows = {}
        for _, r in pairs(Mock.db.combat_stats) do rows[#rows + 1] = row_copy(r) end
        table.sort(rows, function(a, b) return a.kills > b.kills end)
        return rows
    end
    return {}
end

local function wrap(fn)
    return setmetatable({ await = function(q, p) return fn(q, p) end }, {
        __call = function(_, q, p, cb)
            local r = fn(q, p)
            if cb then cb(r) end
            return r
        end,
    })
end
MySQL = {
    single = wrap(MySQLimpl.single), scalar = wrap(MySQLimpl.scalar), insert = wrap(MySQLimpl.insert),
    update = wrap(MySQLimpl.update), query = wrap(MySQLimpl.query),
}

---------------------------------------------------------------------------
-- Bestanden laden
---------------------------------------------------------------------------
function Mock.load(resource, relpath)
    Mock.currentResource = resource
    local group
    local path = ROOT .. '/' .. relpath
    local f, err = loadfile(path)
    assert(f, err)
    f()
end

--- Laad de gedeelde configuratie + combat-resources
function Mock.loadCore()
    Mock.load('server_config', 'resources/[server]/server_config/config.lua')
    Mock.load('server_config', 'resources/[server]/server_config/locale_nl.lua')
end

--- Eenvoudige assert-helpers
Test = { passed = 0, failed = 0, failures = {} }
function Test.eq(actual, expected, msg)
    if actual == expected then Test.passed = Test.passed + 1
    else
        Test.failed = Test.failed + 1
        Test.failures[#Test.failures + 1] = ('%s: verwacht %s, kreeg %s'):format(msg or '?', tostring(expected), tostring(actual))
    end
end
function Test.ok(cond, msg) Test.eq(not not cond, true, msg) end
function Test.no(cond, msg) Test.eq(not not cond, false, msg) end
function Test.case(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
        Test.failed = Test.failed + 1
        Test.failures[#Test.failures + 1] = ('%s: SCRIPTFOUT %s'):format(name, err)
    end
end
