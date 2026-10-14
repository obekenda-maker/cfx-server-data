--[[
    combat_core/server/zones.lua – zone-register (statisch + tijdelijk) en spawnkeuze.
    Alle toestand staat in de globale tabel `Combat` (gedeeld tussen de serverbestanden).
]]

Combat = {
    Zones     = {},   -- [id] = genormaliseerde zone
    ZoneOrder = {},   -- volgorde van id's
    Players   = {},   -- [source] = spelerstatus (alleen deelnemers)
    Scores    = {},   -- [zoneId] = { [teamId] = punten }
    Cooldowns = {},   -- [source] = tijdstip (ms) tot wanneer niet opnieuw gejoind mag worden
}

function Combat.now()
    return GetGameTimer()
end

function Combat.debug(...)
    if CombatCfg.Debug then print('^3[combat_core]^7', ...) end
end

--- Server-side coördinaten van een speler (OneSync).
function Combat.coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

---------------------------------------------------------------------------
-- Zone normaliseren
---------------------------------------------------------------------------
local function normalizeLoadouts(list, zoneId)
    local out = {}
    for _, key in ipairs(list or {}) do
        if CombatCfg.Loadouts[key] then
            out[#out + 1] = key
        else
            print(('^3[combat_core]^7 Zone %s verwijst naar onbekende loadout "%s" – genegeerd.'):format(zoneId, tostring(key)))
        end
    end
    if #out == 0 then
        -- val terug op alle loadouts zodat de zone bruikbaar blijft
        for key in pairs(CombatCfg.Loadouts) do out[#out + 1] = key end
        table.sort(out)
    end
    return out
end

function Combat.normalizeZone(def, temporary)
    assert(type(def) == 'table' and def.id and def.coords and def.radius, 'ongeldige zonedefinitie')
    local zone = {
        id               = tostring(def.id),
        label            = def.label or tostring(def.id),
        coords           = CombatUtil.xyz(def.coords),
        radius           = (def.radius or 100.0) + 0.0,
        mode             = def.mode == 'team' and 'team' or 'ffa',
        maxPlayers       = def.maxPlayers or 24,
        minLevel         = def.minLevel or 1,
        entryFee         = def.entryFee or 0,
        entryFeeAccount  = def.entryFeeAccount or 'money',
        rewardMultiplier = def.rewardMultiplier or 1.0,
        loadouts         = normalizeLoadouts(def.loadouts, def.id),
        blip             = def.blip or { sprite = 84, colour = 1, scale = 0.9 },
        scoreLimit       = def.scoreLimit or 30,
        spawnCount       = def.spawnCount or 12,
        temporary        = temporary == true,
        access           = def.access,                        -- { gangs = {id, id} } of nil
        rewards          = def.rewards ~= false,              -- false = geen geld/XP
        countStats       = def.countStats ~= false,           -- false = niet in combat_stats
        expiresAt        = def.expiresAt,
    }

    if def.exit then
        zone.exit = { x = def.exit.x + 0.0, y = def.exit.y + 0.0, z = def.exit.z + 0.0, h = (def.exit.w or def.exit.h or 0.0) + 0.0 }
    end

    if def.spawns and #def.spawns > 0 then
        zone.spawns = {}
        for _, s in ipairs(def.spawns) do
            zone.spawns[#zone.spawns + 1] = { x = s.x + 0.0, y = s.y + 0.0, z = s.z + 0.0, h = (s.w or s.h or 0.0) + 0.0, team = s.team }
        end
    end

    if zone.mode == 'team' then
        local teams = def.teams or CombatCfg.DefaultTeams
        zone.teams = {}
        for i, t in ipairs(teams) do
            zone.teams[i] = { id = t.id or i, label = t.label or ('Team ' .. i), color = t.color or '#ffffff', blipColour = t.blipColour }
        end
        assert(#zone.teams >= 2, 'teamzone heeft minimaal 2 teams nodig: ' .. zone.id)
    end

    return zone
end

function Combat.registerZone(def, temporary)
    local zone = Combat.normalizeZone(def, temporary)
    if not Combat.Zones[zone.id] then
        Combat.ZoneOrder[#Combat.ZoneOrder + 1] = zone.id
    end
    Combat.Zones[zone.id] = zone
    Combat.Scores[zone.id] = {}
    return zone
end

function Combat.unregisterZone(id)
    if not Combat.Zones[id] then return false end
    Combat.Zones[id] = nil
    Combat.Scores[id] = nil
    for i, v in ipairs(Combat.ZoneOrder) do
        if v == id then table.remove(Combat.ZoneOrder, i) break end
    end
    return true
end

function Combat.loadStaticZones()
    for _, def in ipairs(CombatCfg.Zones) do
        local ok, err = pcall(Combat.registerZone, def, false)
        if not ok then
            print(('^1[combat_core]^7 Zone overgeslagen: %s'):format(tostring(err)))
        end
    end
end

--- Serialiseerbare versie voor clients (geen functies, geen vectoren).
function Combat.zonePublic(zone)
    local loadouts = {}
    for _, key in ipairs(zone.loadouts) do
        loadouts[#loadouts + 1] = { key = key, label = CombatCfg.Loadouts[key].label }
    end
    return {
        id = zone.id, label = zone.label, coords = zone.coords, radius = zone.radius,
        mode = zone.mode, maxPlayers = zone.maxPlayers, minLevel = zone.minLevel,
        entryFee = zone.entryFee, entryFeeAccount = zone.entryFeeAccount,
        blip = zone.blip, exit = zone.exit, teams = zone.teams, loadouts = loadouts,
        temporary = zone.temporary, scoreLimit = zone.scoreLimit,
    }
end

---------------------------------------------------------------------------
-- Tellen
---------------------------------------------------------------------------
function Combat.countPlayers(zoneId, teamId)
    local n = 0
    for _, p in pairs(Combat.Players) do
        if p.zone == zoneId and (teamId == nil or p.team == teamId) then n = n + 1 end
    end
    return n
end

function Combat.zoneMembers(zoneId)
    local list = {}
    for src, p in pairs(Combat.Players) do
        if p.zone == zoneId then list[#list + 1] = src end
    end
    return list
end

--- Team met de minste spelers (gelijk → team met laagste score, dan laagste index).
function Combat.balancedTeam(zone)
    local best, bestCount, bestScore
    for i, t in ipairs(zone.teams) do
        local count = Combat.countPlayers(zone.id, t.id)
        local score = (Combat.Scores[zone.id] and Combat.Scores[zone.id][t.id]) or 0
        if not best or count < bestCount or (count == bestCount and score < bestScore) then
            best, bestCount, bestScore = i, count, score
        end
    end
    return zone.teams[best].id
end

function Combat.teamIndex(zone, teamId)
    for i, t in ipairs(zone.teams or {}) do
        if t.id == teamId then return i end
    end
    return 1
end

---------------------------------------------------------------------------
-- Spawnkeuze: kies het punt dat het verst van levende tegenstanders ligt
---------------------------------------------------------------------------
function Combat.pickSpawn(zone, teamId, src)
    local candidates = {}
    if zone.spawns then
        for _, s in ipairs(zone.spawns) do
            if zone.mode ~= 'team' or s.team == nil or s.team == teamId then
                candidates[#candidates + 1] = s
            end
        end
    end
    if #candidates == 0 then
        local ring = CombatUtil.ringSpawns(zone.coords, zone.radius, zone.spawnCount, 0.65)
        if zone.mode == 'team' then
            local teamCount = #zone.teams
            local myIndex = Combat.teamIndex(zone, teamId)
            for _, pt in ipairs(ring) do
                local sector = math.floor(pt.index * teamCount / zone.spawnCount) + 1
                if sector == myIndex then candidates[#candidates + 1] = pt end
            end
        else
            candidates = ring
        end
    end
    if #candidates == 0 then candidates = CombatUtil.ringSpawns(zone.coords, zone.radius, zone.spawnCount, 0.65) end

    local enemies = {}
    for s, p in pairs(Combat.Players) do
        if s ~= src and p.zone == zone.id and p.alive and (zone.mode ~= 'team' or p.team ~= teamId) then
            local c = Combat.coordsOf(s)
            if c then enemies[#enemies + 1] = c end
        end
    end

    local best, bestScore
    for _, pt in ipairs(candidates) do
        local minDist = 1e9
        for _, e in ipairs(enemies) do
            local d = CombatUtil.dist2d(pt, e)
            if d < minDist then minDist = d end
        end
        -- lichte willekeur zodat spawns niet voorspelbaar zijn
        local score = minDist + math.random() * 10.0
        if not bestScore or score > bestScore then best, bestScore = pt, score end
    end
    return { x = best.x, y = best.y, z = best.z, h = best.h or 0.0 }
end
