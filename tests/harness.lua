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

local function jsonEncode(v)
    local t = type(v)
    if v == nil then return 'null' end
    if t == 'boolean' then return tostring(v) end
    if t == 'number' then
        if math.type(v) == 'integer' then return tostring(v) end
        return string.format('%.14g', v)
    end
    if t == 'string' then
        return '"' .. v:gsub('[%c"\\]', function(c)
            local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
            return map[c] or string.format('\\u%04x', c:byte())
        end) .. '"'
    end
    if t == 'table' then
        local n, count = #v, 0
        for _ in pairs(v) do count = count + 1 end
        if n == count and n > 0 then
            local out = {}
            for i = 1, n do out[i] = jsonEncode(v[i]) end
            return '[' .. table.concat(out, ',') .. ']'
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        local out = {}
        for _, k in ipairs(keys) do
            local val = v[k]; if val == nil then val = v[tonumber(k)] end
            out[#out + 1] = jsonEncode(k) .. ':' .. jsonEncode(val)
        end
        return '{' .. table.concat(out, ',') .. '}'
    end
    error('json: niet ondersteund type ' .. t)
end

local function jsonDecode(str)
    local pos = 1
    local function ws() pos = str:find('%S', pos) or #str + 1 end
    local value
    local function string_()
        local out, i = {}, pos + 1
        while true do
            local c = str:sub(i, i)
            if c == '"' then pos = i + 1 return table.concat(out) end
            if c == '\\' then
                local n = str:sub(i + 1, i + 1)
                local map = { n = '\n', t = '\t', r = '\r', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
                if n == 'u' then out[#out + 1] = utf8.char(tonumber(str:sub(i + 2, i + 5), 16)); i = i + 6
                else out[#out + 1] = map[n] or n; i = i + 2 end
            else out[#out + 1] = c; i = i + 1 end
        end
    end
    function value()
        ws()
        local c = str:sub(pos, pos)
        if c == '{' then
            local obj = {}; pos = pos + 1; ws()
            if str:sub(pos, pos) == '}' then pos = pos + 1 return obj end
            while true do
                ws(); local k = string_(); ws(); assert(str:sub(pos, pos) == ':', 'json: ":" verwacht'); pos = pos + 1
                obj[k] = value(); ws()
                local d = str:sub(pos, pos); pos = pos + 1
                if d == '}' then return obj end
                assert(d == ',', 'json: "," verwacht')
            end
        elseif c == '[' then
            local arr = {}; pos = pos + 1; ws()
            if str:sub(pos, pos) == ']' then pos = pos + 1 return arr end
            while true do
                arr[#arr + 1] = value(); ws()
                local d = str:sub(pos, pos); pos = pos + 1
                if d == ']' then return arr end
                assert(d == ',', 'json: "," verwacht')
            end
        elseif c == '"' then return string_()
        elseif str:sub(pos, pos + 3) == 'true' then pos = pos + 4 return true
        elseif str:sub(pos, pos + 4) == 'false' then pos = pos + 5 return false
        elseif str:sub(pos, pos + 3) == 'null' then pos = pos + 4 return nil
        else
            local num = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
            assert(num and #num > 0, 'json: ongeldig op positie ' .. pos)
            pos = pos + #num
            return math.tointeger(tonumber(num)) or tonumber(num)
        end
    end
    local result = value()
    return result
end

json = { encode = jsonEncode, decode = function(str) local ok, r = pcall(jsonDecode, str) if not ok then error(r) end return r end }

function PerformHttpRequest(url, cb, method, body, headers)
    Mock.http[#Mock.http + 1] = { url = url, body = body, cb = cb }
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
Mock.clientCallbacks = {}   -- [name] = function(target, ...) → resultaat (simuleert client-reactie)
lib = {
    callback = {
        register = function(name, fn) Mock.callbacks[name] = fn end,
        await = function(name, target, ...)
            local fn = Mock.clientCallbacks[name]
            assert(fn, 'geen client-callback gemockt: ' .. name)
            return fn(target, ...)
        end,
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

function GetEntityCoords(ped)
    if ped >= 1000 and ped < 2000 then return playerOfPed(ped).coords end
    return Mock.vehicles[ped].coords
end
function GetEntityHealth(ped) return playerOfPed(ped).health or 200 end
function GetVehiclePedIsIn(ped) return playerOfPed(ped).vehicle or 0 end
function GetPlayerFromServerId(id) return id end
function GetSelectedPedWeapon(ped) return playerOfPed(ped).selectedWeapon or joaat('WEAPON_UNARMED') end
function RemoveWeaponFromPed(ped, hash) playerOfPed(ped).removedWeapon = hash end
function GetPlayerName(src) return Mock.players[src] and Mock.players[src].name or nil end
function GetPlayerIdentifiers(src) return Mock.players[src] and Mock.players[src].identifiers or {} end
function DoesEntityExist(e) if e >= 1000 and e < 2000 then return Mock.players[e - 1000] ~= nil end return Mock.vehicles[e] ~= nil end
function GetEntityType() return 1 end
function NetworkGetEntityFromNetworkId(id) return Mock.vehNet[id] or id end
function NetworkGetEntityOwner(e) return e - 1000 end

Mock.vehicles = {}   -- [entityId] = { model=, plate=, coords=, netId= }
Mock.vehNet = {}
function Mock.addVehicle(entity, model, plate, coords)
    Mock.vehicles[entity] = { model = joaat(model), plate = plate, coords = coords or { x = 0.0, y = 0.0, z = 0.0 }, netId = entity + 5000 }
    Mock.vehNet[entity + 5000] = entity
    return entity + 5000
end
function GetAllVehicles() local l = {} for e in pairs(Mock.vehicles) do l[#l + 1] = e end return l end
function GetVehicleNumberPlateText(e) return Mock.vehicles[e] and Mock.vehicles[e].plate or '' end
function GetEntityModel(e) return Mock.vehicles[e] and Mock.vehicles[e].model or 0 end
function DeleteEntity(e) Mock.vehicles[e] = nil Mock.deleted = e end
function SetEntityCoords(ped, x, y, z) Mock.players[ped - 1000].coords = { x = x, y = y, z = z } end
function DropPlayer(src, reason) Mock.dropped = { src = src, reason = reason } end
function GetPlayerPing() return 42 end
function NetworkGetNetworkIdFromEntity(e) return e + 5000 end
function Mock.setVehicleOf(src, entity) Mock.players[src].vehicle = entity end

Citizen.Await = function(p) return p.value end
promise = { new = function() local p = { resolve = function(self, v) self.value = v end } return p end }

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
Mock.jobs = {}
for _, n in ipairs({ 'unemployed', 'police', 'offpolice', 'ambulance', 'offambulance', 'mechanic', 'offmechanic', 'taxi', 'trucker', 'courier' }) do
    Mock.jobs[n] = { name = n, grades = { ['0'] = {}, ['1'] = {}, ['2'] = {}, ['3'] = {}, ['4'] = {} } }
end
Mock.usable = {}
ESX = {
    GetJobs = function() return Mock.jobs end,
    RegisterUsableItem = function(name, fn) Mock.usable[name] = fn end,
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
        job = { name = opts.job or 'unemployed', grade = opts.grade or 0, grade_name = opts.grade_name or 'agent' },
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
    function xp.setJob(name, grade) local last = xp.job; xp.job = { name = name, grade = grade or 0, grade_name = last.grade_name }; TriggerEvent('esx:setJob', src, xp.job, last) end
    function xp.getGroup() return xp.group end
    function xp.getLoadout() local c = {}; for i, w in ipairs(xp.loadout) do c[i] = { name = w.name, ammo = w.ammo, components = w.components or {}, tintIndex = w.tintIndex or 0 } end return c end
    function xp.updateWeaponAmmo(name, ammo) for _, w in ipairs(xp.loadout) do if w.name == name then w.ammo = ammo end end end
    function xp.hasWeapon(name) for _, w in ipairs(xp.loadout) do if w.name == name then return true end end return false end
    function xp.showNotification(msg) xp.notified[#xp.notified + 1] = msg end
    function xp.getInventoryItem(name) return { name = name, label = name, count = xp.inventory[name] or 0 } end
    function xp.addInventoryItem(name, n) xp.inventory[name] = (xp.inventory[name] or 0) + n end
    function xp.removeInventoryItem(name, n) xp.inventory[name] = (xp.inventory[name] or 0) - n end
    function xp.canCarryItem() return not xp.noCarry end
    function xp.getInventory() local l = {} for n, c in pairs(xp.inventory) do l[#l + 1] = { name = n, label = n, count = c } end return l end
    function xp.addWeapon(name, ammo) table.insert(xp.loadout, { name = name, ammo = ammo }) end
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
-- oxmysql → ECHTE MariaDB via Python-brug (__db wordt door run_tests.py geleverd)
-- Controleert ook dat parameterlijsten geen nil-gaten bevatten (breekt msgpack naar oxmysql).
---------------------------------------------------------------------------
local function checkParams(q, p)
    if p == nil then return {} end
    assert(type(p) == 'table', 'parameters moeten een tabel zijn: ' .. q)
    local n, count = #p, 0
    for _ in pairs(p) do count = count + 1 end
    assert(n == count, 'parameterlijst met nil-gat: ' .. q)
    return p
end

local function dbcall(mode, q, p)
    p = checkParams(q, p)
    return __db(mode, q, p, #p)
end

local function wrap(mode)
    return setmetatable({ await = function(q, p) return dbcall(mode, q, p) end }, {
        __call = function(_, q, p, cb)
            local r = dbcall(mode, q, p)
            if cb then cb(r) end
            return r
        end,
    })
end
MySQL = { single = wrap('single'), scalar = wrap('scalar'), insert = wrap('insert'), update = wrap('update'), query = wrap('query') }

--- Direct SQL voor tests (rijen als lijst van tabellen)
DB = {}
function DB.query(q, p) return dbcall('query', q, p or {}) end
function DB.one(q, p) return dbcall('single', q, p or {}) end
function DB.scalar(q, p) return dbcall('scalar', q, p or {}) end
function DB.exec(q, p) return dbcall('update', q, p or {}) end

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

--- Laad ALLE eigen serverbestanden (zoals bij een echte serverstart) en laat de opstartthreads lopen
function Mock.loadAll()
    Mock.loadCore()
    local function res(name, group, files)
        for _, f in ipairs(files) do Mock.load(name, ('resources/%s/%s/%s.lua'):format(group, name, f)) end
    end
    res('combat_stats', '[combat]', { 'config', 'server/main' })
    res('combat_core', '[combat]', { 'config', 'shared/util', 'server/zones', 'server/rules', 'server/rewards', 'server/damage', 'server/main' })
    res('rp_jobs', '[roleplay]', { 'config', 'server/main', 'server/police', 'server/medic', 'server/mechanic', 'server/taxi', 'server/delivery' })
    res('rp_garages', '[roleplay]', { 'config', 'server/main' })
    res('rp_shops', '[roleplay]', { 'config', 'server/main' })
    res('rp_interactions', '[roleplay]', { 'config', 'server/main' })
    res('rp_gangs', '[roleplay]', { 'config', 'server/main', 'server/territory', 'server/market' })
    res('admin_tools', '[admin]', { 'server/main' })
    Mock.stepThreads()
end
