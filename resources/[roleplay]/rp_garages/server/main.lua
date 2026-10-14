--[[
    rp_garages/server/main.lua
    Alle eigendoms-, prijs- en afstandscontroles gebeuren hier. De client stuurt alleen verzoeken.
]]

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function u32(h) return (tonumber(h) or 0) & 0xFFFFFFFF end

local throttle = ServerCfg.Throttle
local near = ServerCfg.PlayerNear
local pay = ServerCfg.Pay

local garageById, catalog = {}, {}
for _, g in ipairs(GarageCfg.Garages) do garageById[g.id] = g end
for _, cat in ipairs(GarageCfg.Shop.categories) do
    for _, v in ipairs(cat.vehicles) do catalog[v.model] = v end
end

local locks = {}   -- [plate] = tijdstip tot wanneer dit kenteken vergrendeld is (tegen dubbel uitparkeren)

--- Alle kentekens van voertuigen die nu in de wereld staan (één scan per aanroep)
local function worldPlates()
    local set = {}
    for _, veh in ipairs(GetAllVehicles()) do set[trim(GetVehicleNumberPlateText(veh))] = veh end
    return set
end

local function plateInWorld(plate, set)
    return (set or worldPlates())[plate]
end

local function ownedRow(identifier, plate)
    return MySQL.single.await(
        'SELECT plate, vehicle, `type`, `stored` FROM owned_vehicles WHERE owner = ? AND TRIM(plate) = ?',
        { identifier, plate })
end

