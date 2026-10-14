--[[
    combat_core/client/death.lua – dood in een zone, respawn, loadout opnieuw geven.
    De client MELDT alleen (killer-id, wapen); de server beslist over kill, score en respawn-tijd.
]]

local C = CombatClient
local T = ServerCfg.T

local function resolveKiller(ped)
    local source = GetPedSourceOfDeath(ped)
    if not source or source == 0 or source == ped then return nil end
    if IsEntityAVehicle(source) then
        source = GetPedInVehicleSeat(source, -1)
    end
    if source and source ~= 0 and IsEntityAPed(source) and IsPedAPlayer(source) then
        local index = NetworkGetPlayerIndexFromPed(source)
        if index and index ~= -1 then
            return GetPlayerServerId(index)
        end
    end
    return nil
end

local function respawnAt(data)
    local spawn = data.spawn
    DoScreenFadeOut(250)
    Wait(300)
    local ok, err = pcall(function()
        local z = C.groundZ(spawn.x, spawn.y, spawn.z)
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, z, spawn.h or 0.0, true, false)
        local ped = PlayerPedId()
        ClearPedTasksImmediately(ped)
        ClearPedBloodDamage(ped)
        C.applyLoadout(data.loadout)
        C.applyRules()
        TriggerEvent('esx:onPlayerSpawn')            -- zodat andere ESX-resources weten dat de speler leeft
        SetTimeout(600, function() C.restoreNeeds() end) -- honger/dorst blijven op RP-niveau
    end)
    Wait(200)
    DoScreenFadeIn(300)
    if not ok then print('^1[combat_core]^7 Fout bij respawn: ' .. tostring(err)) end
    C.state = data.state or C.state
    TriggerEvent('server_hud:combat', C.state)
    C.startProtection(data.protection)
end

local function runDeath(ped)
    local killer = resolveKiller(ped)
    local weapon = GetPedCauseOfDeath(ped)
    TriggerServerEvent('combat:died', killer, weapon)
    TriggerEvent('server_hud:death', true)

    local startedAt = GetGameTimer()
    local minWait = CombatCfg.Rules.respawnSeconds * 1000
    while C.joined and IsEntityDead(PlayerPedId()) do
        -- Noodrem: wie na 90 s nog dood is (desync met de server) wordt uit de PvP gehaald
        if GetGameTimer() - startedAt > 90000 then
            lib.hideTextUI()
            local res = lib.callback.await('combat:leave', false)
            if not res or not res.ok then C.localCleanup() end
            break
        end
        local remaining = math.ceil((minWait - (GetGameTimer() - startedAt)) / 1000)
        if remaining > 0 then
            lib.showTextUI(T('combat.death_timer', remaining))
            Wait(250)
        else
            lib.showTextUI(T('combat.death_respawning'))
            local res = lib.callback.await('combat:respawn', false)
            if res and res.ok then
                lib.hideTextUI()
                TriggerEvent('server_hud:death', false)
                respawnAt(res.data)
                C.deathHandled = false
                return
            elseif res and res.reason == 'combat.respawn_wait' then
                Wait(((res.param or 1) * 1000) + 100)
            elseif res and res.reason == 'combat.respawn_limit' then
                C.notify('warning', 'combat.respawn_limit')
                Wait(5000)
            elseif res and res.reason == 'combat.not_joined' then
                -- de server kent ons niet meer als deelnemer: lokaal opruimen zodat we niet blijven hangen
                C.localCleanup()
                break
            else
                Wait(1000)
            end
        end
    end
    lib.hideTextUI()
    TriggerEvent('server_hud:death', false)
    C.deathHandled = false
end

CreateThread(function()
    while true do
        if C.joined and not C.deathHandled then
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                C.deathHandled = true
                CreateThread(function() runDeath(ped) end)
            end
            Wait(100)
        else
            Wait(400)
        end
    end
end)
