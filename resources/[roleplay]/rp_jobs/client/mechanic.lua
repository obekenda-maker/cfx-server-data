--[[ rp_jobs/client/mechanic.lua – /repareer ]]

local T = ServerCfg.T
local M = JobsCfg.Mechanic

RegisterCommand('repareer', function()
    if RPJ.jobName() ~= M.job then
        RPJ.notify('error', 'jobs.not_mechanic')
        return
    end
    local veh = RPJ.closestVehicle(M.maxDistance)
    if not veh then
        RPJ.notify('error', 'jobs.no_vehicle')
        return
    end
    local done = lib.progressBar({
        duration = M.repairSeconds * 1000,
        label = T('jobs.repair_progress'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 1 },
    })
    if not done then return end

    local res = lib.callback.await('rp_jobs:mechanic:finishRepair', false, NetworkGetNetworkIdFromEntity(veh))
    if res and res.ok then
        NetworkRequestControlOfEntity(veh)
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
        RPJ.notify('success', 'jobs.repair_done')
    else
        RPJ.result(res)
    end
end, false)
TriggerEvent('chat:addSuggestion', '/repareer', T('jobs.cmd_repair'))
