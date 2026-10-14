--[[
    server_welcome/client/main.lua – regels-akkoord, onboarding en /help via NUI.
    De SERVER dwingt het akkoord af (timeout-kick); dit is alleen de weergave.
    Noodoplossing als de NUI niet reageert: typ /akkoord in de chat.
]]

local T = ServerCfg.T
local isOpen, openMode, mandatory = false, nil, false
local frozen = false

local function buildTexts()
    local out = {}
    for key, text in pairs(ServerCfg.Locale) do
        if key:sub(1, 8) == 'welcome.' and key:sub(1, 13) ~= 'welcome.help_' and key:sub(1, 13) ~= 'welcome.step_' then
            out[key:sub(9)] = text
        end
    end
    return out
end

local function buildSteps()
    local steps = {}
    for i, s in ipairs(WelcomeCfg.Steps) do
        local wp = s.waypoint and WelcomeCfg.Waypoints[s.waypoint]
        steps[i] = {
            title = T('welcome.step_' .. s.key .. '_title'),
            text = T('welcome.step_' .. s.key .. '_text', ServerCfg.Server.name),
            waypoint = wp and { key = s.waypoint, label = wp.label } or nil,
        }
    end
    return steps
end

local function buildHelp()
    local help = {}
    for _, g in ipairs(WelcomeCfg.Help) do
        local items = {}
        for _, it in ipairs(g.items) do items[#items + 1] = { it[1], T(it[2]) } end
        help[#help + 1] = { group = T(g.group), items = items }
    end
    return help
end

local function setFrozen(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state)
    SetEntityInvincible(ped, state)
    frozen = state
end

local function open(mode, mustAccept, timeout)
    if isOpen then return end
    isOpen, openMode, mandatory = true, mode, mustAccept == true
    SetNuiFocus(true, true)
    if mandatory then setFrozen(true) end
    SendNUIMessage({
        action = 'open', mode = mode, mandatory = mandatory, timeout = timeout,
        server = ServerCfg.Server, colors = ServerCfg.Colors, texts = buildTexts(),
        rules = WelcomeRules, steps = buildSteps(), help = buildHelp(), version = WelcomeCfg.Rules.version,
    })
end

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if frozen then setFrozen(false) end
end

local function afterAccept()
    close()
    local s = lib.callback.await('welcome:status', false)
    if WelcomeCfg.Onboarding.enabled and s and not s.onboarded then
        Wait(300)
        open('onboarding', false)
    end
end

---------------------------------------------------------------------------
-- NUI-callbacks
---------------------------------------------------------------------------
RegisterNUICallback('accept', function(_, cb)
    cb({})
    if lib.callback.await('welcome:accept', false) then
        ServerCfg.Notify(nil, 'success', 'welcome.accepted')
        afterAccept()
    end
end)

RegisterNUICallback('decline', function(_, cb)
    cb({})
    TriggerServerEvent('welcome:decline')
    if not WelcomeCfg.Rules.kickOnDecline then close() end
end)

RegisterNUICallback('close', function(_, cb)
    cb({})
    if not mandatory then close() end
end)

RegisterNUICallback('finish', function(_, cb)
    cb({})
    lib.callback.await('welcome:onboarded', false)
    close()
end)

RegisterNUICallback('waypoint', function(data, cb)
    cb({})
    local wp = data and WelcomeCfg.Waypoints[data.key]
    if wp then
        SetNewWaypoint(wp.coords.x, wp.coords.y)
        ServerCfg.Notify(nil, 'inform', 'welcome.waypoint_set', wp.label)
    end
end)

-- /akkoord (chat) is geslaagd terwijl de NUI nog openstond
RegisterNetEvent('welcome:accepted', function()
    if isOpen and openMode == 'rules' and mandatory then afterAccept() end
end)

---------------------------------------------------------------------------
-- Eerste keer: akkoord/onboarding
---------------------------------------------------------------------------
local function checkOnJoin()
    -- Wacht tot er geen andere NUI (bijv. esx_identity-personagescherm) focus heeft en het scherm zichtbaar is
    local waited = 0
    while (IsNuiFocused() or not IsScreenFadedIn()) and waited < 120 do
        Wait(1000)
        waited = waited + 1
    end
    local s = lib.callback.await('welcome:status', false)
    if not s then return end
    if not s.accepted then
        open('rules', WelcomeCfg.Rules.requireAcceptance, s.timeout)
    elseif WelcomeCfg.Onboarding.enabled and not s.onboarded then
        open('onboarding', false)
    end
end

AddEventHandler('esx:playerLoaded', function()
    CreateThread(function()
        Wait(2500)   -- laat esx_identity/spawn eerst klaar zijn
        checkOnJoin()
    end)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() and ESX.IsPlayerLoaded() then CreateThread(checkOnJoin) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if frozen then setFrozen(false) end
end)

---------------------------------------------------------------------------
-- Commando's
---------------------------------------------------------------------------
RegisterCommand('regels', function() open('rules', false) end, false)
RegisterCommand('welkom', function() open('onboarding', false) end, false)
RegisterCommand('help', function() open('help', false) end, false)
TriggerEvent('chat:addSuggestion', '/regels', T('welcome.help_rules'))
TriggerEvent('chat:addSuggestion', '/welkom', T('welcome.help_welcome'))
TriggerEvent('chat:addSuggestion', '/help', T('welcome.help_help'))
TriggerEvent('chat:addSuggestion', '/' .. WelcomeCfg.Rules.chatFallbackCommand, T('welcome.cmd_accept'))
