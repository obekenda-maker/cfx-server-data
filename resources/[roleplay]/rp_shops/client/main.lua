--[[ rp_shops/client/main.lua ]]

local T = ServerCfg.T
local function notify(kind, key, ...) ServerCfg.Notify(nil, kind, key, ...) end
local function result(res)
    if res and res.msg then notify(res.ok and 'success' or 'error', res.msg, res.param) end
end

local function itemLabel(name)
    local item = ESX.GetPlayerData().inventory
    for _, i in ipairs(item or {}) do
        if i.name == name then return i.label end
    end
    return name
end

local function askPurchase(withCount)
    local rows = {}
    if withCount then
        rows[#rows + 1] = { type = 'number', label = T('shop.count'), default = 1, min = 1, max = ShopCfg.MaxPerPurchase, required = true }
    end
    rows[#rows + 1] = {
        type = 'select', label = T('shop.pay_with'), default = 'money', required = true,
        options = { { value = 'money', label = T('shop.pay_cash') }, { value = 'bank', label = T('shop.pay_bank') } },
    }
    return lib.inputDialog(T('shop.checkout'), rows)
end

local function openCatalog(shop)
    local options = {}
    for _, entry in ipairs(ShopCfg.Catalogs[shop.catalog] or {}) do
        options[#options + 1] = {
            title = itemLabel(entry.item), description = T('shop.price', entry.price), icon = 'basket-shopping',
            onSelect = function()
                local input = askPurchase(true)
                if input then
                    result(lib.callback.await('rp_shops:buy', false, shop.id, entry.item, input[1], input[2]))
                end
            end,
        }
    end
    lib.registerContext({ id = 'rp_shop_' .. shop.id, title = shop.label, options = options })
    lib.showContext('rp_shop_' .. shop.id)
end

local function openWeapons(shop)
    local info = lib.callback.await('rp_shops:weaponInfo', false) or {}
    local W = ShopCfg.WeaponShop
    local options = {}
    if not info.hasLicense then
        options[#options + 1] = {
            title = T('shop.license_buy'), description = T('shop.price', W.licensePrice), icon = 'id-card',
            onSelect = function()
                local input = askPurchase(false)
                if input then result(lib.callback.await('rp_shops:buyLicense', false, shop.id, input[1])) end
            end,
        }
    end
    for _, w in ipairs(W.weapons) do
        options[#options + 1] = {
            title = w.label, description = T('shop.price', w.price), icon = 'gun', disabled = not info.hasLicense,
            onSelect = function()
                local input = askPurchase(false)
                if input then result(lib.callback.await('rp_shops:buyWeapon', false, shop.id, w.weapon, input[1])) end
            end,
        }
    end
    lib.registerContext({ id = 'rp_weapons_' .. shop.id, title = shop.label, options = options })
    lib.showContext('rp_weapons_' .. shop.id)
end

CreateThread(function()
    for _, shop in ipairs(ShopCfg.Shops) do
        Interact.blip({ coords = shop.coords, sprite = shop.blip.sprite, colour = shop.blip.colour, label = shop.label, scale = 0.7 })
        Interact.point({
            coords = shop.coords, distance = 2.0, label = T('shop.prompt', shop.label),
            marker = { type = 1, r = 46, g = 204, b = 113, a = 90 },
            onUse = function()
                if shop.type == 'weapons' then openWeapons(shop) else openCatalog(shop) end
            end,
        })
    end
end)

-- Genezing door verbandmiddelen
RegisterNetEvent('rp_shops:heal', function(percent)
    local ped = PlayerPedId()
    local max = GetEntityMaxHealth(ped)
    local add = math.floor((max - 100) * (percent / 100))
    SetEntityHealth(ped, math.min(max, GetEntityHealth(ped) + add))
end)
