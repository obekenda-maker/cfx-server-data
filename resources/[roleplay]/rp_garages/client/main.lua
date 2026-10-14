--[[ rp_garages/client/main.lua ]]

local T = ServerCfg.T
local function notify(kind, key, ...) ServerCfg.Notify(nil, kind, key, ...) end

local function result(res)
    if res and res.msg then notify(res.ok and 'success' or 'error', res.msg, res.param) end
end

local function vehicleLabel(model)
    local name = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(name)
    if label == 'NULL' then return name end
    return label
end

local function spawnVehicle(props, spawn, onFail)
    local pos = vec3(spawn.x, spawn.y, spawn.z)
    if IsAnyVehicleNearPoint(pos.x, pos.y, pos.z, 2.5) then
        notify('error', 'garage.spawn_blocked')
        if onFail then onFail() end
        return
    end
    local model = props.model
    ESX.Game.SpawnVehicle(model, pos, spawn.w, function(vehicle)
        if not vehicle or vehicle == 0 then
            if onFail then onFail() end
            return
        end
        ESX.Game.SetVehicleProperties(vehicle, props)
        if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
        SetVehicleOnGroundProperly(vehicle)
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    end)
end

---------------------------------------------------------------------------
-- Garage
---------------------------------------------------------------------------
local function openGarage(garage)
    local options = {}
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        options[#options + 1] = {
            title = T('garage.menu_store'), icon = 'warehouse',
            onSelect = function()
                local props = ESX.Game.GetVehicleProperties(veh)
                TaskLeaveVehicle(ped, veh, 0)
                Wait(1200)
                result(lib.callback.await('rp_garages:store', false, garage.id, NetworkGetNetworkIdFromEntity(veh), props))
            end,
        }
    end

    local list = lib.callback.await('rp_garages:list', false, garage.id) or {}
    for _, v in ipairs(list) do
        options[#options + 1] = {
            title = vehicleLabel(v.model), description = T('garage.plate', v.plate), icon = 'car',
            onSelect = function()
                local res = lib.callback.await('rp_garages:retrieve', false, garage.id, v.plate)
                if res and res.ok then
                    spawnVehicle(res.props, garage.spawn, function()
                        lib.callback.await('rp_garages:restore', false, v.plate)
                    end)
                else
                    result(res)
                end
            end,
        }
    end
    if #list == 0 then
        options[#options + 1] = { title = T('garage.menu_empty'), icon = 'ban', readOnly = true }
    end

    lib.registerContext({ id = 'rp_garage_' .. garage.id, title = garage.label, options = options })
    lib.showContext('rp_garage_' .. garage.id)
end

---------------------------------------------------------------------------
-- Impound
---------------------------------------------------------------------------
local function openImpound()
    local imp = GarageCfg.Impound
    local list = lib.callback.await('rp_garages:impoundList', false) or {}
    local options = {}
    for _, v in ipairs(list) do
        options[#options + 1] = {
            title = vehicleLabel(v.model), description = T('garage.impound_fee', v.plate, imp.fee), icon = 'truck-ramp-box',
            onSelect = function()
                local res = lib.callback.await('rp_garages:impoundRetrieve', false, v.plate)
                if res and res.ok then
                    notify('inform', 'garage.impound_paid', res.fee)
                    spawnVehicle(res.props, imp.spawn, function()
                        lib.callback.await('rp_garages:restore', false, v.plate)
                    end)
                else
                    result(res)
                end
            end,
        }
    end
    if #options == 0 then options[1] = { title = T('garage.impound_empty'), icon = 'ban', readOnly = true } end
    lib.registerContext({ id = 'rp_impound', title = imp.label, options = options })
    lib.showContext('rp_impound')
end

---------------------------------------------------------------------------
-- Winkel
---------------------------------------------------------------------------
local function openShop()
    local options = {}
    for _, cat in ipairs(GarageCfg.Shop.categories) do
        options[#options + 1] = {
            title = cat.label, icon = 'car-side', arrow = true,
            onSelect = function()
                local sub = {}
                for _, v in ipairs(cat.vehicles) do
                    sub[#sub + 1] = {
                        title = v.label, description = T('garage.price', v.price), icon = 'cart-shopping',
                        onSelect = function()
                            local answer = lib.alertDialog({
                                header = T('garage.buy_header'), content = T('garage.buy_content', v.label, v.price),
                                centered = true, cancel = true,
                            })
                            if answer == 'confirm' then
                                local res = lib.callback.await('rp_garages:buy', false, v.model)
                                if res and res.ok then
                                    notify('success', 'garage.bought', res.param)
                                    notify('inform', 'garage.bought_where', res.plate)
                                else
                                    result(res)
                                end
                            end
                        end,
                    }
                end
                lib.registerContext({ id = 'rp_shop_' .. cat.label, title = cat.label, menu = 'rp_shop_main', options = sub })
                lib.showContext('rp_shop_' .. cat.label)
            end,
        }
    end
    lib.registerContext({ id = 'rp_shop_main', title = GarageCfg.Shop.label, options = options })
    lib.showContext('rp_shop_main')
end

CreateThread(function()
    for _, garage in ipairs(GarageCfg.Garages) do
        Interact.blip({ coords = garage.coords, sprite = garage.blip.sprite, colour = garage.blip.colour, label = garage.label })
        Interact.point({
            coords = garage.coords, distance = 3.0, label = T('garage.prompt', garage.label),
            marker = { type = 36, r = 45, g = 156, b = 255, a = 120 },
            onUse = function() openGarage(garage) end,
        })
    end

    local imp = GarageCfg.Impound
    Interact.blip({ coords = imp.coords, sprite = imp.blip.sprite, colour = imp.blip.colour, label = imp.label })
    Interact.point({
        coords = imp.coords, distance = 3.0, label = T('garage.prompt', imp.label),
        marker = { type = 1, r = 231, g = 76, b = 60, a = 100 }, onUse = openImpound,
    })

    local shop = GarageCfg.Shop
    Interact.blip({ coords = shop.coords, sprite = shop.blip.sprite, colour = shop.blip.colour, label = shop.label })
    Interact.point({
        coords = shop.coords, distance = shop.distance, label = T('garage.prompt', shop.label),
        marker = { type = 1, r = 46, g = 204, b = 113, a = 100 }, onUse = openShop,
    })
end)
