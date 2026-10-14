--[[
    rp_jobs/client/medic.lua – dood (buiten combat), hulp melden, ziekenhuis-respawn en revive door medics.
    In combat zones is combat_core verantwoordelijk (LocalPlayer.state.inCombat).
]]

local T = ServerCfg.T
local D = JobsCfg.Death
local handling = false
local revived = false
local shownText = nil

local function showText(text)
    if shownText ~= text then
        shownText = text
        lib.showTextUI(text)
    end
end

local function hideText()
    if shownText then
        shownText = nil
        lib.hideTextUI()
    end
end

local function resolveKiller(ped)
    local source = GetPedSourceOfDeath(ped)
    if not source or source == 0 or source == ped then return nil end
    if IsEntityAVehicle(source) then source = GetPedInVehicleSeat(source, -1) end
    if source and source ~= 0 and IsEntityAPed(source) and IsPedAPlayer(source) then
        local idx = NetworkGetPlayerIndexFromPed(source)
        if idx and idx ~= -1 then return GetPlayerServerId(idx) end
    end
    return nil
end

local function resurrect(x, y, z, h, health)
    local ped = PlayerPedId()
    DoScreenFadeOut(250)
    Wait(300)
    NetworkResurrectLocalPlayer(x, y, z, h or 0.0, true, false)
    ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, health or 200)
    LocalPlayer.state:set('isDown', false, true)
    TriggerEvent('esx:onPlayerSpawn')
    Wait(200)
    DoScreenFadeIn(300)
end

local function runDeath()
    handling = true
    local ped = PlayerPedId()
    TriggerServerEvent('rp_jobs:died', resolveKiller(ped))
    LocalPlayer.state:set('isDown', true, true)

    local startedAt = GetGameTimer()
    revived = false

    while IsEntityDead(PlayerPedId()) and not revived and not LocalPlayer.state.inCombat do
        local elapsed = (GetGameTimer() - startedAt) / 1000
        local untilRespawn = math.max(0, math.ceil(D.respawnAfterSeconds - elapsed))
        local untilAuto = math.max(0, math.ceil(D.autoRespawnSeconds - elapsed))

        if untilRespawn > 0 then
            showText(T('jobs.down_wait', untilRespawn, untilAuto))
        else
            showText(T('jobs.down_ready', D.hospitalFee, untilAuto))
        end

        if IsControlJustReleased(0, 38) then -- E
            RPJ.result(lib.callback.await('rp_jobs:callMedics', false))
        end
        if (IsControlJustReleased(0, 47) and untilRespawn == 0) or untilAuto == 0 then -- G of automatisch
            local res = lib.callback.await('rp_jobs:hospitalRespawn', false)
            if res and res.ok then
                hideText()
                resurrect(res.spawn.x, res.spawn.y, res.spawn.z, res.spawn.h, 200)
                RPJ.notify('inform', 'jobs.hospital_done', res.label, res.fee)
                handling = false
                return
            else
                RPJ.result(res)
                Wait(1500)
            end
        end
        Wait(0)
    end
    hideText()
    handling = false
end

RegisterNetEvent('rp_jobs:revived', function(health)
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then return end
    revived = true
    local pos = GetEntityCoords(ped)
    resurrect(pos.x, pos.y, pos.z, GetEntityHeading(ped), health or D.reviveHealth)
    RPJ.notify('success', 'jobs.you_revived')
end)

CreateThread(function()
    while true do
        if ESX.IsPlayerLoaded() and not handling and not LocalPlayer.state.inCombat and IsEntityDead(PlayerPedId()) then
            CreateThread(runDeath)
            handling = true
            Wait(500)
        else
            Wait(300)
        end
    end
end)

---------------------------------------------------------------------------
-- Medic: hulpmeldingen en reanimeren
---------------------------------------------------------------------------
RegisterNetEvent('rp_jobs:medicCall', function(patientSrc, coords)
    if RPJ.jobName() ~= D.medicJob then return end
    RPJ.notify('warning', 'jobs.medic_call')
    if coords then
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 153)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 1.0)
        SetBlipFlashes(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(T('jobs.medic_blip'))
        EndTextCommandSetBlipName(blip)
        SetTimeout(90000, function() if DoesBlipExist(blip) then RemoveBlip(blip) end end)
    end
end)

local function findDownedPlayer()
    local me = PlayerId()
    local myPos = GetEntityCoords(PlayerPedId())
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            local ped = GetPlayerPed(player)
            local sid = GetPlayerServerId(player)
            if #(GetEntityCoords(ped) - myPos) <= D.reviveDistance and Player(sid).state.isDown and IsEntityDead(ped) then
                return sid
            end
        end
    end
    return nil
end

CreateThread(function()
    local shown = false
    local busy = false
    while true do
        Wait(400)
        local target
        if ESX.IsPlayerLoaded() and RPJ.jobName() == D.medicJob and not busy and not IsEntityDead(PlayerPedId()) then
            target = findDownedPlayer()
        end
        if target and not shown then
            lib.showTextUI(T('jobs.revive_prompt'))
            shown = true
        elseif not target and shown then
            lib.hideTextUI()
            shown = false
        end
        if target then
            -- korte, snelle poll voor de toets
            for _ = 1, 8 do
                Wait(50)
                if IsControlJustReleased(0, 38) then
                    busy = true
                    lib.hideTextUI()
                    shown = false
                    local done = lib.progressBar({
                        duration = D.reviveSeconds * 1000,
                        label = T('jobs.revive_progress'),
                        useWhileDead = false, canCancel = true,
                        disable = { move = true, car = true, combat = true },
                        anim = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest', flag = 1 },
                    })
                    if done then RPJ.result(lib.callback.await('rp_jobs:revive', false, target)) end
                    busy = false
                    break
                end
            end
        end
    end
end)
