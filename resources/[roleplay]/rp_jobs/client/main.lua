--[[ rp_jobs/client/main.lua – helpers, dienst in/uit, bossmenu ]]

RPJ = {}
local T = ServerCfg.T

function RPJ.notify(kind, key, ...)
    ServerCfg.Notify(nil, kind, key, ...)
end

--- Toon het resultaat-object van een server-callback ({ ok, msg, param })
function RPJ.result(res)
    if not res then return end
    if res.msg then RPJ.notify(res.ok and 'success' or 'error', res.msg, res.param) end
end

function RPJ.jobName()
    if not ESX.IsPlayerLoaded() then return nil end
    local job = ESX.GetPlayerData().job
    return job and job.name or nil
end

function RPJ.gradeName()
    local job = ESX.GetPlayerData().job
    return job and job.grade_name or nil
end

function RPJ.isLoaded() return ESX.IsPlayerLoaded() end

--- Dichtstbijzijnde voertuig binnen `radius`
function RPJ.closestVehicle(radius)
    local p = GetEntityCoords(PlayerPedId())
    local veh = GetClosestVehicle(p.x, p.y, p.z, radius or 4.0, 0, 71)
    if veh and veh ~= 0 then return veh end
    return nil
end

---------------------------------------------------------------------------
-- Dienst in/uit + bossmenu
---------------------------------------------------------------------------
CreateThread(function()
    for index, duty in ipairs(JobsCfg.Duty) do
        Interact.blip({ coords = duty.coords, sprite = duty.blip.sprite, colour = duty.blip.colour, label = duty.label })
        Interact.point({
            coords = duty.coords,
            distance = JobsCfg.DutyDistance,
            label = T('jobs.duty_prompt', duty.label),
            marker = { type = 1, r = 45, g = 156, b = 255, a = 90 },
            canUse = function()
                local name = RPJ.jobName()
                return name == duty.job or name == (JobsCfg.OffDutyPrefix .. duty.job)
            end,
            onUse = function()
                local res = lib.callback.await('rp_jobs:toggleDuty', false, index)
                RPJ.result(res)
            end,
        })
    end

    for _, boss in ipairs(JobsCfg.Boss) do
        Interact.point({
            coords = boss.coords,
            distance = 2.0,
            label = T('jobs.boss_prompt'),
            marker = { type = 1, r = 241, g = 196, b = 15, a = 80 },
            canUse = function()
                return RPJ.jobName() == boss.job and RPJ.gradeName() == 'boss'
            end,
            onUse = function()
                TriggerEvent('esx_society:openBossMenu', boss.job, function(_, menu) menu.close() end, { wash = false })
            end,
        })
    end
end)

RegisterNetEvent('rp_jobs:notifyTarget', function(key)
    RPJ.notify('inform', key)
end)
