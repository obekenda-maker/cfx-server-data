--[[ rp_jobs/client/delivery.lua – vrachtwagenchauffeur en bezorger ]]

local T = ServerCfg.T

local active = nil          -- { kind, route, blip }
local jobVehicle = nil

local function clearMission()
    if active and active.blip and DoesBlipExist(active.blip) then RemoveBlip(active.blip) end
    ClearGpsMultiRoute()
    active = nil
end

local function spawnVehicle(cfg, cb)
    local model = cfg.depot.vehicle
    ESX.Game.SpawnVehicle(model, vec3(cfg.depot.spawn.x, cfg.depot.spawn.y, cfg.depot.spawn.z), cfg.depot.spawn.w, function(vehicle)
        jobVehicle = vehicle
        SetVehicleNumberPlateText(vehicle, 'WERK' .. math.random(1000, 9999))
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        cb(vehicle)
    end)
end

local function startMission(kind)
    local cfg = JobsCfg.Delivery[kind]
    local res = lib.callback.await('rp_jobs:delivery:start', false, kind)
    if not res or not res.ok then
        RPJ.result(res)
        return
    end
    clearMission()

    local c = res.route.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(res.route.label)
    EndTextCommandSetBlipName(blip)
    active = { kind = kind, route = res.route, blip = blip }
    RPJ.notify('inform', 'jobs.mission_start', res.route.label, res.route.pay)

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetEntityModel(veh) ~= joaat(cfg.depot.vehicle) then
        if jobVehicle and DoesEntityExist(jobVehicle) then
            TaskWarpPedIntoVehicle(ped, jobVehicle, -1)
        else
            spawnVehicle(cfg, function() end)
        end
    end
end

local function returnVehicle(cfg)
    if jobVehicle and DoesEntityExist(jobVehicle) then
        local d = #(GetEntityCoords(jobVehicle) - cfg.depot.coords)
        if d < 40.0 then
            ESX.Game.DeleteVehicle(jobVehicle)
            jobVehicle = nil
            RPJ.notify('success', 'jobs.vehicle_returned')
            return
        end
    end
    RPJ.notify('error', 'jobs.vehicle_far')
end

CreateThread(function()
    for kind, cfg in pairs(JobsCfg.Delivery) do
        Interact.blip({ coords = cfg.depot.coords, sprite = cfg.depot.blip.sprite, colour = cfg.depot.blip.colour, label = cfg.label })
        Interact.point({
            coords = cfg.depot.coords,
            distance = 2.5,
            label = T('jobs.depot_prompt', cfg.label),
            marker = { type = 1, r = 255, g = 106, b = 0, a = 90, scale = 1.6 },
            canUse = function() return RPJ.jobName() == cfg.job end,
            onUse = function()
                lib.registerContext({
                    id = 'rp_depot_' .. kind,
                    title = cfg.label,
                    options = {
                        { title = T('jobs.depot_new'), icon = 'truck', onSelect = function() startMission(kind) end },
                        { title = T('jobs.depot_return'), icon = 'rotate-left', onSelect = function() returnVehicle(cfg) end },
                        { title = T('jobs.depot_cancel'), icon = 'xmark', onSelect = function()
                            lib.callback.await('rp_jobs:delivery:cancel', false)
                            clearMission()
                            RPJ.notify('inform', 'jobs.mission_cancelled')
                        end },
                    },
                })
                lib.showContext('rp_depot_' .. kind)
            end,
        })
    end
end)

-- Aankomst/lossen
CreateThread(function()
    local shown = false
    while true do
        if active then
            local cfg = JobsCfg.Delivery[active.kind]
            local c = active.route.coords
            local d = #(GetEntityCoords(PlayerPedId()) - vec3(c.x, c.y, c.z))
            if d < 60.0 then
                Wait(0)
                DrawMarker(1, c.x, c.y, c.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    cfg.finishDistance * 0.6, cfg.finishDistance * 0.6, 0.6, 46, 204, 113, 110,
                    false, false, 2, false, nil, nil, false)
                if d < cfg.finishDistance then
                    if not shown then lib.showTextUI(T('jobs.unload_prompt')) shown = true end
                    if IsControlJustReleased(0, 38) then
                        lib.hideTextUI()
                        shown = false
                        local ok = lib.progressBar({
                            duration = cfg.unloadSeconds * 1000, label = T('jobs.unload_progress'),
                            canCancel = true, disable = { move = true, car = true, combat = true },
                        })
                        if ok then
                            local res = lib.callback.await('rp_jobs:delivery:finish', false)
                            RPJ.result(res)
                            if res and res.ok then clearMission() end
                        end
                    end
                elseif shown then
                    lib.hideTextUI()
                    shown = false
                end
            else
                if shown then lib.hideTextUI() shown = false end
                Wait(500)
            end
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearMission() end
end)
