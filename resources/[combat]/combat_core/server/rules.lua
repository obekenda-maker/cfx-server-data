--[[
    combat_core/server/rules.lua – deelname, verlaten, dood, respawn en grenscontrole.
    Alles wat geld, wapens of kills raakt wordt HIER server-side besloten.
]]

local function jobName(xPlayer)
    local job = xPlayer.job
    if not job and xPlayer.getJob then job = xPlayer.getJob() end
    return (job and job.name) or 'unemployed'
end

function Combat.jobRule(xPlayer)
    return CombatCfg.JobRules[jobName(xPlayer)] or CombatCfg.JobRules.default
end

function Combat.isInCombat(src)
    return Combat.Players[src] ~= nil
end

local function stateBag(src)
    local ok, bag = pcall(function() return Player(src).state end)
    if ok then return bag end
    return nil
end

local function accountMoney(xPlayer, account)
    if account == 'money' then return xPlayer.getMoney() end
    local acc = xPlayer.getAccount(account)
    return acc and acc.money or 0
end

function Combat.loadoutPayload(key)
    local lo = CombatCfg.Loadouts[key]
    local weapons = {}
    for _, w in ipairs(lo.weapons) do
        weapons[#weapons + 1] = { name = w.name, ammo = w.ammo or 0, components = w.components or {} }
    end
    return { key = key, label = lo.label, health = lo.health or 200, armor = lo.armor or 0, weapons = weapons }
end

---------------------------------------------------------------------------
-- Toegang
---------------------------------------------------------------------------
--- Bij toegangsbeperkte zones (ganggevechten): welk team hoort deze speler?
function Combat.accessTeam(src, zone)
    if not zone.access or not zone.access.gangs then return nil end
    local ok, gangId = pcall(function() return exports.rp_gangs:GetGangId(src) end)
    if not ok or not gangId then return nil end
    for i, id in ipairs(zone.access.gangs) do
        if id == gangId then return zone.teams and zone.teams[i] and zone.teams[i].id or i end
    end
    return nil
end

function Combat.canJoin(src, zoneId)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false, 'combat.not_loaded' end

    local zone = Combat.Zones[zoneId]
    if not zone then return false, 'combat.zone_unknown' end
    if Combat.Players[src] then return false, 'combat.already_joined' end
    if (Combat.Cooldowns[src] or 0) > Combat.now() then return false, 'combat.cooldown' end

    local rule = Combat.jobRule(xPlayer)
    if not rule.canJoin then return false, rule.reason or 'combat.job_blocked_duty' end

    local accessTeam
    if zone.access then
        accessTeam = Combat.accessTeam(src, zone)
        if not accessTeam then return false, 'combat.no_access' end
    end

    if Combat.countPlayers(zone.id) >= zone.maxPlayers then return false, 'combat.zone_full' end

    local okStats, stats = pcall(function() return exports.combat_stats:Get(src) end)
    local level = (okStats and stats and stats.level) or 1
    if level < zone.minLevel then return false, 'combat.level_low', zone.minLevel end

    local ped = GetPlayerPed(src)
    local coords = Combat.coordsOf(src)
    if not ped or ped == 0 or not coords then return false, 'combat.not_in_zone' end
    if CombatUtil.dist(coords, zone.coords) > zone.radius + CombatCfg.Rules.zoneMargin then
        return false, 'combat.not_in_zone'
    end
    if Combat.safeZoneAt(coords) then return false, 'combat.safe_zone' end
    if CombatCfg.Rules.blockVehicles and GetVehiclePedIsIn(ped, false) ~= 0 then
        return false, 'combat.in_vehicle'
    end
    if GetEntityHealth(ped) <= 0 then return false, 'combat.dead' end

    local bag = stateBag(src)
    if bag and bag.isCuffed then return false, 'combat.cuffed' end

    if zone.entryFee > 0 and accountMoney(xPlayer, zone.entryFeeAccount) < zone.entryFee then
        return false, 'combat.no_money', zone.entryFee
    end

    return true, nil, zone, accessTeam
end

---------------------------------------------------------------------------
-- State naar clients
---------------------------------------------------------------------------
function Combat.statePayload(src)
    local p = Combat.Players[src]
    if not p then return { active = false } end
    local zone = Combat.Zones[p.zone]
    if not zone then return { active = false } end
    local teamLabel
    if zone.mode == 'team' then
        teamLabel = zone.teams[Combat.teamIndex(zone, p.team)].label
    end
    return {
        active = true,
        zone = { id = zone.id, label = zone.label, mode = zone.mode },
        team = p.team, teamLabel = teamLabel,
        kills = p.kills, deaths = p.deaths, streak = p.streak,
        scores = Combat.Scores[zone.id] or {},
        teams = zone.teams, scoreLimit = zone.mode == 'team' and zone.scoreLimit or nil,
        players = Combat.countPlayers(zone.id),
    }
end

function Combat.pushState(src)
    TriggerClientEvent('combat:state', src, Combat.statePayload(src))
end

function Combat.pushZoneState(zoneId)
    for _, src in ipairs(Combat.zoneMembers(zoneId)) do Combat.pushState(src) end
end

---------------------------------------------------------------------------
-- RP-loadout veiligstellen
-- ESX schrijft munitie van het huidige wapen terug naar de loadout als de wapennaam
-- overeenkomt (esx:updateWeaponAmmo). Daarom: snapshot bij deelname, handhaven per tick,
-- herstellen bij verlaten. Zo kan combat-munitie nooit in de RP-loadout/DB terechtkomen.
---------------------------------------------------------------------------
local function snapshotLoadout(xPlayer)
    local out = {}
    local ok, loadout = pcall(function() return xPlayer.getLoadout() end)
    if not ok or type(loadout) ~= 'table' then return out end
    for _, w in ipairs(loadout) do
        out[#out + 1] = {
            name = w.name, ammo = w.ammo or 0,
            components = w.components or {}, tintIndex = w.tintIndex or 0,
        }
    end
    return out
end

local function overlapNames(zone, rpLoadout)
    local combatNames = {}
    for _, key in ipairs(zone.loadouts) do
        for _, w in ipairs(CombatCfg.Loadouts[key].weapons) do combatNames[w.name] = true end
    end
    local overlap = {}
    for _, w in ipairs(rpLoadout) do
        if combatNames[w.name] then overlap[#overlap + 1] = w end
    end
    return overlap
end

local function enforceRpAmmo(xPlayer, p)
    if not p.rpOverlap then return end
    for _, w in ipairs(p.rpOverlap) do
        local ok = pcall(function() xPlayer.updateWeaponAmmo(w.name, w.ammo) end)
        if not ok then break end
    end
end
Combat.enforceRpAmmo = enforceRpAmmo

---------------------------------------------------------------------------
-- Deelnemen
---------------------------------------------------------------------------
function Combat.join(src, zoneId, loadoutKey)
    local ok, reason, zoneOrParam, accessTeam = Combat.canJoin(src, zoneId)
    if not ok then return nil, reason, zoneOrParam end
    local zone = zoneOrParam
    local xPlayer = ESX.GetPlayerFromId(src)

    if not loadoutKey or not ServerCfg.Contains(zone.loadouts, loadoutKey) then
        loadoutKey = zone.loadouts[1]
    end

    if zone.entryFee > 0 then
        if zone.entryFeeAccount == 'money' then
            xPlayer.removeMoney(zone.entryFee, 'Combat entree ' .. zone.id)
        else
            xPlayer.removeAccountMoney(zone.entryFeeAccount, zone.entryFee, 'Combat entree ' .. zone.id)
        end
        exports.server_logs:Log('money', 'Combat entreegeld', ('%s betaalde €%d (%s) voor %s'):format(
            exports.server_logs:Describe(src), zone.entryFee, zone.entryFeeAccount, zone.label))
    end

    local team
    if zone.mode == 'team' then
        team = accessTeam or Combat.balancedTeam(zone)
    end

    local now = Combat.now()
    local protection = CombatCfg.Rules.spawnProtectionSeconds
    local p = {
        zone = zone.id, team = team, loadout = loadoutKey, joinedAt = now, alive = true,
        spawnedAt = now, protectedUntil = now + protection * 1000,
        streak = 0, kills = 0, deaths = 0, lastDamageAt = -100000000, lastDamageBy = nil,
        respawns = {}, outsideTicks = 0, identifier = xPlayer.identifier,
        name = (xPlayer.getName and xPlayer.getName()) or GetPlayerName(src),
    }
    p.rpLoadout = snapshotLoadout(xPlayer)
    p.rpOverlap = overlapNames(zone, p.rpLoadout)
    Combat.Players[src] = p
    Combat.Cooldowns[src] = nil

    local bag = stateBag(src)
    if bag then
        bag:set('inCombat', true, true)
        bag:set('combatZone', zone.id, true)
        bag:set('combatTeam', team or 0, true)
    end

    local spawn = Combat.pickSpawn(zone, team, src)
    Combat.pushZoneState(zone.id)

    exports.server_logs:Log('combat', 'PvP deelname', ('%s doet mee in %s (loadout: %s)'):format(
        exports.server_logs:Describe(src), zone.label, loadoutKey))

    return {
        zone = Combat.zonePublic(zone), team = team, spawn = spawn,
        loadout = Combat.loadoutPayload(loadoutKey), protection = protection,
        state = Combat.statePayload(src),
    }
end

---------------------------------------------------------------------------
-- Verlaten
---------------------------------------------------------------------------
local function auditWeapons(src, zone, identifier)
    if not CombatCfg.Rules.auditWeaponsAfterLeave then return end
    SetTimeout(3500, function()
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer or xPlayer.identifier ~= identifier or Combat.Players[src] then return end
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return end
        local selected = GetSelectedPedWeapon(ped)
        for _, key in ipairs(zone.loadouts) do
            for _, w in ipairs(CombatCfg.Loadouts[key].weapons) do
                if joaat(w.name) == selected and not xPlayer.hasWeapon(w.name) then
                    RemoveWeaponFromPed(ped, selected)
                    exports.server_logs:Log('suspicious', 'Combatwapen na verlaten zone',
                        ('%s had %s nog na het verlaten van %s (verwijderd).'):format(
                            exports.server_logs:Describe(src), w.name, zone.label))
                    return
                end
            end
        end
    end)
end

function Combat.leave(src, reasonKey, dropped)
    local p = Combat.Players[src]
    if not p then return false end
    local zone = Combat.Zones[p.zone]

    Combat.Players[src] = nil
    Combat.Cooldowns[src] = Combat.now() + CombatCfg.Rules.joinCooldownSeconds * 1000

    if not dropped then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then enforceRpAmmo(xPlayer, p) end
        local bag = stateBag(src)
        if bag then
            bag:set('inCombat', false, true)
            bag:set('combatZone', nil, true)
            bag:set('combatTeam', 0, true)
        end
        TriggerClientEvent('combat:left', src, reasonKey or 'combat.left', p.rpLoadout)
    end

    if zone then
        Combat.pushZoneState(zone.id)
        if not dropped then auditWeapons(src, zone, p.identifier) end
        exports.server_logs:Log('combat', 'PvP verlaten', ('%s verliet %s (kills %d, deaths %d)'):format(
            p.name or ('#' .. src), zone.label, p.kills, p.deaths))
    end
    return true
end

---------------------------------------------------------------------------
-- Dood
---------------------------------------------------------------------------
--- Wordt aangeroepen met een CLAIM van de client van het slachtoffer.
--- Alles wordt hier opnieuw server-side gecontroleerd.
function Combat.handleDeath(src, killerId, weaponHash)
    local p = Combat.Players[src]
    if not p or not p.alive then return end -- onbekend of al verwerkt (dubbele melding)

    local zone = Combat.Zones[p.zone]
    if not zone then return end

    local now = Combat.now()
    p.alive = false
    p.diedAt = now
    p.deaths = p.deaths + 1
    p.streak = 0

    killerId = tonumber(killerId)
    weaponHash = tonumber(weaponHash) or 0

    local credited = false
    local flag -- reden waarom een claim werd afgewezen

    if killerId and killerId ~= src then
        local k = Combat.Players[killerId]
        if not k then
            flag = 'killer is geen deelnemer'
        elseif k.zone ~= p.zone then
            flag = 'killer zit in andere zone'
        elseif not k.alive and (now - (k.diedAt or 0)) > CombatCfg.Rules.mutualKillWindowMs then
            flag = 'killer was al dood'
        elseif zone.mode == 'team' and k.team == p.team then
            flag = 'teamkill'
        elseif now < p.protectedUntil then
            flag = 'slachtoffer had beschermtijd'
        else
            local kc, vc = Combat.coordsOf(killerId), Combat.coordsOf(src)
            if kc and vc and CombatUtil.dist(kc, vc) > CombatCfg.Rules.maxKillDistance then
                flag = 'afstand te groot'
            elseif CombatCfg.Rules.strictDamageCheck
                and not (p.lastDamageBy == killerId
                    and (now - p.lastDamageAt) <= CombatCfg.Rules.killWindowSeconds * 1000) then
                flag = 'geen schade van killer gezien'
            else
                credited = true
            end
        end

        if flag then
            exports.server_logs:Log('suspicious', 'Afgewezen kill-claim', ('Slachtoffer %s claimt killer #%d: %s'):format(
                exports.server_logs:Describe(src), killerId, flag))
        end
    end

    if credited then
        Combat.processKill(killerId, src, zone, weaponHash)
    else
        if CombatCfg.Rules.countEnvironmentDeaths and zone.countStats then
            pcall(function() exports.combat_stats:RecordDeath(src) end)
        end
        Combat.killfeed(zone, nil, src, weaponHash)
    end
    Combat.pushZoneState(zone.id)
end

---------------------------------------------------------------------------
-- Respawn
---------------------------------------------------------------------------
function Combat.respawn(src)
    local p = Combat.Players[src]
    if not p then return nil, 'combat.not_joined' end
    if p.alive then return nil, 'combat.not_dead' end
    local zone = Combat.Zones[p.zone]
    if not zone then return nil, 'combat.zone_unknown' end

    local now = Combat.now()
    local need = CombatCfg.Rules.respawnSeconds * 1000 - 400 -- 400 ms tolerantie voor netwerklatentie
    if now - p.diedAt < need then
        return nil, 'combat.respawn_wait', math.ceil((need - (now - p.diedAt)) / 1000)
    end

    local recent = {}
    for _, t in ipairs(p.respawns) do
        if now - t < 60000 then recent[#recent + 1] = t end
    end
    p.respawns = recent
    if #recent >= CombatCfg.Rules.respawnMaxPerMinute then
        return nil, 'combat.respawn_limit'
    end
    recent[#recent + 1] = now

    local protection = CombatCfg.Rules.spawnProtectionSeconds
    p.alive = true
    p.spawnedAt = now
    p.protectedUntil = now + protection * 1000
    p.lastDamageBy = nil
    p.outsideTicks = 0

    local spawn = Combat.pickSpawn(zone, p.team, src)
    return {
        spawn = spawn, loadout = Combat.loadoutPayload(p.loadout), protection = protection,
        state = Combat.statePayload(src),
    }
end

---------------------------------------------------------------------------
-- Grenscontrole (1×/tick)
---------------------------------------------------------------------------
function Combat.tick()
    local now = Combat.now()
    local expired = {}
    for id, zone in pairs(Combat.Zones) do
        if zone.expiresAt and os.time() >= zone.expiresAt then expired[#expired + 1] = id end
    end
    for _, id in ipairs(expired) do
        for _, src in ipairs(Combat.zoneMembers(id)) do Combat.leave(src, 'combat.left_forced') end
        Combat.unregisterZone(id)
        TriggerClientEvent('combat:zoneRemove', -1, id)
    end

    for src, p in pairs(Combat.Players) do
        local zone = Combat.Zones[p.zone]
        if not zone then
            Combat.leave(src, 'combat.left_forced')
        else
            if p.rpOverlap and #p.rpOverlap > 0 then
                local xPlayer = ESX.GetPlayerFromId(src)
                if xPlayer then enforceRpAmmo(xPlayer, p) end
            end
        end
        if zone and p.alive then
            local c = Combat.coordsOf(src)
            if c and Combat.safeZoneAt(c) then
                Combat.leave(src, 'combat.left_safe')   -- beschermd RP-gebied betreden: altijd uit de PvP
            elseif c then
                if CombatUtil.dist(c, zone.coords) > zone.radius + CombatCfg.Rules.zoneMargin then
                    p.outsideTicks = p.outsideTicks + 1
                    if p.outsideTicks >= CombatCfg.Rules.leaveConfirmTicks then
                        Combat.leave(src, 'combat.left_outside')
                    end
                else
                    p.outsideTicks = 0
                end
            end
        end
    end
    return now
end
