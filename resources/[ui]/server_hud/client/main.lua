--[[
    server_hud – client
    Verzamelt gegevens en stuurt ze (alleen bij verandering) naar de NUI.

    Events (lokaal) die andere resources kunnen triggeren:
        server_hud:combat      (state)      combat-status of {active=false}
        server_hud:killfeed    (entry)
        server_hud:zoneBanner  ({title,text,color})
        server_hud:protection  (seconden)
        server_hud:death       (bool)
]]

local cfg = ServerCfg.Hud
local T = ServerCfg.T

local nuiReady = false
local last = {}               -- laatst verstuurde waarden (diff)
local needs = { hunger = nil, thirst = nil }
local boardOpen = false

local function send(data)
    SendNUIMessage(data)
end

---------------------------------------------------------------------------
-- NUI-config
---------------------------------------------------------------------------
local function buildTexts()
    local out = {}
    for key, text in pairs(ServerCfg.Locale) do
        if key:sub(1, 4) == 'hud.' then out[key:sub(5)] = text end
    end
    return out
end

local function sendConfig()
    send({
        action = 'config',
        server = ServerCfg.Server,
        colors = ServerCfg.Colors,
        hud = {
            position = cfg.position, moneyPosition = cfg.moneyPosition, killfeedPosition = cfg.killfeedPosition,
            scale = cfg.scale, killfeedMax = cfg.killfeedMax, killfeedSeconds = cfg.killfeedSeconds,
            showHunger = cfg.showHunger, showThirst = cfg.showThirst, showMoney = cfg.showMoney,
            showBank = cfg.showBank, showJob = cfg.showJob, showVehicle = cfg.showVehicle,
            showAmmo = cfg.showAmmo, showKillfeed = cfg.showKillfeed, speedUnit = cfg.speedUnit,
        },
        texts = buildTexts(),
    })
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendConfig()
    cb({})
end)

---------------------------------------------------------------------------
-- Bronnen: ESX-status, geld, job
---------------------------------------------------------------------------
AddEventHandler('esx_status:onTick', function(data)
    for _, s in ipairs(data or {}) do
        if s.name == 'hunger' then needs.hunger = s.percent
        elseif s.name == 'thirst' then needs.thirst = s.percent end
    end
end)

local function accountMoney(name)
    local data = ESX.GetPlayerData()
    for _, acc in ipairs(data.accounts or {}) do
        if acc.name == name then return acc.money or 0 end
    end
    if name == 'money' then return data.money or 0 end
    return 0
end

local function jobInfo()
    local job = ESX.GetPlayerData().job
    if not job then return T('hud.job_none'), '' end
    return job.label or T('hud.job_none'), job.grade_label or ''
end

---------------------------------------------------------------------------
-- Hoofdlus: stuur alleen als er iets verandert
---------------------------------------------------------------------------
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local UNARMED = joaat('WEAPON_UNARMED')

CreateThread(function()
    while true do
        Wait(cfg.updateMs)
        if cfg.enabled and nuiReady and ESX.IsPlayerLoaded() then
            local ped = PlayerPedId()
            local dead = IsEntityDead(ped)

            local maxHp = math.max(GetEntityMaxHealth(ped) - 100, 1)
            local health = dead and 0 or math.min(100, math.floor(math.max(GetEntityHealth(ped) - 100, 0) / maxHp * 100))

            local jobLabel, gradeLabel = jobInfo()
            local data = {
                action = 'update',
                visible = not IsPauseMenuActive(),
                health = health,
                armor = GetPedArmour(ped),
                hunger = needs.hunger and math.floor(needs.hunger) or nil,
                thirst = needs.thirst and math.floor(needs.thirst) or nil,
                cash = accountMoney('money'),
                bank = accountMoney('bank'),
                job = jobLabel, grade = gradeLabel,
            }

            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                local mult = cfg.speedUnit == 'mph' and 2.236936 or 3.6
                data.vehicle = {
                    speed = math.floor(GetEntitySpeed(veh) * mult),
                    fuel = math.floor(GetVehicleFuelLevel(veh)),
                    gear = GetVehicleCurrentGear(veh),
                    engine = math.max(0, math.floor(GetVehicleEngineHealth(veh) / 10)),
                }
            end

            if IsPedArmed(ped, 4) then
                local _, weapon = GetCurrentPedWeapon(ped, true)
                if weapon and weapon ~= UNARMED then
                    local _, clip = GetAmmoInClip(ped, weapon)
                    local total = GetAmmoInPedWeapon(ped, weapon)
                    data.ammo = { clip = clip or 0, reserve = math.max((total or 0) - (clip or 0), 0) }
                end
            end

            if not same(data, last) then
                last = data
                send(data)
            end
        end
    end
end)

-- Verberg standaard GTA-HUD onderdelen (geen dubbele HUD)
CreateThread(function()
    while true do
        if cfg.hideGameHud then
            Wait(0)
            for _, id in ipairs({ 1, 2, 3, 4, 6, 7, 8, 9 }) do HideHudComponentThisFrame(id) end
        else
            Wait(2000)
        end
    end
end)

---------------------------------------------------------------------------
-- Combat-events
---------------------------------------------------------------------------
AddEventHandler('server_hud:combat', function(state)
    send({ action = 'combat', state = state or { active = false } })
end)

AddEventHandler('server_hud:killfeed', function(entry)
    if cfg.showKillfeed then send({ action = 'killfeed', entry = entry }) end
end)

AddEventHandler('server_hud:zoneBanner', function(banner)
    send({ action = 'banner', banner = banner })
end)

AddEventHandler('server_hud:protection', function(seconds)
    send({ action = 'protection', seconds = seconds or 0 })
end)

AddEventHandler('server_hud:death', function(isDead)
    send({ action = 'death', dead = isDead == true })
end)

---------------------------------------------------------------------------
-- Leaderboard (toets ingedrukt houden of /top)
---------------------------------------------------------------------------
local function showBoard(sort)
    sort = (sort == 'kd' or sort == 'xp') and sort or 'kills'
    local rows = lib.callback.await('combat_stats:getLeaderboard', false, sort, cfg.leaderboardRows) or {}
    local mine = lib.callback.await('combat_stats:getMine', false)
    send({ action = 'leaderboard', show = true, sort = sort, rows = rows, mine = mine })
end

RegisterCommand('+hud_leaderboard', function()
    if boardOpen then return end
    boardOpen = true
    showBoard('kills')
end, false)

RegisterCommand('-hud_leaderboard', function()
    boardOpen = false
    send({ action = 'leaderboard', show = false })
end, false)

RegisterKeyMapping('+hud_leaderboard', T('hud.key_leaderboard'), 'keyboard', cfg.leaderboardKey)

RegisterCommand('top', function(_, args)
    showBoard(args[1])
    SetTimeout(8000, function()
        if not boardOpen then send({ action = 'leaderboard', show = false }) end
    end)
end, false)
TriggerEvent('chat:addSuggestion', '/top', T('hud.cmd_top'), { { name = 'sortering', help = 'kills | kd | xp' } })

---------------------------------------------------------------------------
-- Herstellen na restart
---------------------------------------------------------------------------
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetTimeout(1000, function() if nuiReady then sendConfig() end end)
end)
