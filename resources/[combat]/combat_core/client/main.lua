--[[
    combat_core/client/main.lua – deelname, loadouts, snapshots en menu.
    De client voert uit wat de server bepaalt; alle beslissingen over geld/kills/toegang zijn server-side.
]]

CombatClient = {
    zones          = {},    -- [id] = { data = zoneData, zone = lib.zones object, blips = {...} }
    inside         = nil,   -- zone-id waar de speler fysiek in staat
    joined         = false,
    zoneId         = nil,
    team           = nil,
    state          = { active = false },
    needs          = nil,   -- snapshot honger/dorst
    vitals         = nil,   -- snapshot health/armor
    protectedUntil = 0,
    busy           = false,
    deathHandled   = false,
    bystander      = nil,
}
local C = CombatClient
local T = ServerCfg.T

function C.notify(kind, key, ...)
    ServerCfg.Notify(nil, kind, key, ...)
end

---------------------------------------------------------------------------
-- Hulpfuncties
---------------------------------------------------------------------------
--- Grondhoogte bepalen (hint = verwachte z). Geeft altijd een getal terug.
function C.groundZ(x, y, hint)
    RequestCollisionAtCoord(x, y, hint)
    local heights = { hint + 80.0, hint + 40.0, hint + 15.0, hint + 3.0, hint - 10.0 }
    for _ = 1, 6 do
        for _, h in ipairs(heights) do
            local found, z = GetGroundZFor_3dCoord(x, y, h, false)
            if found then return z + 0.5 end
        end
        Wait(60)
        RequestCollisionAtCoord(x, y, hint)
    end
    return hint + 1.0
end

function C.teleport(spawn)
    local ped = PlayerPedId()
    local z = C.groundZ(spawn.x, spawn.y, spawn.z)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, spawn.x, spawn.y, z, false, false, false, false)
    SetEntityHeading(ped, spawn.h or 0.0)
    local timeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(50) end
    FreezeEntityPosition(ped, false)
end

function C.applyLoadout(lo)
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    for _, w in ipairs(lo.weapons) do
        local hash = joaat(w.name)
        GiveWeaponToPed(ped, hash, w.ammo or 0, false, false)
        for _, comp in ipairs(w.components or {}) do
            GiveWeaponComponentToPed(ped, hash, joaat(comp))
        end
    end
    if lo.weapons[1] then SetCurrentPedWeapon(ped, joaat(lo.weapons[1].name), true) end
    SetPedDropsWeaponsWhenDead(ped, false)
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, lo.health or 200)
    SetPedArmour(ped, lo.armor or 0)
    ClearPedBloodDamage(ped)
end

--- Herstel de RP-loadout uit de server-snapshot (bevat naam, ammo, componenten, tint)
function C.restoreRpLoadout(list)
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    if not CombatCfg.Rules.restoreRpLoadout then return end
    -- Zonder server-snapshot (bijv. lokale noodopruiming): val terug op de ESX-loadout
    list = list or ESX.GetPlayerData().loadout
    for _, w in ipairs(list or {}) do
        local hash = joaat(w.name)
        GiveWeaponToPed(ped, hash, w.ammo or 0, false, false)
        for _, comp in ipairs(w.components or {}) do
            GiveWeaponComponentToPed(ped, hash, joaat(comp))
        end
        if w.tintIndex and w.tintIndex > 0 then SetPedWeaponTintIndex(ped, hash, w.tintIndex) end
    end
    SetPedDropsWeaponsWhenDead(ped, true)
end

function C.snapshotVitals()
    local ped = PlayerPedId()
    C.vitals = { health = GetEntityHealth(ped), armor = GetPedArmour(ped) }
    if not CombatCfg.Rules.freezeNeedsInZone then return end
    C.needs = {}
    for _, name in ipairs({ 'hunger', 'thirst' }) do
        TriggerEvent('esx_status:getStatus', name, function(status)
            if status and status.val then C.needs[name] = status.val end
        end)
    end
end

function C.restoreNeeds()
    if not C.needs then return end
    for name, val in pairs(C.needs) do
        TriggerEvent('esx_status:set', name, val)
    end
end

function C.restoreVitals()
    local ped = PlayerPedId()
    if C.vitals then
        SetEntityHealth(ped, math.max(C.vitals.health, 101))
        SetPedArmour(ped, C.vitals.armor)
    end
    C.restoreNeeds()
    C.vitals, C.needs = nil, nil
