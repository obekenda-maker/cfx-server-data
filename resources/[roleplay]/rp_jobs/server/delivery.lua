--[[
    rp_jobs/server/delivery.lua – vrachtwagenchauffeur en bezorger.
    Server bepaalt route + beloning, controleert afstand, voertuigmodel, minimale reistijd en dagmaximum.
]]

local missions = {}   -- [source] = { kind, route, startedAt, from }

local function u32(h) return (tonumber(h) or 0) & 0xFFFFFFFF end

lib.callback.register('rp_jobs:delivery:start', function(source, kind)
    local cfg = JobsCfg.Delivery[kind]
    if not cfg then return { ok = false, msg = 'jobs.invalid' } end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or Jobs.jobName(xPlayer) ~= cfg.job then return { ok = false, msg = 'jobs.not_employee', param = cfg.label } end
    if not Jobs.throttle(source, 'dstart', 2000) then return { ok = false, msg = 'jobs.too_fast' } end

    local c = Jobs.coordsOf(source)
    if not c or Jobs.dist(c, cfg.depot.coords) > 30.0 then return { ok = false, msg = 'jobs.too_far' } end

    local daily = Jobs.getDaily(xPlayer.identifier, 'delivery:' .. kind)
    if daily.amount >= cfg.dailyMax then return { ok = false, msg = 'jobs.daily_max' } end

    local previous = missions[source] and missions[source].route
    local route
    for _ = 1, 6 do
        route = cfg.routes[math.random(#cfg.routes)]
        if route ~= previous or #cfg.routes == 1 then break end
    end

    missions[source] = { kind = kind, route = route, startedAt = GetGameTimer(), from = { x = c.x, y = c.y, z = c.z } }
    return {
        ok = true,
        route = { label = route.label, coords = { x = route.coords.x, y = route.coords.y, z = route.coords.z }, pay = route.pay },
    }
end)

lib.callback.register('rp_jobs:delivery:finish', function(source)
    if not Jobs.throttle(source, 'dfinish', 1500) then return { ok = false, msg = 'jobs.too_fast' } end
    local m = missions[source]
    if not m then return { ok = false, msg = 'jobs.no_mission' } end
    local cfg = JobsCfg.Delivery[m.kind]
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or Jobs.jobName(xPlayer) ~= cfg.job then missions[source] = nil return { ok = false, msg = 'jobs.not_employee', param = cfg.label } end

    local c = Jobs.coordsOf(source)
    if not c or Jobs.dist(c, m.route.coords) > cfg.finishDistance + 6.0 then return { ok = false, msg = 'jobs.too_far' } end

    -- juiste voertuig?
    local ped = GetPlayerPed(source)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or u32(GetEntityModel(veh)) ~= u32(joaat(cfg.depot.vehicle)) then
        return { ok = false, msg = 'jobs.wrong_vehicle' }
    end

    -- realistische reistijd
    local minSeconds = Jobs.dist(m.from, m.route.coords) / cfg.maxSpeed
    local elapsed = (GetGameTimer() - m.startedAt) / 1000
    if elapsed < minSeconds then
        exports.server_logs:Log('suspicious', 'Te snelle bezorging', ('%s deed %s in %.0fs (minimaal %.0fs)'):format(
            exports.server_logs:Describe(source), m.route.label, elapsed, minSeconds))
        missions[source] = nil
        return { ok = false, msg = 'jobs.too_fast_delivery' }
    end

    local daily = Jobs.getDaily(xPlayer.identifier, 'delivery:' .. m.kind)
    local pay = math.min(m.route.pay, math.max(0, cfg.dailyMax - daily.amount))
    missions[source] = nil
    if pay <= 0 then return { ok = false, msg = 'jobs.daily_max' } end

    xPlayer.addMoney(pay, 'Bezorging ' .. m.route.label)
    Jobs.addDaily(xPlayer.identifier, 'delivery:' .. m.kind, 1, pay)
    exports.server_logs:Log('money', 'Bezorgbeloning', ('%s ontving €%d voor %s (%s)'):format(
        exports.server_logs:Describe(source), pay, m.route.label, cfg.label))
    return { ok = true, msg = 'jobs.delivery_paid', param = pay }
end)

lib.callback.register('rp_jobs:delivery:cancel', function(source)
    missions[source] = nil
    return true
end)

AddEventHandler('playerDropped', function() missions[source] = nil end)
