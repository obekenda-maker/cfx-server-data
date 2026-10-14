-- FASE A (vóór de herstart): maak data aan via de echte serverlogica
Mock.loadAll()
local function at(v) return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0 } end
local function addP(src, opts)
    local xp = Mock.addPlayer(src, opts)
    TriggerEvent('esx:playerLoaded', src, xp, false)
    return xp
end
local function bump() Mock.advance(3000) end

-- combat: twee spelers, één kill met beloning
local HAVEN = CombatCfg.Zones[1].coords
local a = addP(1, { identifier = 'license:persist1', name = 'Persist Een', coords = { x = HAVEN.x + 1, y = HAVEN.y, z = HAVEN.z }, bank = 100000 })
local b = addP(2, { identifier = 'license:persist2', name = 'Persist Twee', coords = { x = HAVEN.x + 2, y = HAVEN.y, z = HAVEN.z } })
Mock.callback('combat:join', 1, 'haven'); Mock.advance(1500); Mock.callback('combat:join', 2, 'haven')
Mock.advance(30000)
Mock.fire('combat:died', 2, 1, joaat('WEAPON_CARBINERIFLE'))
Test.eq(a.accounts.bank, 100000 + CombatCfg.Rewards.killMoney, 'A: beloning ontvangen')

-- gang + territorium + kas
Mock.clientCallbacks['rp_gangs:confirmInvite'] = function() return true end
local GROVE = GangCfg.Territories[1]
a.accounts.bank = 200000
Mock.callback('rp_gangs:create', 1, 'Blijvers', '#00ff00'); bump()
Mock.players[2].coords = { x = HAVEN.x + 2, y = HAVEN.y, z = HAVEN.z }
Mock.callback('rp_gangs:invite', 1, 2); bump()
a.money = 50000
Mock.callback('rp_gangs:deposit', 1, 40000); bump()
Mock.players[1].coords = at(GROVE.coords); Mock.players[2].coords = at(GROVE.coords)
Test.ok(Mock.callback('rp_gangs:claim', 1, 'grove').ok, 'territorium geclaimd')
bump()
Mock.callback('rp_gangs:setGrade', 1, 'license:persist2', 2)

-- voertuigen: koop twee, parkeer er één uit (blijft stored=0 → depot)
Mock.players[1].coords = at(GarageCfg.Shop.coords); a.accounts.bank = 500000
Test.ok(Mock.callback('rp_garages:buy', 1, 'blista').ok, 'voertuig 1 gekocht'); Mock.advance(4000)
Test.ok(Mock.callback('rp_garages:buy', 1, 'asea').ok, 'voertuig 2 gekocht'); Mock.advance(4000)
Mock.players[1].coords = at(GarageCfg.Garages[1].coords)
local plate = DB.scalar("SELECT plate FROM owned_vehicles WHERE owner = ? ORDER BY plate LIMIT 1", { 'license:persist1' })
Test.ok(Mock.callback('rp_garages:retrieve', 1, 'legion', plate).ok, 'voertuig uitgeparkeerd')

-- admin: ban + warning
Mock.addPlayer(3, { group = 'admin', name = 'Admin' }); Mock.addPlayer(9, { name = 'Boef' })
Mock.commands.ban(3, { '9', '5d', 'Persistent' }); bump()
Mock.commands.warn(3, { '1', 'Waarschuwing', 'test' })

-- dagelijkse bezorgbeloning
local cfg = JobsCfg.Delivery.courier
Mock.xPlayers[1].job.name = 'courier'
Mock.players[1].coords = at(cfg.depot.coords)
Mock.advance(10000)
local s = Mock.callback('rp_jobs:delivery:start', 1, 'courier')
Mock.addVehicle(70, 'faggio2', 'JOB', at(s.route.coords)); Mock.setVehicleOf(1, 70)
Mock.players[1].coords = at(s.route.coords); Mock.advance(600000)
Test.ok(Mock.callback('rp_jobs:delivery:finish', 1).ok, 'bezorging betaald')

-- netjes afsluiten zoals een server dat doet: resources stoppen (stats flushen), spelers vertrekken
for _, fn in ipairs(Mock.handlers['onResourceStop'] or {}) do fn('combat_stats') end
Mock.removePlayer(1); Mock.removePlayer(2)
