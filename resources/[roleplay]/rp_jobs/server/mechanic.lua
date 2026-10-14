--[[ rp_jobs/server/mechanic.lua – reparatie (verbruikt een reparatiekit) ]]

local M = JobsCfg.Mechanic

lib.callback.register('rp_jobs:mechanic:finishRepair', function(source, vehNetId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or Jobs.jobName(xPlayer) ~= M.job then return { ok = false, msg = 'jobs.not_mechanic' } end
    if not Jobs.throttle(source, 'repair', 3000) then return { ok = false, msg = 'jobs.too_fast' } end

    -- voertuig moet bestaan en dichtbij zijn
    local netId = tonumber(vehNetId)
    local entity = netId and NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return { ok = false, msg = 'jobs.no_vehicle' } end
    local c, v = Jobs.coordsOf(source), GetEntityCoords(entity)
    if not c or Jobs.dist(c, { x = v.x, y = v.y, z = v.z }) > M.maxDistance + 3.0 then
        return { ok = false, msg = 'jobs.too_far' }
    end

    if M.repairItem ~= '' then
        local item = xPlayer.getInventoryItem(M.repairItem)
        if not item or item.count < 1 then return { ok = false, msg = 'jobs.no_repairkit' } end
        xPlayer.removeInventoryItem(M.repairItem, 1)
    end
    return { ok = true }
end)