---------------------------------------------------------------------------
-- Lijsten
---------------------------------------------------------------------------
lib.callback.register('rp_garages:list', function(source, garageId)
    if not throttle(source, 'list', 700) then return {} end
    local garage = garageById[garageId]
    local xPlayer = ESX.GetPlayerFromId(source)
    if not garage or not xPlayer then return {} end
    if not near(source, garage.coords, GarageCfg.RetrieveDistance + 10.0) then return {} end

    local rows = MySQL.query.await(
        'SELECT plate, vehicle FROM owned_vehicles WHERE owner = ? AND `type` = ? AND `stored` = 1 ORDER BY plate',
        { xPlayer.identifier, 'car' }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local ok, props = pcall(json.decode, r.vehicle)
        if ok and type(props) == 'table' and props.model then
            out[#out + 1] = { plate = trim(r.plate), model = props.model }
        end
    end
    return out
end)

lib.callback.register('rp_garages:impoundList', function(source)
    if not throttle(source, 'ilist', 700) then return {} end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not near(source, GarageCfg.Impound.coords, GarageCfg.RetrieveDistance + 10.0) then return {} end
    local rows = MySQL.query.await(
        'SELECT plate, vehicle FROM owned_vehicles WHERE owner = ? AND `type` = ? AND `stored` = 0 ORDER BY plate',
        { xPlayer.identifier, 'car' }) or {}
    local out = {}
    local inWorld = worldPlates()
    for _, r in ipairs(rows) do
        local plate = trim(r.plate)
        if not inWorld[plate] then
            local ok, props = pcall(json.decode, r.vehicle)
            if ok and type(props) == 'table' and props.model then
                out[#out + 1] = { plate = plate, model = props.model }
            end
        end
    end
    return out
end)

---------------------------------------------------------------------------
-- Uitparkeren (garage)
---------------------------------------------------------------------------
lib.callback.register('rp_garages:retrieve', function(source, garageId, plate)
    local garage = garageById[garageId]
    local xPlayer = ESX.GetPlayerFromId(source)
    if not garage or not xPlayer or type(plate) ~= 'string' then return { ok = false, msg = 'garage.invalid' } end
    if not throttle(source, 'retrieve', 1500) then return { ok = false, msg = 'garage.too_fast' } end
    if not near(source, garage.coords, GarageCfg.RetrieveDistance) then return { ok = false, msg = 'garage.too_far' } end
    plate = trim(plate)
    if (locks[plate] or 0) > GetGameTimer() then return { ok = false, msg = 'garage.locked' } end

    local row = ownedRow(xPlayer.identifier, plate)
    if not row then return { ok = false, msg = 'garage.not_owner' } end

    -- atomisch: alleen als het voertuig nog `stored = 1` is (voorkomt dubbel uitparkeren)
    local affected = MySQL.update.await(
        'UPDATE owned_vehicles SET `stored` = 0 WHERE owner = ? AND TRIM(plate) = ? AND `stored` = 1',
        { xPlayer.identifier, plate })
    if not affected or affected < 1 then return { ok = false, msg = 'garage.not_stored' } end

    locks[plate] = GetGameTimer() + 15000
    local ok, props = pcall(json.decode, row.vehicle)
    if not ok or type(props) ~= 'table' then
        MySQL.update.await('UPDATE owned_vehicles SET `stored` = 1 WHERE owner = ? AND TRIM(plate) = ?', { xPlayer.identifier, plate })
        return { ok = false, msg = 'garage.corrupt' }
    end
    return { ok = true, props = props }
end)

--- Spawn mislukt aan clientzijde → terugzetten in garage
lib.callback.register('rp_garages:restore', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or type(plate) ~= 'string' then return false end
    plate = trim(plate)
    if plateInWorld(plate) then return false end
    locks[plate] = nil
    MySQL.update.await('UPDATE owned_vehicles SET `stored` = 1 WHERE owner = ? AND TRIM(plate) = ? AND `stored` = 0',
        { xPlayer.identifier, plate })
    return true
end)

---------------------------------------------------------------------------
-- Opslaan
---------------------------------------------------------------------------
lib.callback.register('rp_garages:store', function(source, garageId, netId, props)
    local garage = garageById[garageId]
    local xPlayer = ESX.GetPlayerFromId(source)
    if not garage or not xPlayer or type(props) ~= 'table' then return { ok = false, msg = 'garage.invalid' } end
    if not throttle(source, 'store', 1500) then return { ok = false, msg = 'garage.too_fast' } end
    if not near(source, garage.coords, garage.storeRadius) then return { ok = false, msg = 'garage.too_far' } end

    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return { ok = false, msg = 'garage.no_vehicle' } end

    local plate = trim(GetVehicleNumberPlateText(entity))
    local row = ownedRow(xPlayer.identifier, plate)
    if not row then return { ok = false, msg = 'garage.not_owner' } end
    if row.type ~= 'car' then return { ok = false, msg = 'garage.invalid' } end

    -- voertuig moet bij de garage staan
    local v = GetEntityCoords(entity)
    local vc = { x = v.x, y = v.y, z = v.z }
    local gc = garage.coords
    local dist = math.sqrt((vc.x - gc.x) ^ 2 + (vc.y - gc.y) ^ 2 + (vc.z - gc.z) ^ 2)
    if dist > garage.storeRadius + 10.0 then return { ok = false, msg = 'garage.too_far' } end

    -- model mag niet veranderen (voorkomt "ruilen" van een goedkope auto voor een dure)
    local okOld, old = pcall(json.decode, row.vehicle)
    if not okOld or type(old) ~= 'table' or u32(old.model) ~= u32(GetEntityModel(entity)) then
        return { ok = false, msg = 'garage.model_mismatch' }
    end

    props.model = old.model
    props.plate = row.plate
    local encoded = json.encode(props)
    if #encoded > GarageCfg.MaxPropsLength then return { ok = false, msg = 'garage.invalid' } end

    MySQL.update.await('UPDATE owned_vehicles SET vehicle = ?, `stored` = 1 WHERE owner = ? AND TRIM(plate) = ?',
        { encoded, xPlayer.identifier, plate })
    DeleteEntity(entity)
    locks[plate] = nil
    return { ok = true, msg = 'garage.stored' }
end)

---------------------------------------------------------------------------
-- Impound
---------------------------------------------------------------------------
lib.callback.register('rp_garages:impoundRetrieve', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or type(plate) ~= 'string' then return { ok = false, msg = 'garage.invalid' } end
    if not throttle(source, 'impound', 1500) then return { ok = false, msg = 'garage.too_fast' } end
    if not near(source, GarageCfg.Impound.coords, GarageCfg.RetrieveDistance) then return { ok = false, msg = 'garage.too_far' } end
    plate = trim(plate)
    if (locks[plate] or 0) > GetGameTimer() then return { ok = false, msg = 'garage.locked' } end

    local row = ownedRow(xPlayer.identifier, plate)
    if not row then return { ok = false, msg = 'garage.not_owner' } end
    if row.stored == 1 or row.stored == true then return { ok = false, msg = 'garage.in_garage' } end
    if plateInWorld(plate) then return { ok = false, msg = 'garage.in_world' } end

    local fee = GarageCfg.Impound.fee
    local account = xPlayer.getAccount('bank').money >= fee and 'bank' or 'money'
    if not pay(xPlayer, account, fee, 'Depotkosten ' .. plate) then return { ok = false, msg = 'garage.no_money', param = fee } end

    locks[plate] = GetGameTimer() + 15000
    local ok, props = pcall(json.decode, row.vehicle)
    if not ok or type(props) ~= 'table' then return { ok = false, msg = 'garage.corrupt' } end
    exports.server_logs:Log('money', 'Depotkosten', ('%s betaalde €%d voor %s'):format(exports.server_logs:Describe(source), fee, plate))
    return { ok = true, props = props, fee = fee }
end)

---------------------------------------------------------------------------
-- Winkel
---------------------------------------------------------------------------
local function randomPlate()
    local fmt = GarageCfg.Shop.plateFormat
    local out = {}
    for i = 1, #fmt do
        local ch = fmt:sub(i, i)
        if ch == 'A' then out[i] = string.char(math.random(65, 90))
        elseif ch == '0' then out[i] = tostring(math.random(0, 9))
        else out[i] = ch end
    end
    return table.concat(out)
end

lib.callback.register('rp_garages:buy', function(source, model)
    local xPlayer = ESX.GetPlayerFromId(source)
    local entry = type(model) == 'string' and catalog[model]
    if not xPlayer or not entry then return { ok = false, msg = 'garage.invalid' } end
    if not throttle(source, 'buy', 3000) then return { ok = false, msg = 'garage.too_fast' } end
    if not near(source, GarageCfg.Shop.coords, GarageCfg.ShopDistance) then return { ok = false, msg = 'garage.too_far' } end

    local plate
    for _ = 1, 20 do
        local candidate = randomPlate()
        local exists = MySQL.scalar.await('SELECT 1 FROM owned_vehicles WHERE plate = ? LIMIT 1', { candidate })
        if not exists then plate = candidate break end
    end
    if not plate then return { ok = false, msg = 'garage.plate_fail' } end

    if not pay(xPlayer, GarageCfg.Shop.account, entry.price, 'Voertuigaankoop ' .. entry.label) then
        return { ok = false, msg = 'garage.no_money', param = entry.price }
    end

    local props = json.encode({ model = joaat(entry.model), plate = plate })
    MySQL.insert.await(
        'INSERT INTO owned_vehicles (owner, plate, vehicle, `type`, `stored`) VALUES (?, ?, ?, ?, 1)',
        { xPlayer.identifier, plate, props, 'car' })

    exports.server_logs:Log('money', 'Voertuig gekocht', ('%s kocht %s (%s) voor €%d'):format(
        exports.server_logs:Describe(source), entry.label, plate, entry.price))
    return { ok = true, msg = 'garage.bought', param = entry.label, plate = plate, garage = GarageCfg.Shop.deliverTo }
end)


-- Geheugen: verlopen kenteken-locks opruimen (elke 10 minuten)
CreateThread(function()
    while true do
        Wait(10 * 60 * 1000)
        local now = GetGameTimer()
        for plate, untilT in pairs(locks) do
            if untilT <= now then locks[plate] = nil end
        end
    end
end)
