--[[
    RP_GARAGES – garages, impound en voertuigwinkel.
    Gebruikt de ESX-tabel `owned_vehicles` (owner, plate, vehicle, type, stored). Geen eigen voertuigtabel.
    Coördinaten: controleer in-game met /coords (admin).
]]

GarageCfg = {}

GarageCfg.Garages = {
    {
        id = 'legion', label = 'Garage Legion Square',
        coords = vec3(215.8, -810.1, 30.7), spawn = vec4(222.5, -801.0, 30.5, 250.0),
        storeRadius = 25.0, blip = { sprite = 357, colour = 3 },
    },
    {
        id = 'sandy', label = 'Garage Sandy Shores',
        coords = vec3(1737.0, 3710.0, 34.1), spawn = vec4(1744.0, 3716.0, 34.1, 20.0),
        storeRadius = 25.0, blip = { sprite = 357, colour = 3 },
    },
}

GarageCfg.Impound = {
    label = 'Depot (wegsleepdienst)',
    coords = vec3(409.0, -1623.0, 29.3), spawn = vec4(405.0, -1643.0, 27.6, 230.0),
    fee = 500,                 -- kosten om een voertuig op te halen dat niet in een garage staat
    blip = { sprite = 67, colour = 1 },
}

GarageCfg.Shop = {
    label = 'Premium Deluxe Motorsport',
    coords = vec3(-56.8, -1096.7, 26.4),
    distance = 3.0,
    account = 'bank',                 -- 'bank' of 'money'
    deliverTo = 'legion',             -- nieuw gekocht voertuig staat in deze garage
    blip = { sprite = 225, colour = 2 },
    plateFormat = 'AA 000 A',         -- A = letter, 0 = cijfer, rest letterlijk (max. 8 tekens)
    categories = {
        { label = 'Compact', vehicles = {
            { model = 'blista', label = 'Blista',   price = 9500 },
            { model = 'panto',  label = 'Panto',    price = 7000 },
            { model = 'issi2',  label = 'Issi',     price = 10500 },
        } },
        { label = 'Sedan', vehicles = {
            { model = 'asea',    label = 'Asea',    price = 12000 },
            { model = 'premier', label = 'Premier', price = 15000 },
            { model = 'tailgater', label = 'Tailgater', price = 38000 },
        } },
        { label = 'Sport', vehicles = {
            { model = 'sultan',   label = 'Sultan',   price = 45000 },
            { model = 'buffalo',  label = 'Buffalo',  price = 52000 },
            { model = 'dominator', label = 'Dominator', price = 60000 },
        } },
        { label = 'SUV / Bestel', vehicles = {
            { model = 'baller', label = 'Baller', price = 48000 },
            { model = 'bison',  label = 'Bison',  price = 30000 },
        } },
        { label = 'Motor / Scooter', vehicles = {
            { model = 'faggio2', label = 'Faggio', price = 3000 },
            { model = 'sanchez', label = 'Sanchez', price = 14000 },
        } },
    },
}

GarageCfg.RetrieveDistance = 15.0   -- server-controle afstand tot garage
GarageCfg.ShopDistance     = 25.0
GarageCfg.MaxPropsLength   = 20000  -- maximale grootte van opgeslagen voertuigeigenschappen (JSON-tekens)
