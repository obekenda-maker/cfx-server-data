-- Tests rp_jobs (server): dienst, politie, medic/dood, bezorging, taxi, monteur
Mock.loadCore()
local RES = 'resources/[roleplay]/rp_jobs/'
Mock.load('rp_jobs', RES .. 'config.lua')
for _, f in ipairs({ 'main', 'police', 'medic', 'mechanic', 'taxi', 'delivery' }) do Mock.load('rp_jobs', RES .. 'server/' .. f .. '.lua') end
Mock.stepThreads()

--- Callback met een korte klokstap ervoor: de nieuwe spam-throttles (≤2 s) mogen de échte cooldowns niet maskeren
local function slow(name, src, ...)
    Mock.advance(2100)
    return Mock.callback(name, src, ...)
end

local deposits = {}
AddEventHandler('esx_addonaccount:getSharedAccount', function(name, cb)
    cb({ addMoney = function(m) deposits[name] = (deposits[name] or 0) + m end })
end)

local function reset()
    local srcs = {}
    for src in pairs(Mock.xPlayers) do srcs[#srcs + 1] = src end
    for _, src in ipairs(srcs) do Mock.removePlayer(src) end
    Mock.events, Mock.logs, deposits = {}, {}, {}
    DB.exec('DELETE FROM rp_cooldowns')
    Mock.advance(300000)
end

local function at(x, y, z) return { x = x + 0.0, y = y + 0.0, z = (z or 30.0) + 0.0 } end

Test.case('dienst in/uit met server-afstandscontrole', function()
    reset()
    local d = JobsCfg.Duty[1]
    local xp = Mock.addPlayer(1, { job = 'police', grade = 1, coords = at(d.coords.x + 1, d.coords.y, d.coords.z) })
    local r = Mock.callback('rp_jobs:toggleDuty', 1, 1)
    Test.ok(r.ok and not r.onDuty, 'uit dienst')
    Test.eq(xp.job.name, 'offpolice', 'job = offpolice')
    Test.eq(xp.job.grade, 1, 'grade blijft gelijk')
    Mock.advance(3000)
    r = Mock.callback('rp_jobs:toggleDuty', 1, 1)
    Test.ok(r.ok and r.onDuty, 'weer op dienst')
    Test.eq(xp.job.name, 'police', 'job = police')
    Mock.advance(3000)
    Mock.players[1].coords = at(0, 0)
    Test.eq(Mock.callback('rp_jobs:toggleDuty', 1, 1).msg, 'jobs.too_far', 'te ver weg')
    Mock.advance(3000)
    xp.job.name = 'unemployed'; Mock.players[1].coords = at(d.coords.x, d.coords.y, d.coords.z)
    Test.eq(Mock.callback('rp_jobs:toggleDuty', 1, 1).msg, 'jobs.not_employee', 'niet in dienst')
    Test.eq(Mock.callback('rp_jobs:toggleDuty', 1, 99).msg, 'jobs.duty_invalid', 'ongeldig index')
end)

Test.case('politie: boeien/fouilleren/boete met validatie', function()
    reset()
    local cop = Mock.addPlayer(1, { job = 'police', coords = at(0, 0) })
    local civ = Mock.addPlayer(2, { coords = at(1, 0), money = 1000, bank = 5000 })
    civ.addInventoryItem('bread', 2)
    local call = function(a, t, e) return Mock.callback('rp_jobs:police:action', 1, a, t, e) end

    local r = Mock.callback('rp_jobs:police:action', 2, 'cuff', 1)
    Test.eq(r.msg, 'jobs.not_police', 'burger kan niet boeien')

    Test.eq(call('search', 2).msg, 'jobs.search_needs_cuffs', 'fouilleren vereist boeien')
    Mock.advance(1000)
    Test.ok(call('cuff', 2).ok, 'boeien')
    Test.eq(Mock.players[2].state.isCuffed, true, 'state bag')
    Mock.advance(1000)
    Test.eq(call('cuff', 2).msg, 'jobs.already_cuffed', 'dubbel boeien')
    Mock.advance(1000)
    local s = call('search', 2)
    Test.ok(s.ok and s.data.cash == 1000, 'fouillering levert gegevens')
    Test.eq(s.data.items[1].count, 2, 'items in fouillering')

    Mock.advance(1000)
    Test.eq(call('fine', 2, { amount = 999999, reason = 'x' }).msg, 'jobs.fine_invalid', 'boete boven maximum')
    Mock.advance(1000)
    local f = call('fine', 2, { amount = 2000, reason = 'Te hard rijden' })
    Test.ok(f.ok, 'boete')
    Test.eq(civ.money, 0, 'eerst contant afgeschreven')
    Test.eq(civ.accounts.bank, 4000, 'dan bank')
    Test.eq(deposits.society_police, 2000, 'boete naar society')

    Mock.players[2].coords = at(50, 0)
    Mock.advance(1000)
    Test.eq(call('uncuff', 2).msg, 'jobs.too_far', 'te ver weg')
    Mock.players[2].coords = at(1, 0)
    Mock.advance(1000)
    Test.ok(call('uncuff', 2).ok, 'ontboeien')
    Test.eq(Mock.players[2].state.isCuffed, false, 'state uit')
end)

Test.case('dood: RDM-logging, hulp melden, revive, ziekenhuis', function()
    reset()
    local medic = Mock.addPlayer(1, { job = 'ambulance', coords = at(0, 0) })
    local patient = Mock.addPlayer(2, { coords = at(2, 0), money = 100, bank = 0 })
    local killer = Mock.addPlayer(3, { coords = at(40, 0) })

    -- RDM
    Mock.players[2].health = 0
    Mock.fire('rp_jobs:died', 2, 3)
    Test.eq(#Mock.logsOf('combat'), 1, 'RDM-melding (nog laag niveau)')
    for i = 1, 3 do Mock.advance(4000); Mock.fire('rp_jobs:died', 2, 3) end
    Test.ok(#Mock.logsOf('suspicious') >= 1, 'herhaald → suspicious')

    -- hulp melden
    local c = slow('rp_jobs:callMedics', 2)
    Test.eq(c.msg, 'jobs.call_sent', 'melding verstuurd')
    Test.eq(#Mock.eventsNamed('rp_jobs:medicCall', 1), 1, 'medic ontving melding')
    Test.eq(slow('rp_jobs:callMedics', 2).msg, 'jobs.call_wait', 'cooldown')

    -- revive
    Mock.advance(5000)
    Test.eq(slow('rp_jobs:revive', 3, 2).msg, 'jobs.not_medic', 'geen medic')
    Mock.players[2].coords = at(30, 0)
    Test.eq(slow('rp_jobs:revive', 1, 2).msg, 'jobs.too_far', 'te ver')
    Mock.players[2].coords = at(2, 0)
    Mock.players[2].health = 200
    Test.eq(slow('rp_jobs:revive', 1, 2).msg, 'jobs.not_down', 'niet down')
    Mock.players[2].health = 0
    Mock.advance(4000)
    local r = slow('rp_jobs:revive', 1, 2)
    Test.ok(r.ok, 'revive')
    Test.eq(patient.money, 0, 'behandelkosten (max wat de speler heeft)')
    Test.eq(deposits.society_ambulance, 100, 'kosten naar society')
    Test.eq(#Mock.eventsNamed('rp_jobs:revived', 2), 1, 'patiënt ontvangt revive')

    -- ziekenhuis
    Mock.players[2].health = 0
    Mock.fire('rp_jobs:died', 2)
    Test.eq(slow('rp_jobs:hospitalRespawn', 2).msg, 'jobs.respawn_wait', 'te vroeg')
    Mock.advance(JobsCfg.Death.respawnAfterSeconds * 1000 + 1000)
    patient.money = 100
    local h = slow('rp_jobs:hospitalRespawn', 2)
    Test.ok(h.ok, 'ziekenhuis-respawn')
    Test.eq(h.fee, 100, 'kosten nooit hoger dan bezit')
    Test.ok(h.spawn.x ~= nil, 'spawn gekozen')
    Mock.players[2].health = 200
    Test.eq(slow('rp_jobs:hospitalRespawn', 2).msg, 'jobs.not_down', 'levend: niet toegestaan')
end)

Test.case('dood in PvP wordt niet door rp_jobs afgehandeld', function()
    reset()
    Mock.registry.combat_core = { IsInCombat = function(src) return true end }
    Mock.addPlayer(1, { coords = at(0, 0) }); Mock.addPlayer(2, { coords = at(5, 0) })
    Mock.players[1].health = 0
    Mock.fire('rp_jobs:died', 1, 2)
    Test.eq(#Mock.logsOf('combat'), 0, 'geen RDM-log tijdens PvP')
    Test.eq(slow('rp_jobs:hospitalRespawn', 1).msg, 'jobs.in_pvp', 'geen ziekenhuis-respawn in PvP')
    Mock.registry.combat_core = nil
end)

Test.case('bezorging: route, anti-teleport, voertuig, daglimiet', function()
    reset()
    local cfg = JobsCfg.Delivery.courier
    local xp = Mock.addPlayer(1, { job = 'courier', coords = at(cfg.depot.coords.x, cfg.depot.coords.y, cfg.depot.coords.z) })
    Test.eq(slow('rp_jobs:delivery:finish', 1).msg, 'jobs.no_mission', 'geen missie')

    local r = Mock.callback('rp_jobs:delivery:start', 1, 'courier')
    Test.ok(r.ok and r.route.pay > 0, 'missie gestart')
    local dest = r.route.coords
    -- teleporteren + meteen claimen
    Mock.addVehicle(11, 'faggio2', 'JOB1', at(dest.x, dest.y, dest.z))
    Mock.setVehicleOf(1, 11)
    Mock.players[1].coords = at(dest.x, dest.y, dest.z)
    Mock.advance(1000)
    local f = slow('rp_jobs:delivery:finish', 1)
    Test.eq(f.msg, 'jobs.too_fast_delivery', 'teleport-claim geweigerd')
    Test.ok(#Mock.logsOf('suspicious') >= 1, 'suspicious gelogd')
    Test.eq(xp.money, 1000, 'geen geld')

    -- eerlijke bezorging
    Mock.advance(3000)
    Mock.players[1].coords = at(cfg.depot.coords.x, cfg.depot.coords.y, cfg.depot.coords.z)
    r = Mock.callback('rp_jobs:delivery:start', 1, 'courier')
    dest = r.route.coords
    local dx, dy = dest.x - cfg.depot.coords.x, dest.y - cfg.depot.coords.y
    local meters = math.sqrt(dx * dx + dy * dy)
    Mock.players[1].coords = at(dest.x, dest.y, dest.z)
    Mock.setVehicleOf(1, 0)
    Mock.advance(meters / cfg.maxSpeed * 1000 + 2000)
    Test.eq(slow('rp_jobs:delivery:finish', 1).msg, 'jobs.wrong_vehicle', 'geen voertuig')
    Mock.setVehicleOf(1, 11)
    f = slow('rp_jobs:delivery:finish', 1)
    Test.ok(f.ok, 'bezorging betaald')
    Test.eq(xp.money, 1000 + f.param, 'geld ontvangen')
    Test.eq(DB.scalar('SELECT `amount` FROM rp_cooldowns WHERE identifier = ? AND `action` = ?', { xp.identifier, 'delivery:courier' }), f.param, 'daglimiet geregistreerd')
    Test.eq(slow('rp_jobs:delivery:finish', 1).msg, 'jobs.no_mission', 'niet dubbel betaald')

    -- daglimiet
    DB.exec('UPDATE rp_cooldowns SET `amount` = ? WHERE identifier = ?', { cfg.dailyMax, xp.identifier })
    Mock.advance(3000)
    Mock.players[1].coords = at(cfg.depot.coords.x, cfg.depot.coords.y, cfg.depot.coords.z)
    Test.eq(Mock.callback('rp_jobs:delivery:start', 1, 'courier').msg, 'jobs.daily_max', 'daglimiet bereikt')
    -- verkeerde job
    xp.job.name = 'unemployed'
    Mock.advance(3000)
    Test.eq(Mock.callback('rp_jobs:delivery:start', 1, 'courier').msg, 'jobs.not_employee', 'verkeerde baan')
end)

Test.case('taxi: passagier betaalt, tarief begrensd, overdracht (geen geld erbij)', function()
    reset()
    local driver = Mock.addPlayer(1, { job = 'taxi', coords = at(0, 0), money = 0 })
    local pax = Mock.addPlayer(2, { coords = at(0, 0), money = 1000, bank = 0 })
    Mock.addVehicle(21, 'asea', 'TAXI', at(0, 0)); Mock.addVehicle(22, 'asea', 'ANDER', at(0, 0))
    Mock.setVehicleOf(1, 21); Mock.setVehicleOf(2, 22)
    Mock.clientCallbacks['rp_jobs:taxi:confirm'] = function() return true end
    Test.eq(Mock.callback('rp_jobs:taxi:charge', 1, 2, 5).msg, 'jobs.not_in_vehicle', 'andere auto')
    Mock.setVehicleOf(2, 21)
    Mock.advance(6000)
    local total = driver.money + pax.money
    local r = Mock.callback('rp_jobs:taxi:charge', 1, 2, 5)
    Test.ok(r.ok, 'rit afgerekend')
    Test.eq(pax.money, 1000 - 650, 'tarief 50 + 5×120')
    Test.eq(driver.money, 520, 'chauffeur krijgt 80%')
    Test.eq(deposits.society_taxi, 130, 'society krijgt 20%')
    Test.eq(driver.money + pax.money + deposits.society_taxi, total, 'geld alleen overgedragen')
    Mock.advance(6000)
    Mock.clientCallbacks['rp_jobs:taxi:confirm'] = function() return false end
    local before = pax.money
    Test.eq(Mock.callback('rp_jobs:taxi:charge', 1, 2, 5).msg, 'jobs.fare_refused', 'passagier weigert')
    Test.eq(pax.money, before, 'niets afgeschreven')
    Mock.advance(6000)
    Mock.clientCallbacks['rp_jobs:taxi:confirm'] = function(_, fare) Test.eq(fare, JobsCfg.Taxi.maxFare, 'tarief gemaximeerd') return true end
    Mock.callback('rp_jobs:taxi:charge', 1, 2, 999)
    Test.eq(Mock.callback('rp_jobs:taxi:charge', 2, 1, 5).msg, 'jobs.not_taxi', 'passagier is geen chauffeur')
end)

Test.case('monteur: kit verplicht en verbruikt, afstand', function()
    reset()
    local m = Mock.addPlayer(1, { job = 'mechanic', coords = at(0, 0) })
    local net = Mock.addVehicle(31, 'asea', 'KAPOT', at(2, 0))
    Test.eq(Mock.callback('rp_jobs:mechanic:finishRepair', 1, net).msg, 'jobs.no_repairkit', 'geen kit')
    m.addInventoryItem('repairkit', 1)
    Mock.advance(4000)
    Test.ok(Mock.callback('rp_jobs:mechanic:finishRepair', 1, net).ok, 'repareren')
    Test.eq(m.inventory.repairkit, 0, 'kit verbruikt')
    m.addInventoryItem('repairkit', 1)
    Mock.vehicles[31].coords = at(60, 0)
    Mock.advance(4000)
    Test.eq(Mock.callback('rp_jobs:mechanic:finishRepair', 1, net).msg, 'jobs.too_far', 'te ver')
    Mock.addPlayer(2, { coords = at(0, 0) })
    Test.eq(Mock.callback('rp_jobs:mechanic:finishRepair', 2, net).msg, 'jobs.not_mechanic', 'geen monteur')
end)
