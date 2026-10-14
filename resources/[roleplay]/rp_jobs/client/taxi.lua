--[[ rp_jobs/client/taxi.lua – taximeter (/taxi) ]]

local T = ServerCfg.T
local C = JobsCfg.Taxi

local meter = nil -- { km = 0.0, last = vec3 }

local function fare(km)
    return math.min(C.maxFare, math.floor(C.baseFare + C.perKm * km))
end

local function startMeter()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        RPJ.notify('error', 'jobs.not_in_vehicle')
        return
    end
    meter = { km = 0.0, last = GetEntityCoords(veh) }
    RPJ.notify('success', 'jobs.meter_started')
end

local function stopMeter()
    if not meter then return end
    local km = meter.km
    meter = nil
    lib.hideTextUI()

    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    local passenger
    if veh ~= 0 then
        for seat = 0, GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 2 do
            local ped = GetPedInVehicleSeat(veh, seat)
            if ped ~= 0 and IsPedAPlayer(ped) then
                local idx = NetworkGetPlayerIndexFromPed(ped)
                if idx ~= -1 then passenger = GetPlayerServerId(idx) break end
            end
        end
    end
    if not passenger then
        RPJ.notify('inform', 'jobs.meter_nopassenger')
        return
    end
    RPJ.result(lib.callback.await('rp_jobs:taxi:charge', false, passenger, km))
end

RegisterCommand('taxi', function()
    if RPJ.jobName() ~= C.job then
        RPJ.notify('error', 'jobs.not_taxi')
        return
    end
    lib.registerContext({
        id = 'rp_taxi_menu',
        title = T('jobs.taxi_menu'),
        options = {
            { title = T('jobs.meter_start'), icon = 'play', disabled = meter ~= nil, onSelect = startMeter },
            { title = T('jobs.meter_stop'), icon = 'stop', disabled = meter == nil, onSelect = stopMeter },
        },
    })
    lib.showContext('rp_taxi_menu')
end, false)
TriggerEvent('chat:addSuggestion', '/taxi', T('jobs.cmd_taxi'))

CreateThread(function()
    while true do
        if meter then
            Wait(500)
            local veh = GetVehiclePedIsIn(PlayerPedId(), false)
            if veh ~= 0 then
                local pos = GetEntityCoords(veh)
                meter.km = meter.km + (#(pos - meter.last) / 1000.0)
                meter.last = pos
            end
            lib.showTextUI(T('jobs.meter_text', fare(meter.km), meter.km))
        else
            Wait(1000)
        end
    end
end)

-- De passagier bevestigt het tarief (server → client callback)
lib.callback.register('rp_jobs:taxi:confirm', function(amount, driverName)
    local answer = lib.alertDialog({
        header = T('jobs.fare_header'),
        content = T('jobs.fare_content', driverName, amount),
        centered = true,
        cancel = true,
        labels = { confirm = T('jobs.fare_pay'), cancel = T('jobs.fare_refuse') },
    })
    return answer == 'confirm'
end)
