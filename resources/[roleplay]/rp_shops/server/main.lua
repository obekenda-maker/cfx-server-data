--[[ rp_shops/server/main.lua – kopen (server-gevalideerd) en bruikbare items ]]

local shopById = {}
for _, s in ipairs(ShopCfg.Shops) do shopById[s.id] = s end

local last = {}
local function throttle(src, key, ms)
    local id = src .. ':' .. key
    local now = GetGameTimer()
    if (last[id] or -1e9) + ms > now then return false end
    last[id] = now
    return true
end

local function nearShop(src, shop)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local dx, dy, dz = c.x - shop.coords.x, c.y - shop.coords.y, c.z - shop.coords.z
    return math.sqrt(dx * dx + dy * dy + dz * dz) <= ShopCfg.ShopDistance
end

local function inCombat(src)
    local ok, res = pcall(function() return exports.combat_core:IsInCombat(src) end)
    return ok and res == true
end

local function pay(xPlayer, account, amount, reason)
    if not ShopCfg.AllowedAccounts[account] then return false end
    if account == 'money' then
        if xPlayer.getMoney() < amount then return false end
        xPlayer.removeMoney(amount, reason)
    else
        if xPlayer.getAccount(account).money < amount then return false end
        xPlayer.removeAccountMoney(account, amount, reason)
    end
    return true
end

local function hasLicense(src, licenseType)
    local p = promise.new()
    TriggerEvent('esx_license:checkLicense', src, licenseType, function(has) p:resolve(has) end)
    return Citizen.Await(p) == true
end

---------------------------------------------------------------------------
-- Gewone winkel
---------------------------------------------------------------------------
lib.callback.register('rp_shops:buy', function(source, shopId, item, count, account)
    local shop = shopById[shopId]
    local xPlayer = ESX.GetPlayerFromId(source)
    if not shop or not xPlayer or shop.type == 'weapons' then return { ok = false, msg = 'shop.invalid' } end
    if not throttle(source, 'buy', 600) then return { ok = false, msg = 'shop.too_fast' } end
    if not nearShop(source, shop) then return { ok = false, msg = 'shop.too_far' } end
    if inCombat(source) then return { ok = false, msg = 'shop.in_combat' } end

    count = math.floor(tonumber(count) or 0)
    if count < 1 or count > ShopCfg.MaxPerPurchase then return { ok = false, msg = 'shop.invalid' } end

    local entry
    for _, e in ipairs(ShopCfg.Catalogs[shop.catalog] or {}) do
        if e.item == item then entry = e break end
    end
    if not entry then return { ok = false, msg = 'shop.invalid' } end

    if not xPlayer.canCarryItem(item, count) then return { ok = false, msg = 'shop.cannot_carry' } end

    local total = entry.price * count
    if not pay(xPlayer, account, total, ('Winkel %s: %dx %s'):format(shop.label, count, item)) then
        return { ok = false, msg = 'shop.no_money', param = total }
    end
    xPlayer.addInventoryItem(item, count)
    if total >= ShopCfg.LogOver then
        exports.server_logs:Log('money', 'Winkelaankoop', ('%s kocht %dx %s voor €%d bij %s'):format(
            exports.server_logs:Describe(source), count, item, total, shop.label))
    end
    return { ok = true, msg = 'shop.bought', param = total }
end)

---------------------------------------------------------------------------
-- Ammu-Nation
---------------------------------------------------------------------------
lib.callback.register('rp_shops:weaponInfo', function(source)
    return { hasLicense = hasLicense(source, ShopCfg.WeaponShop.licenseType) }
end)

lib.callback.register('rp_shops:buyLicense', function(source, shopId, account)
    local shop = shopById[shopId]
    local xPlayer = ESX.GetPlayerFromId(source)
    if not shop or shop.type ~= 'weapons' or not xPlayer then return { ok = false, msg = 'shop.invalid' } end
    if not nearShop(source, shop) then return { ok = false, msg = 'shop.too_far' } end
    if not throttle(source, 'license', 2000) then return { ok = false, msg = 'shop.too_fast' } end
    if hasLicense(source, ShopCfg.WeaponShop.licenseType) then return { ok = false, msg = 'shop.have_license' } end
    if not pay(xPlayer, account, ShopCfg.WeaponShop.licensePrice, 'Wapenlicentie') then
        return { ok = false, msg = 'shop.no_money', param = ShopCfg.WeaponShop.licensePrice }
    end
    TriggerEvent('esx_license:addLicense', source, ShopCfg.WeaponShop.licenseType, function() end)
    exports.server_logs:Log('money', 'Wapenlicentie gekocht', exports.server_logs:Describe(source))
    return { ok = true, msg = 'shop.license_bought' }
end)

lib.callback.register('rp_shops:buyWeapon', function(source, shopId, weapon, account)
    local shop = shopById[shopId]
    local xPlayer = ESX.GetPlayerFromId(source)
    if not shop or shop.type ~= 'weapons' or not xPlayer then return { ok = false, msg = 'shop.invalid' } end
    if not nearShop(source, shop) then return { ok = false, msg = 'shop.too_far' } end
    if not throttle(source, 'weapon', 1500) then return { ok = false, msg = 'shop.too_fast' } end
    if inCombat(source) then return { ok = false, msg = 'shop.in_combat' } end

    local entry
    for _, w in ipairs(ShopCfg.WeaponShop.weapons) do
        if w.weapon == weapon then entry = w break end
    end
    if not entry then return { ok = false, msg = 'shop.invalid' } end
    if not hasLicense(source, ShopCfg.WeaponShop.licenseType) then return { ok = false, msg = 'shop.need_license' } end
    if xPlayer.hasWeapon(entry.weapon) then return { ok = false, msg = 'shop.have_weapon' } end

    if not pay(xPlayer, account, entry.price, 'Wapenaankoop ' .. entry.weapon) then
        return { ok = false, msg = 'shop.no_money', param = entry.price }
    end
    xPlayer.addWeapon(entry.weapon, entry.ammo)
    exports.server_logs:Log('money', 'Wapenaankoop', ('%s kocht %s voor €%d'):format(
        exports.server_logs:Describe(source), entry.weapon, entry.price))
    return { ok = true, msg = 'shop.bought', param = entry.price }
end)

---------------------------------------------------------------------------
-- Bruikbare items
---------------------------------------------------------------------------
for name, effect in pairs(ShopCfg.Consumables) do
    ESX.RegisterUsableItem(name, function(source)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return end
        if inCombat(source) then
            ServerCfg.Notify(source, 'error', 'shop.in_combat')
            return
        end
        if not throttle(source, 'use', ShopCfg.UseCooldownMs) then return end
        if xPlayer.getInventoryItem(name).count < 1 then return end

        xPlayer.removeInventoryItem(name, 1)
        if effect.hunger then TriggerClientEvent('esx_status:add', source, 'hunger', effect.hunger) end
        if effect.thirst then TriggerClientEvent('esx_status:add', source, 'thirst', effect.thirst) end
        if effect.anim == 'eat' then TriggerClientEvent('esx_basicneeds:onEat', source) end
        if effect.anim == 'drink' then TriggerClientEvent('esx_basicneeds:onDrink', source) end
        if effect.heal then TriggerClientEvent('rp_shops:heal', source, effect.heal) end
    end)
end

AddEventHandler('playerDropped', function()
    local prefix = source .. ':'
    for k in pairs(last) do if k:sub(1, #prefix) == prefix then last[k] = nil end end
end)