end

--- Teams en friendly fire. Buiten zones: alle spelers in team 1; FF volgens Outside.mode.
function C.applyRules()
    local ped = PlayerPedId()
    if C.joined then
        if C.state.zone and C.state.zone.mode == 'team' then
            SetPlayerTeam(PlayerId(), 10 + (C.team or 1))
            NetworkSetFriendlyFireOption(false)
            SetCanAttackFriendly(ped, false, false)
        else
            SetPlayerTeam(PlayerId(), 10)
            NetworkSetFriendlyFireOption(true)
            SetCanAttackFriendly(ped, true, false)
        end
    else
        local allowOutside = CombatCfg.Outside.mode ~= 'disabled'
        SetPlayerTeam(PlayerId(), 1)
        NetworkSetFriendlyFireOption(allowOutside)
        SetCanAttackFriendly(ped, allowOutside, false)
    end
end

function C.startProtection(seconds)
    if not seconds or seconds <= 0 then return end
    C.protectedUntil = GetGameTimer() + seconds * 1000
    CreateThread(function()
        local ped = PlayerPedId()
        SetEntityInvincible(ped, true)
        SetEntityAlpha(ped, 150, false)
        TriggerEvent('server_hud:protection', seconds)
        while GetGameTimer() < C.protectedUntil and C.joined do
            Wait(0)
            if CombatCfg.Rules.protectionBreaksOnFire and IsPedShooting(PlayerPedId()) then
                TriggerServerEvent('combat:protectionBroken')
                break
            end
        end
        ped = PlayerPedId()
        SetEntityInvincible(ped, false)
        ResetEntityAlpha(ped)
        C.protectedUntil = 0
        TriggerEvent('server_hud:protection', 0)
    end)
end

---------------------------------------------------------------------------
-- Deelnemen / verlaten
---------------------------------------------------------------------------
function C.onJoined(data)
    C.joined = true
    C.zoneId = data.zone.id
    C.team = data.team
    C.state = data.state or { active = true, zone = data.zone }
    C.deathHandled = false
    C.bystander = nil

    DoScreenFadeOut(250)
    Wait(300)
    -- Een fout hieronder mag NOOIT een zwart scherm of half-toegepaste staat achterlaten.
    local ok, err = pcall(function()
        C.snapshotVitals()
        C.teleport(data.spawn)
        C.applyLoadout(data.loadout)
        C.applyRules()
    end)
    DoScreenFadeIn(300)
    if not ok then
        print('^1[combat_core]^7 Fout bij deelnemen: ' .. tostring(err))
        C.requestLeave()
        return
    end
    C.startProtection(data.protection)

    TriggerEvent('server_hud:combat', C.state)
    C.notify('success', 'combat.joined', data.zone.label)
end

function C.join(zoneId)
    if C.busy or C.joined then return end
    local entry = C.zones[zoneId]
    if not entry then return end
    local zone = entry.data

    C.busy = true
    local loadoutKey
    if #zone.loadouts > 1 then
        local options = {}
        for _, lo in ipairs(zone.loadouts) do options[#options + 1] = { value = lo.key, label = lo.label } end
        local input = lib.inputDialog(T('combat.choose_loadout'), {
            { type = 'select', label = T('combat.loadout'), options = options, default = options[1].value, required = true },
        })
        if not input then
            C.busy = false
            return
        end
        loadoutKey = input[1]
    end

    local res = lib.callback.await('combat:join', false, zoneId, loadoutKey)
    C.busy = false
    if not res or not res.ok then
        C.notify('error', (res and res.reason) or 'combat.too_fast', res and res.param)
        return
    end
    C.onJoined(res.data)
end

function C.requestLeave()
    if not C.joined then
        C.notify('error', 'combat.not_joined')
        return
    end
    local res = lib.callback.await('combat:leave', false)
    if not res or not res.ok then
        C.notify('error', (res and res.reason) or 'combat.too_fast', res and res.param)
    end
    -- succes: de server stuurt combat:left
end

RegisterNetEvent('combat:left', function(reasonKey, rpLoadout)
    if not C.joined then return end
    C.joined = false
    C.zoneId, C.team = nil, nil
    C.state = { active = false }
    C.deathHandled = false
    lib.hideTextUI()

    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        local pos = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(ped), true, false)
        ClearPedTasksImmediately(PlayerPedId())
        TriggerEvent('esx:onPlayerSpawn')
    end
    SetEntityInvincible(PlayerPedId(), false)
    ResetEntityAlpha(PlayerPedId())
    C.protectedUntil = 0

    C.restoreRpLoadout(rpLoadout)
    C.restoreVitals()
    C.applyRules()

    TriggerEvent('server_hud:combat', { active = false })
    TriggerEvent('server_hud:protection', 0)
    C.notify('inform', reasonKey or 'combat.left')
end)

