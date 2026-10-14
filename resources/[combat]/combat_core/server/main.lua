--[[
    combat_core/server/main.lua – callbacks, events, exports, lifecycle.
]]

local throttle = ServerCfg.Throttle

local function reply(ok, reason, param, data)
    return { ok = ok, reason = reason, param = param, data = data }
end

---------------------------------------------------------------------------
-- Callbacks (client → server)
---------------------------------------------------------------------------
lib.callback.register('combat:getZones', function(source)
    if not throttle(source, 'zones', 400) then return {} end
    local list = {}
    for _, id in ipairs(Combat.ZoneOrder) do
        local zone = Combat.Zones[id]
        if not zone.access or Combat.accessTeam(source, zone) then
            list[#list + 1] = Combat.zonePublic(zone)
        end
    end
    return list
end)

lib.callback.register('combat:getCounts', function(source)
    if not throttle(source, 'counts', 400) then return {} end
    local counts = {}
    for _, id in ipairs(Combat.ZoneOrder) do
        counts[id] = Combat.countPlayers(id)
    end
    return counts
end)

lib.callback.register('combat:join', function(source, zoneId, loadoutKey)
    if type(zoneId) ~= 'string' or (loadoutKey ~= nil and type(loadoutKey) ~= 'string') then
        return reply(false, 'combat.zone_unknown')
    end
    if not throttle(source, 'join', 1000) then return reply(false, 'combat.too_fast') end
    local data, reason, param = Combat.join(source, zoneId, loadoutKey)
    if not data then return reply(false, reason, param) end
    return reply(true, nil, nil, data)
end)

lib.callback.register('combat:leave', function(source)
    local p = Combat.Players[source]
    if not p then return reply(false, 'combat.not_joined') end
    local tag = CombatCfg.Rules.combatTagSeconds * 1000
    if Combat.now() - p.lastDamageAt < tag and p.alive then
        return reply(false, 'combat.tagged', CombatCfg.Rules.combatTagSeconds)
    end
    Combat.leave(source, 'combat.left')
    return reply(true)
end)

lib.callback.register('combat:respawn', function(source)
    if not throttle(source, 'respawn', 800) then return reply(false, 'combat.too_fast') end
    local data, reason, param = Combat.respawn(source)
    if not data then return reply(false, reason, param) end
    return reply(true, nil, nil, data)
end)

---------------------------------------------------------------------------
-- Events (client → server): altijd valideren
---------------------------------------------------------------------------
RegisterNetEvent('combat:died', function(killerId, weaponHash)
    local src = source
    if type(killerId) ~= 'number' and killerId ~= nil then return end
    if type(weaponHash) ~= 'number' and weaponHash ~= nil then return end
    if not throttle(src, 'died', 1500) then return end
    Combat.handleDeath(src, killerId, weaponHash)
end)

RegisterNetEvent('combat:protectionBroken', function()
    if not throttle(source, 'prot', 500) then return end
    local p = Combat.Players[source]
    if p and p.protectedUntil > Combat.now() then
        p.protectedUntil = Combat.now()
    end
end)

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    Combat.leave(src, nil, true)
    Combat.Cooldowns[src] = nil
end)

-- Jobwissel tijdens PvP (bijv. politie gaat in dienst) → direct verlaten
AddEventHandler('esx:setJob', function(src)
    if not Combat.Players[src] then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not Combat.jobRule(xPlayer).canJoin then
        Combat.leave(src, 'combat.left_job')
    end
end)

CreateThread(function()
    Combat.loadStaticZones()
    print(('^2[combat_core]^7 %d zone(s) geladen.'):format(#Combat.ZoneOrder))
    while true do
        Wait(CombatCfg.Rules.tickMs)
        Combat.tick()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Combat.Players) do
        local ok, bag = pcall(function() return Player(src).state end)
        if ok and bag then
            bag:set('inCombat', false, true)
            bag:set('combatZone', nil, true)
        end
        TriggerClientEvent('combat:left', src, 'combat.left_forced')
    end
end)

---------------------------------------------------------------------------
-- Exports voor andere resources
---------------------------------------------------------------------------
exports('IsInCombat', function(src) return Combat.isInCombat(src) end)

exports('GetPlayerZone', function(src)
    local p = Combat.Players[src]
    return p and p.zone or nil
end)

exports('GetZonePlayers', function(zoneId) return Combat.zoneMembers(zoneId) end)

exports('ForceLeave', function(src, reasonKey)
    return Combat.leave(src, reasonKey or 'combat.left_forced')
end)

--- Tijdelijke zone (bijv. ganggevecht). `def` bevat gewone tabellen {x,y,z}, geen vectoren.
--- Vereist: id, coords, radius. Optioneel: label, mode, teams, access={gangs={..}}, loadouts,
--- durationSeconds, rewards=false, countStats=false, scoreLimit.
exports('CreateTemporaryZone', function(def)
    if type(def) ~= 'table' then return false end
    if def.durationSeconds then def.expiresAt = os.time() + math.floor(def.durationSeconds) end
    local ok, zone = pcall(Combat.registerZone, def, true)
    if not ok then
        print('^1[combat_core]^7 CreateTemporaryZone mislukt: ' .. tostring(zone))
        return false
    end
    local public = Combat.zonePublic(zone)
    for _, id in ipairs(ESX.GetPlayers()) do
        local src = tonumber(id)
        if not zone.access or Combat.accessTeam(src, zone) then
            TriggerClientEvent('combat:zoneAdd', src, public)
        end
    end
    return true
end)

exports('RemoveTemporaryZone', function(id)
    local zone = Combat.Zones[id]
    if not zone or not zone.temporary then return false end
    for _, src in ipairs(Combat.zoneMembers(id)) do Combat.leave(src, 'combat.left_forced') end
    Combat.unregisterZone(id)
    TriggerClientEvent('combat:zoneRemove', -1, id)
    return true
end)

exports('GetZoneScores', function(id)
    return Combat.Scores[id]
end)
