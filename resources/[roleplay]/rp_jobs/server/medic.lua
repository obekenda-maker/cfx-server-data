--[[
    rp_jobs/server/medic.lua – dood buiten combat, hulp melden, revive door ambulance, ziekenhuis-respawn.
    (Dood BINNEN een combat zone wordt door combat_core afgehandeld.)
]]

local D = JobsCfg.Death

local downAt = {}      -- [source] = GetGameTimer() op moment van dood
local callAt = {}      -- [source] = laatste hulpmelding
local reviveAt = {}    -- [medic] = laatste revive
local killsByKiller = {} -- [identifier] = { times = {} }

local function isDown(src)
    local ped = GetPlayerPed(src)
    return ped and ped ~= 0 and GetEntityHealth(ped) <= 0
end

---------------------------------------------------------------------------
-- Melding van overlijden (claim van client; alleen voor logging + timer)
---------------------------------------------------------------------------
RegisterNetEvent('rp_jobs:died', function(killerId)
    local src = source
    if killerId ~= nil and type(killerId) ~= 'number' then return end
    if not Jobs.throttle(src, 'died', 3000) then return end

    local inCombat = false
    pcall(function() inCombat = exports.combat_core:IsInCombat(src) end)
    if inCombat then return end

    downAt[src] = GetGameTimer()

    if D.logPlayerKills and killerId and killerId ~= src and ESX.GetPlayerFromId(killerId) then
        local killerCombat = false
        pcall(function() killerCombat = exports.combat_core:IsInCombat(killerId) end)
        local xKiller = ESX.GetPlayerFromId(killerId)
        local xVictim = ESX.GetPlayerFromId(src)
        local bucket = killsByKiller[xKiller.identifier] or { times = {} }
        killsByKiller[xKiller.identifier] = bucket
        local now = os.time()
        local fresh = {}
        for _, t in ipairs(bucket.times) do if now - t < 3600 then fresh[#fresh + 1] = t end end
        fresh[#fresh + 1] = now
        bucket.times = fresh

        local text = ('%s heeft %s gedood buiten een combat zone (killer job: %s, slachtoffer job: %s, killer in PvP: %s). %d× in het laatste uur.'):format(
            exports.server_logs:Describe(killerId), exports.server_logs:Describe(src),
            Jobs.jobName(xKiller), Jobs.jobName(xVictim), tostring(killerCombat), #fresh)
        exports.server_logs:Log(#fresh >= D.rdmWarnThreshold and 'suspicious' or 'combat', 'Mogelijke RDM', text)
    end
end)

---------------------------------------------------------------------------
-- Hulp melden → alle medics op dienst
---------------------------------------------------------------------------
lib.callback.register('rp_jobs:callMedics', function(source)
    if not isDown(source) then return { ok = false, msg = 'jobs.not_down' } end
    local now = GetGameTimer()
    if callAt[source] and now - callAt[source] < D.callCooldownSeconds * 1000 then
        return { ok = false, msg = 'jobs.call_wait' }
    end
    callAt[source] = now
    local c = Jobs.coordsOf(source)
    local count = 0
    for _, id in ipairs(ESX.GetPlayers()) do
        local x = ESX.GetPlayerFromId(tonumber(id))
        if x and Jobs.jobName(x) == D.medicJob then
            count = count + 1
            TriggerClientEvent('rp_jobs:medicCall', tonumber(id), source, c)
        end
    end
    return { ok = true, msg = count > 0 and 'jobs.call_sent' or 'jobs.call_nobody' }
end)

---------------------------------------------------------------------------
-- Revive door medic
---------------------------------------------------------------------------
lib.callback.register('rp_jobs:revive', function(source, targetId)
    local xMedic = ESX.GetPlayerFromId(source)
    if not xMedic or Jobs.jobName(xMedic) ~= D.medicJob then return { ok = false, msg = 'jobs.not_medic' } end
    targetId = tonumber(targetId)
    local xTarget = targetId and ESX.GetPlayerFromId(targetId)
    if not xTarget or targetId == source then return { ok = false, msg = 'jobs.no_target' } end
    if reviveAt[source] and GetGameTimer() - reviveAt[source] < 3000 then return { ok = false, msg = 'jobs.too_fast' } end

    local d = Jobs.playerDistance(source, targetId)
    if not d or d > D.reviveDistance + 1.5 then return { ok = false, msg = 'jobs.too_far' } end
    if not isDown(targetId) then return { ok = false, msg = 'jobs.not_down' } end
    local inCombat = false
    pcall(function() inCombat = exports.combat_core:IsInCombat(targetId) end)
    if inCombat then return { ok = false, msg = 'jobs.in_pvp' } end

    reviveAt[source] = GetGameTimer()
    downAt[targetId] = nil

    local fee = Jobs.charge(xTarget, D.reviveFee, 'Behandeling ambulance')
    if fee > 0 then
        Jobs.depositSociety(D.medicSociety, fee)
        ServerCfg.Notify(targetId, 'inform', 'jobs.revive_fee', fee)
    end
    TriggerClientEvent('rp_jobs:revived', targetId, D.reviveHealth)
    exports.server_logs:Log('general', 'Revive', ('%s reanimeerde %s (kosten €%d)'):format(
        exports.server_logs:Describe(source), exports.server_logs:Describe(targetId), fee))
    return { ok = true, msg = 'jobs.revive_ok' }
end)

---------------------------------------------------------------------------
-- Ziekenhuis-respawn (kosten nooit hoger dan het bezit van de speler)
---------------------------------------------------------------------------
lib.callback.register('rp_jobs:hospitalRespawn', function(source)
    if not isDown(source) then return { ok = false, msg = 'jobs.not_down' } end
    local inCombat = false
    pcall(function() inCombat = exports.combat_core:IsInCombat(source) end)
    if inCombat then return { ok = false, msg = 'jobs.in_pvp' } end

    local since = downAt[source] or GetGameTimer()
    if GetGameTimer() - since < D.respawnAfterSeconds * 1000 - 500 then
        return { ok = false, msg = 'jobs.respawn_wait' }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { ok = false, msg = 'jobs.invalid' } end

    -- dichtstbijzijnde ziekenhuis (server-coördinaten)
    local c = Jobs.coordsOf(source)
    local best, bestD
    for _, h in ipairs(D.hospitals) do
        local d = c and Jobs.dist(c, h.coords) or 0
        if not bestD or d < bestD then best, bestD = h, d end
    end

    local fee = Jobs.charge(xPlayer, D.hospitalFee, 'Ziekenhuisopname')
    downAt[source] = nil
    if fee > 0 then
        Jobs.depositSociety(D.medicSociety, fee)
    end
    exports.server_logs:Log('general', 'Ziekenhuis-respawn', ('%s is opgenomen in %s (kosten €%d)'):format(
        exports.server_logs:Describe(source), best.label, fee))
    return { ok = true, spawn = { x = best.coords.x, y = best.coords.y, z = best.coords.z, h = best.coords.w }, fee = fee, label = best.label }
end)

AddEventHandler('playerDropped', function()
    downAt[source], callAt[source], reviveAt[source] = nil, nil, nil
end)
