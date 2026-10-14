-- luacheck-configuratie voor de eigen resources (Lua 5.4 / CfxLua).
-- read_globals = FiveM-/Cfx-natives en runtime-functies die in de code worden gebruikt.
-- Een NIEUWE onbekende globale naam laat `python3 tests/check_lint.py` falen: controleer dan of het een
-- geldige native is en voeg hem hier toe (typfouten in eigen variabelen worden zo gevangen).
std = "lua54"
max_line_length = false
unused_args = false
allow_defined_top = true
exclude_files = { "**/fxmanifest.lua" }

-- globals die onze resources zelf definiëren (gedeeld tussen bestanden van één resource)
globals = { "ServerCfg", "Combat", "CombatCfg", "CombatUtil", "CombatClient", "StatsCfg", "Jobs", "JobsCfg", "RPJ", "GarageCfg", "ShopCfg", "InterCfg", "Gang", "GangCfg", "Interact", "WelcomeCfg", "WelcomeRules" }

-- FiveM-omgeving
read_globals = {
    "SetNuiFocus", "IsNuiFocused", "IsScreenFadedIn",
    "lib", "ESX", "MySQL", "exports", "json", "source", "Citizen", "Player", "LocalPlayer",
    "AddBlipForCoord", "AddBlipForRadius", "AddEventHandler", "AddTextComponentSubstringPlayerName", "AttachEntityToEntity", "BeginTextCommandDisplayText",
    "BeginTextCommandSetBlipName", "CancelEvent", "ClearGpsMultiRoute", "ClearPedBloodDamage", "ClearPedTasks", "ClearPedTasksImmediately",
    "CreateThread", "DeleteEntity", "DetachEntity", "DisableControlAction", "DisablePlayerFiring", "DoScreenFadeIn",
    "DoScreenFadeOut", "DoesBlipExist", "DoesEntityExist", "DrawMarker", "DropPlayer", "EndTextCommandDisplayText",
    "EndTextCommandSetBlipName", "FreezeEntityPosition", "GetActivePlayers", "GetAllVehicles", "GetAmmoInClip", "GetAmmoInPedWeapon",
    "GetClosestVehicle", "GetConvar", "GetCurrentPedWeapon", "GetCurrentResourceName", "GetDisplayNameFromVehicleModel", "GetEntityCoords",
    "GetEntityHeading", "GetEntityHealth", "GetEntityMaxHealth", "GetEntityModel", "GetEntitySpeed", "GetEntityType",
    "GetGameTimer", "GetGroundZFor_3dCoord", "GetLabelText", "GetPedArmour", "GetPedCauseOfDeath", "GetPedInVehicleSeat",
    "GetPedSourceOfDeath", "GetPlayerFromServerId", "GetPlayerIdentifiers", "GetPlayerName", "GetPlayerPed", "GetPlayerPing",
    "GetPlayerServerId", "GetScreenCoordFromWorldCoord", "GetSelectedPedWeapon", "GetVehicleCurrentGear", "GetVehicleEngineHealth", "GetVehicleFuelLevel",
    "GetVehicleModelNumberOfSeats", "GetVehicleNumberPlateText", "GetVehiclePedIsIn", "GiveWeaponComponentToPed", "GiveWeaponToPed", "HasAnimDictLoaded",
    "HasCollisionLoadedAroundEntity", "HideHudComponentThisFrame", "IsAnyVehicleNearPoint", "IsControlJustReleased", "IsDuplicityVersion", "IsEntityAPed",
    "IsEntityAVehicle", "IsEntityDead", "IsEntityPlayingAnim", "IsPauseMenuActive", "IsPedAPlayer", "IsPedArmed",
    "IsPedInAnyVehicle", "IsPedShooting", "NetworkGetEntityFromNetworkId", "NetworkGetEntityOwner", "NetworkGetNetworkIdFromEntity", "NetworkGetPlayerIndexFromPed",
    "NetworkRequestControlOfEntity", "NetworkResurrectLocalPlayer", "NetworkSetFriendlyFireOption", "PerformHttpRequest", "PlayerId", "PlayerPedId",
    "RegisterCommand", "RegisterKeyMapping", "RegisterNUICallback", "RegisterNetEvent", "RemoveAllPedWeapons", "RemoveBlip",
    "RemoveWeaponFromPed", "RequestAnimDict", "RequestCollisionAtCoord", "ResetEntityAlpha", "SendNUIMessage", "SetBlipAlpha",
    "SetBlipAsShortRange", "SetBlipColour", "SetBlipFlashes", "SetBlipRoute", "SetBlipScale", "SetBlipSecondaryColour",
    "SetBlipSprite", "SetCanAttackFriendly", "SetCurrentPedWeapon", "SetEnableHandcuffs", "SetEntityAlpha", "SetEntityCoords",
    "SetEntityHeading", "SetEntityHealth", "SetEntityInvincible", "SetEntityMaxHealth", "SetNewWaypoint", "SetPedArmour",
    "SetPedDropsWeaponsWhenDead", "SetPedWeaponTintIndex", "SetPlayerTeam", "SetTextCentre", "SetTextColour", "SetTextFont",
    "SetTextOutline", "SetTextProportional", "SetTextScale", "SetTimeout", "SetVehicleBodyHealth", "SetVehicleDeformationFixed",
    "SetVehicleEngineHealth", "SetVehicleFixed", "SetVehicleNumberPlateText", "SetVehicleOnGroundProperly", "SetVehiclePetrolTankHealth", "SetVehicleUndriveable",
    "TaskLeaveVehicle", "TaskPlayAnim", "TaskWarpPedIntoVehicle", "TriggerClientEvent", "TriggerEvent", "TriggerServerEvent",
    "Wait", "joaat", "promise", "vec3", "vec4",
}
