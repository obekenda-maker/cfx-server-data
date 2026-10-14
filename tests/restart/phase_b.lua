-- FASE B (na de herstart): nieuwe Lua-runtime, dezelfde database → alles moet er nog zijn
Mock.loadAll()
local function addP(src, opts)
    local xp = Mock.addPlayer(src, opts)
    TriggerEvent('esx:playerLoaded', src, xp, false)
    return xp
end
local function at(v) return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0 } end

Test.eq(DB.scalar('SELECT COUNT(*) FROM combat_stats'), 2, 'combat_stats rijen bewaard')
Test.eq(next(Combat.Players), nil, 'geen PvP-deelnemers na herstart (geen vastgelopen toestand)')
Test.eq(Mock.registry.combat_core.IsInCombat(1), false, 'niemand in combat')

local a = addP(1, { identifier = 'license:persist1', name = 'Persist Een', coords = { x = 0.0, y = 0.0, z = 30.0 } })
local b = addP(2, { identifier = 'license:persist2', name = 'Persist Twee', coords = { x = 0.0, y = 0.0, z = 30.0 } })

-- combat-stats + dagcap
local st = exports.combat_stats:Get(1)
Test.eq(st.kills, 1, 'kills bewaard'); Test.eq(st.xp, CombatCfg.Rewards.killXp, 'xp bewaard')
Test.eq(exports.combat_stats:Get(2).deaths, 1, 'deaths bewaard')
Test.eq(exports.combat_stats:GetEarnedToday(1), CombatCfg.Rewards.killMoney, 'dagcap-teller blijft staan na herstart (geen reset-misbruik)')
Test.eq(exports.combat_stats:GetLeaderboard(5, 'kills')[1].name, 'Persist Een', 'leaderboard na herstart')

-- gang
local g = Gang.of(1)
Test.ok(g ~= nil and g.label == 'Blijvers' and g.color == '#00ff00', 'gang geladen')
Test.eq(g.bank, 40000 - GangCfg.Territory.claimCost, 'gangkas bewaard (storting min claimkosten)')
local _, m2 = Gang.of(2)
Test.eq(m2.grade, 2, 'ganggrade van lid bewaard')
Test.eq(Gang.territories.grove.gang_id, g.id, 'territoriumeigenaar bewaard')
Test.ok(Gang.territories.grove.lockedUntil > 0, 'vergrendeling bewaard')
Test.eq(Mock.players[1].state.gangId, g.id, 'state bag gangId na herstart gezet')
Test.eq(Mock.callback('rp_gangs:getTerritories', 1)[1].ownerLabel, 'Blijvers', 'territoria naar client met eigenaar')

-- voertuigen
Mock.players[1].coords = at(GarageCfg.Garages[1].coords)
local list = Mock.callback('rp_garages:list', 1, 'legion')
Test.eq(#list, 1, 'het opgeslagen voertuig staat in de garage')
Mock.players[1].coords = at(GarageCfg.Impound.coords); Mock.advance(2000)
local imp = Mock.callback('rp_garages:impoundList', 1)
Test.eq(#imp, 1, 'het uitgeparkeerde voertuig (niet meer in de wereld na herstart) staat in het depot')
Mock.advance(3000)
a.accounts.bank = 5000
local r = Mock.callback('rp_garages:impoundRetrieve', 1, imp[1].plate)
Test.ok(r.ok, 'ophalen uit depot na herstart (geen verloren voertuig)')

-- admin
local conn = { done = false }
Mock.players[9] = { coords = at({ x = 0, y = 0, z = 0 }), name = 'Boef', identifiers = { 'license:lic9', 'discord:dis9' } }
local res = {}
Mock.fire('playerConnecting', 9, 'Boef', function() end, { defer = function() end, update = function() end, done = function(m) res.msg = m end })
Test.ok(res.msg ~= nil and res.msg:find('Persistent', 1, true), 'ban werkt na herstart')
Test.eq(DB.scalar('SELECT COUNT(*) FROM admin_warnings WHERE license = ?', { 'license:lic1' }), 1, 'waarschuwing bewaard (op Rockstar-license)')

-- dagelijkse limiet voor bezorging
local d = exports.rp_jobs:GetDaily('license:persist1', 'delivery:courier')
Test.eq(d.count, 1, 'bezorgteller bewaard'); Test.ok(d.amount > 0, 'bezorgbedrag bewaard (geen reset via herstart)')

-- wat ESX zelf bewaart (users: geld/job/positie) valt buiten onze tabellen en wordt hier NIET getest
