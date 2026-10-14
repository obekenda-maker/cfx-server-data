--[[
    rp_jobs/server/taxi.lua – taxirit afrekenen.
    De PASSAGIER betaalt (bevestigt eerst); het bedrag wordt overgedragen, niet gecreëerd.
]]

local T = JobsCfg.Taxi

local function sameVehicle(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if not pa or pa == 0 or not pb or pb == 0 then return false end
    local va, vb = GetVehiclePedIsIn(pa, false), GetVehiclePedIsIn(pb, false)
    return va ~= 0 and va == vb
end

lib.callback.register('rp_jobs:taxi:charge', function(source, passengerId, km)
    local xDriver = ESX.GetPlayerFromId(source)
    if not xDriver or Jobs.jobName(xDriver) ~= T.job then return { ok = false, msg = 'jobs.not_taxi' } end
    passengerId = tonumber(passengerId)
    local xPassenger = passengerId and ESX.GetPlayerFromId(passengerId)
    if not xPassenger or passengerId == source then return { ok = false, msg = 'jobs.no_target' } end
    if not Jobs.throttle(source, 'taxi', 5000) then return { ok = false, msg = 'jobs.too_fast' } end
    if not sameVehicle(source, passengerId) then return { ok = false, msg = 'jobs.not_in_vehicle' } end

    km = math.max(0, math.min(tonumber(km) or 0, 60))
    local fare = math.min(T.maxFare, math.floor(T.baseFare + T.perKm * km))
    if fare < 1 then return { ok = false, msg = 'jobs.invalid' } end

    local accepted = lib.callback.await('rp_jobs:taxi:confirm', passengerId, fare, xDriver.getName())
    if not accepted then return { ok = false, msg = 'jobs.fare_refused' } end

    local charged = Jobs.charge(xPassenger, fare, 'Taxirit')
    if charged <= 0 then return { ok = false, msg = 'jobs.fare_no_money' } end

    local societyCut = math.floor(charged * T.societyShare)
    if societyCut > 0 and not Jobs.depositSociety(T.societyAccount, societyCut) then societyCut = 0 end
    local driverCut = charged - societyCut
    xDriver.addMoney(driverCut, 'Taxirit')

    exports.server_logs:Log('money', 'Taxirit', ('Passagier %s betaalde €%d aan chauffeur %s (society €%d)'):format(
        exports.server_logs:Describe(passengerId), charged, exports.server_logs:Describe(source), societyCut))
    ServerCfg.Notify(passengerId, 'inform', 'jobs.fare_paid', charged)
    return { ok = true, msg = 'jobs.fare_received', param = driverCut }
end)
