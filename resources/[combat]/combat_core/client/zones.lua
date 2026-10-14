--[[
    combat_core/client/zones.lua – zones, blips, grensmarkering, binnenkomst-prompt en
    gedrag van niet-deelnemers ("bystanders").
]]

local C = CombatClient
local T = ServerCfg.T

---------------------------------------------------------------------------
-- Blips
---------------------------------------------------------------------------
local function colourFromZone(z)
    return (z.blip and z.blip.colour) or 1
end

local function createBlips(z)
    local blips = {}
    local radius = AddBlipForRadius(z.coords.x, z.coords.y, z.coords.z, z.radius)
    SetBlipColour(radius, colourFromZone(z))
    SetBlipAlpha(radius, 90)
    blips[#blips + 1] = radius

    local center = AddBlipForCoord(z.coords.x, z.coords.y, z.coords.z)
    SetBlipSprite(center, (z.blip and z.blip.sprite) or 84)
    SetBlipScale(center, (z.blip and z.blip.scale) or 0.9)
    SetBlipColour(center, colourFromZone(z))
    SetBlipAsShortRange(center, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(T('combat.blip_name', z.label))
    EndTextCommandSetBlipName(center)
    blips[#blips + 1] = center
    return blips
end

---------------------------------------------------------------------------
-- Zones toevoegen / verwijderen
---------------------------------------------------------------------------
local function removeZone(id)
    local entry = C.zones[id]
    if not entry then return end
    if entry.zone then entry.zone:remove() end
    for _, b in ipairs(entry.blips or {}) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    C.zones[id] = nil
    if C.inside == id then C.inside = nil end
    if C.bystander == id then C.bystander = nil end
end

local function addZone(z)
    if C.zones[z.id] then removeZone(z.id) end
    local entry = { data = z }
    entry.blips = createBlips(z)
    entry.zone = lib.zones.sphere({
        coords = vec3(z.coords.x, z.coords.y, z.coords.z),
        radius = z.radius,
        debug = CombatCfg.Debug,
        onEnter = function() C.onZoneEnter(z.id) end,
        onExit = function() C.onZoneExit(z.id) end,
    })
    C.zones[z.id] = entry
end

local function loadZones()
    for id in pairs(C.zones) do removeZone(id) end
    local list = lib.callback.await('combat:getZones', false) or {}
    for _, z in ipairs(list) do addZone(z) end
end

RegisterNetEvent('combat:zoneAdd', function(z) addZone(z) end)
RegisterNetEvent('combat:zoneRemove', function(id) removeZone(id) end)

AddEventHandler('esx:playerLoaded', function()
    loadZones()
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() and ESX.IsPlayerLoaded() then
        loadZones()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(C.zones) do removeZone(id) end
end)

---------------------------------------------------------------------------
-- Betreden / verlaten
---------------------------------------------------------------------------
local function banner(title, text, color)
    TriggerEvent('server_hud:zoneBanner', { title = title, text = text, color = color })
end

function C.onZoneEnter(id)
    local entry = C.zones[id]
    if not entry then return end
    local z = entry.data
    C.inside = id
    banner(T('combat.banner_enter', z.label), T('combat.banner_enter_sub'), ServerCfg.Colors.danger)
    C.notify('warning', 'combat.zone_enter', z.label)
    if not C.joined then C.startBystander(id) end
end

function C.onZoneExit(id)
    local entry = C.zones[id]
    if C.inside == id then C.inside = nil end
    if C.bystander == id then C.bystander = nil end
    if entry then
        banner(T('combat.banner_leave', entry.data.label), T('combat.banner_leave_sub'), ServerCfg.Colors.success)
        C.notify('inform', 'combat.zone_leave', entry.data.label)
    end
end

---------------------------------------------------------------------------
-- Niet-deelnemers: eerst vragen, anders beschermd en na enige tijd naar buiten
---------------------------------------------------------------------------
local function eject(z)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local target
    if z.exit then
        target = { x = z.exit.x, y = z.exit.y, z = z.exit.z, h = z.exit.h }
    else
        local dx, dy = pos.x - z.coords.x, pos.y - z.coords.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1.0 then dx, dy, len = 1.0, 0.0, 1.0 end
        target = {
            x = z.coords.x + dx / len * (z.radius + 12.0),
            y = z.coords.y + dy / len * (z.radius + 12.0),
            z = z.coords.z,
            h = GetEntityHeading(ped),
        }
    end
    DoScreenFadeOut(200)
    Wait(250)
    C.teleport(target)
    DoScreenFadeIn(250)
    C.notify('inform', 'combat.ejected', z.label)
end

function C.startBystander(id)
    C.bystander = id
    CreateThread(function()
        local entry = C.zones[id]
        if not entry then return end
        local z = entry.data

        Wait(1200) -- laat de speler even landen/stoppen
        if C.bystander ~= id or C.joined then return end

        local inVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
        if inVehicle then
            C.notify('inform', 'combat.vehicle_hint')
        elseif not C.busy then
            C.busy = true
            local answer = lib.alertDialog({
                header = T('combat.prompt_header', z.label),
                content = T('combat.prompt_content',
                    z.mode == 'team' and T('combat.mode_team') or T('combat.mode_ffa'), z.entryFee),
                centered = true,
                cancel = true,
                labels = { confirm = T('combat.prompt_yes'), cancel = T('combat.prompt_no') },
            })
            C.busy = false
            if answer == 'confirm' and C.bystander == id and not C.joined then
                C.join(id)
                return
            end
        end

        if C.bystander ~= id or C.joined then return end
        C.notify('inform', 'combat.bystander_hint', CombatCfg.Rules.bystanderEjectSeconds)

        local deadline = GetGameTimer() + CombatCfg.Rules.bystanderEjectSeconds * 1000
        local protect = CombatCfg.Rules.protectBystanders
        while C.bystander == id and not C.joined do
            Wait(0)
            local ped = PlayerPedId()
            if protect then
                SetEntityInvincible(ped, true)
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 257, true)
            end
            if IsPedInAnyVehicle(ped, false) then
                deadline = GetGameTimer() + CombatCfg.Rules.bystanderEjectSeconds * 1000
            elseif GetGameTimer() > deadline then
                eject(z)
                break
            end
        end
        if not C.joined and C.protectedUntil == 0 then
            SetEntityInvincible(PlayerPedId(), false)
        end
    end)
end

---------------------------------------------------------------------------
-- Zonegrens tekenen (alleen in de buurt)
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local near = {}
        if next(C.zones) ~= nil then
            local pos = GetEntityCoords(PlayerPedId())
            for _, entry in pairs(C.zones) do
                local z = entry.data
                local d = #(pos - vec3(z.coords.x, z.coords.y, z.coords.z))
                if d < z.radius + 120.0 then near[#near + 1] = z end
            end
        end
        if #near > 0 then
            for _ = 1, 25 do -- ~500 ms tekenen
                for _, z in ipairs(near) do
                    local colour = ServerCfg.Colors.danger
                    local r = tonumber(colour:sub(2, 3), 16) or 231
                    local g = tonumber(colour:sub(4, 5), 16) or 76
                    local b = tonumber(colour:sub(6, 7), 16) or 60
                    -- platte schijf op de grond (type 1 = cilinder, dun)
                    DrawMarker(1, z.coords.x, z.coords.y, z.coords.z - 30.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        z.radius * 2.0, z.radius * 2.0, 60.0, r, g, b, 18, false, false, 2, false, nil, nil, false)
                end
                Wait(0)
            end
        else
            Wait(750)
        end
    end
end)