--- Noodopruiming zonder serverbericht (hergebruikt de normale combat:left-afhandeling)
function C.localCleanup()
    TriggerEvent('combat:left', 'combat.left_forced', nil)
end

RegisterNetEvent('combat:state', function(payload)
    C.state = payload or { active = false }
    if payload and payload.active then
        C.team = payload.team
    end
    TriggerEvent('server_hud:combat', C.state)
end)

RegisterNetEvent('combat:killfeed', function(payload)
    TriggerEvent('server_hud:killfeed', payload)
end)

---------------------------------------------------------------------------
-- Menu en commando's
---------------------------------------------------------------------------
function C.openMenu()
    local counts = lib.callback.await('combat:getCounts', false) or {}
    local options = {}

    if C.joined then
        local s = C.state or {}
        options[#options + 1] = {
            title = T('combat.menu_current', (s.zone and s.zone.label) or '-'),
            description = T('combat.menu_stats', s.kills or 0, s.deaths or 0, s.streak or 0),
            icon = 'crosshairs',
            readOnly = true,
        }
        options[#options + 1] = {
            title = T('combat.menu_leave'),
            description = T('combat.menu_leave_desc', CombatCfg.Rules.combatTagSeconds),
            icon = 'door-open',
            onSelect = function() C.requestLeave() end,
        }
    else
        for id, entry in pairs(C.zones) do
            local z = entry.data
            local here = (C.inside == id)
            options[#options + 1] = {
                title = z.label,
                description = T('combat.menu_zone_desc',
                    z.mode == 'team' and T('combat.mode_team') or T('combat.mode_ffa'),
                    counts[id] or 0, z.maxPlayers, z.entryFee),
                icon = z.mode == 'team' and 'users' or 'skull',
                metadata = { { label = T('combat.menu_status'), value = here and T('combat.menu_here') or T('combat.menu_away') } },
                onSelect = function()
                    if here then
                        C.confirmAndJoin(id)
                    else
                        SetNewWaypoint(z.coords.x, z.coords.y)
                        C.notify('inform', 'combat.waypoint_set', z.label)
                    end
                end,
            }
        end
        if #options == 0 then
            options[1] = { title = T('combat.menu_none'), icon = 'ban', readOnly = true }
        end
    end

    lib.registerContext({ id = 'combat_menu', title = T('combat.menu_title'), options = options })
    lib.showContext('combat_menu')
end

function C.confirmAndJoin(zoneId)
    local entry = C.zones[zoneId]
    if not entry then return end
    local z = entry.data
    local answer = lib.alertDialog({
        header = T('combat.prompt_header', z.label),
        content = T('combat.prompt_content',
            z.mode == 'team' and T('combat.mode_team') or T('combat.mode_ffa'), z.entryFee),
        centered = true,
        cancel = true,
        labels = { confirm = T('combat.prompt_yes'), cancel = T('combat.prompt_no') },
    })
    if answer == 'confirm' then C.join(zoneId) end
end

RegisterCommand('pvp', function() C.openMenu() end, false)
RegisterCommand('pvpverlaat', function() C.requestLeave() end, false)
TriggerEvent('chat:addSuggestion', '/pvp', T('combat.cmd_pvp'))
TriggerEvent('chat:addSuggestion', '/pvpverlaat', T('combat.cmd_leave'))

---------------------------------------------------------------------------
-- Regels toepassen (ped kan wisselen na respawn) + voertuigblokkade
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        if ESX.IsPlayerLoaded() then C.applyRules() end
        Wait(2000)
    end
end)

CreateThread(function()
    while true do
        if C.joined and CombatCfg.Rules.blockVehicles then
            Wait(0)
            DisableControlAction(0, 23, true)   -- INPUT_ENTER
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    ResetEntityAlpha(ped)
    lib.hideTextUI()
    if C.joined then
        FreezeEntityPosition(ped, false)
    end
end)
