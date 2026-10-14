--[[
    RP_SHOPS – winkels en bruikbare items.
    Alle items moeten in de ESX-tabel `items` staan (zie sql/02_jobs_items.sql).
    Status-waarden: esx_status gebruikt standaard een maximum van 1.000.000.
]]

ShopCfg = {}

ShopCfg.MaxPerPurchase = 20
ShopCfg.ShopDistance   = 6.0     -- server-controle
ShopCfg.LogOver        = 2000    -- aankopen vanaf dit totaalbedrag worden gelogd
ShopCfg.AllowedAccounts = { money = true, bank = true }

ShopCfg.Catalogs = {
    general = {
        { item = 'bread',       price = 5 },
        { item = 'water',       price = 3 },
        { item = 'burger',      price = 12 },
        { item = 'cola',        price = 4 },
        { item = 'energydrink', price = 9 },
        { item = 'bandage',     price = 60 },
        { item = 'medkit',      price = 250 },
        { item = 'repairkit',   price = 600 },
    },
    liquor = {
        { item = 'water', price = 3 },
        { item = 'cola',  price = 4 },
    },
}

--- Ammu-Nation: wapens vereisen de 'weapon'-licentie (esx_license)
ShopCfg.WeaponShop = {
    licenseType  = 'weapon',
    licensePrice = 2500,
    weapons = {
        { weapon = 'WEAPON_PISTOL',       label = 'Pistool',        price = 4500, ammo = 48 },
        { weapon = 'WEAPON_COMBATPISTOL', label = 'Combat pistool', price = 6500, ammo = 48 },
        { weapon = 'WEAPON_BAT',          label = 'Honkbalknuppel', price = 400,  ammo = 1 },
        { weapon = 'WEAPON_KNIFE',        label = 'Mes',            price = 350,  ammo = 1 },
    },
}

--- Locaties. type = 'shop' (catalog) of 'weapons'
ShopCfg.Shops = {
    { id = 'ltd_davis',   label = 'LTD Davis',         coords = vec3(-47.0, -1758.2, 29.4),   catalog = 'general', blip = { sprite = 52, colour = 2 } },
    { id = 'tf_strawb',   label = '24/7 Strawberry',   coords = vec3(25.7, -1347.3, 29.5),    catalog = 'general', blip = { sprite = 52, colour = 2 } },
    { id = 'ltd_mirror',  label = 'LTD Mirror Park',   coords = vec3(1163.4, -323.8, 69.2),   catalog = 'general', blip = { sprite = 52, colour = 2 } },
    { id = 'ltd_seoul',   label = 'LTD Little Seoul',  coords = vec3(-707.5, -914.3, 19.2),   catalog = 'general', blip = { sprite = 52, colour = 2 } },
    { id = 'ltd_grape',   label = 'LTD Grapeseed',     coords = vec3(1698.4, 4924.4, 42.1),   catalog = 'general', blip = { sprite = 52, colour = 2 } },
    { id = 'robs_morning',label = 'Robs Liquor',       coords = vec3(-1222.9, -907.0, 12.3),  catalog = 'liquor',  blip = { sprite = 52, colour = 2 } },
    { id = 'ammu_adams',  label = 'Ammu-Nation',       coords = vec3(22.0, -1107.3, 29.8),    type = 'weapons',    blip = { sprite = 110, colour = 1 } },
}

--- Bruikbare items (effect server-side bepaald). eat/drink gebruiken esx_basicneeds-animaties.
--- bread en water worden al door esx_basicneeds geregistreerd en staan hier dus NIET in.
ShopCfg.Consumables = {
    burger      = { hunger = 350000, anim = 'eat' },
    cola        = { thirst = 250000, anim = 'drink' },
    energydrink = { thirst = 150000, anim = 'drink' },
    bandage     = { heal = 25 },
    medkit      = { heal = 60 },
}
ShopCfg.UseCooldownMs = 2500
