-- Tests rp_gangs (server) inclusief ganggevecht via combat_core en zwarte markt
Mock.loadCore()
Mock.load('combat_stats', 'resources/[combat]/combat_stats/config.lua')
Mock.load('combat_stats', 'resources/[combat]/combat_stats/server/main.lua')
Mock.load('combat_core', 'resources/[combat]/combat_core/config.lua')
Mock.load('combat_core', 'resources/[combat]/combat_core/shared/util.lua')
for _, f in ipairs({ 'zones', 'rules', 'rewards', 'damage', 'main' }) do Mock.load('combat_core', 'resources/[combat]/combat_core/server/' .. f .. '.lua') end
Mock.load('rp_jobs', 'resources/[roleplay]/rp_jobs/config.lua')
Mock.load('rp_jobs', 'resources/[roleplay]/rp_jobs/server/main.lua')
Mock.load('rp_gangs', 'resources/[roleplay]/rp_gangs/config.lua')
for _, f in ipairs({ 'main', 'territory', 'market' }) do Mock.load('rp_gangs', 'resources/[roleplay]/rp_gangs/server/' .. f .. '.lua') end
Mock.stepThreads()

--- Callback met een korte klokstap ervoor: de nieuwe spam-throttles (≤2 s) mogen de échte cooldowns niet maskeren
local function slow(name, src, ...)
    Mock.advance(2100)
    return Mock.callback(name, src, ...)
end

local function at(x, y, z) return { x = x + 0.0, y = y + 0.0, z = (z or 30.0) + 0.0 } end
local function c3(v) return at(v.x, v.y, v.z) end
local GROVE = GangCfg.Territories[1]

local function reset()
    local srcs = {}
    for src in pairs(Mock.xPlayers) do srcs[#srcs + 1] = src end
    for _, src in ipairs(srcs) do Mock.removePlayer(src) end
    for id in pairs(Combat.Zones) do if Combat.Zones[id].temporary then exports.combat_core:RemoveTemporaryZone(id) end end
    for k in pairs(Combat.Players) do Combat.Players[k] = nil end
    Combat.Cooldowns = {}
    Mock.timeouts = {}
    DB.exec('DELETE FROM rp_gang_members'); DB.exec('DELETE FROM rp_gangs'); DB.exec('UPDATE rp_gang_territories SET gang_id = NULL, locked_until = NULL')
    DB.exec('DELETE FROM rp_cooldowns'); DB.exec('DELETE FROM combat_stats')
    Gang.gangs, Gang.members, Gang.bySrc = {}, {}, {}
    for _, t in pairs(Gang.territories) do t.gang_id = nil t.lockedUntil = 0 end
    Mock.events, Mock.logs = {}, {}
    Mock.clientCallbacks['rp_gangs:confirmInvite'] = function() return true end
    Mock.advance(600000)
end

local function addP(src, opts)
    opts = opts or {}
    opts.coords = opts.coords or at(0, 0)
    local xp = Mock.addPlayer(src, opts)
    TriggerEvent('esx:playerLoaded', src, xp, false)
    return xp
end

local function bump() Mock.advance(3000) end

--- gang met leider `leader` en extra leden (grade 0 tenzij anders)
local function makeGang(name, leader, members, color)
    local r = Mock.callback('rp_gangs:create', leader, name, color or '#ff0000')
    assert(r.ok, 'gang aanmaken mislukt: ' .. tostring(r.msg))
    for _, m in ipairs(members or {}) do
        bump()
        local i = Mock.callback('rp_gangs:invite', leader, m)
        assert(i.ok, 'uitnodigen mislukt: ' .. tostring(i.msg))
    end
    return Gang.of(leader)
end

---------------------------------------------------------------------------
Test.case('gang oprichten: regels, kosten, unieke naam', function()
    reset()
    local xp = addP(1, { bank = 100000 })
    Test.eq(Mock.callback('rp_gangs:create', 1, 'ab', '#fff').msg, 'gang.name_invalid', 'te korte naam')
    bump()
    Test.eq(Mock.callback('rp_gangs:create', 1, 'Naam; DROP TABLE', '#fff').msg, 'gang.name_invalid', 'ongeldige tekens')
    bump()
    local r = Mock.callback('rp_gangs:create', 1, 'Grove Boys', 'geen-kleur')
    Test.ok(r.ok, 'aangemaakt')
    Test.eq(xp.accounts.bank, 100000 - GangCfg.Creation.cost, 'oprichtingskosten')
    local g = Gang.of(1)
    Test.eq(g.color, '#ff0000', 'ongeldige kleur → standaard')
    Test.eq(DB.scalar('SELECT grade FROM rp_gang_members WHERE identifier = ?', { xp.identifier }), GangCfg.LeaderGrade, 'leider in DB')
    Test.eq(Mock.players[1].state.gangId, g.id, 'state bag gangId')
    Test.eq(exports.rp_gangs:GetGangId(1), g.id, 'export GetGangId')
    bump()
    Test.eq(Mock.callback('rp_gangs:create', 1, 'Tweede', '#fff').msg, 'gang.already_in', 'al in gang')
    local b = addP(2, { bank = 100000 })
    Test.eq(Mock.callback('rp_gangs:create', 2, 'grove boys', '#fff').msg, 'gang.name_taken', 'naam al in gebruik (hoofdletterongevoelig)')
    Test.eq(b.accounts.bank, 100000, 'niets afgeschreven bij mislukken')
    local poor = addP(3, { bank = 10, money = 0 })
    Test.eq(Mock.callback('rp_gangs:create', 3, 'Armoe', '#fff').msg, 'gang.no_money', 'te weinig geld')
end)

Test.case('leden: uitnodigen, rechten per grade, kick/promote-grenzen', function()
    reset()
    addP(1, { bank = 100000, coords = at(0, 0) }); addP(2, { coords = at(1, 0) }); addP(3, { coords = at(2, 0) }); addP(4, { coords = at(60, 0) })
    local g = makeGang('Rood', 1, { 2, 3 })
    Test.eq(#Gang.onlineMembers(g.id), 3, 'drie leden online')
    bump()
    Test.eq(Mock.callback('rp_gangs:invite', 1, 4).msg, 'gang.too_far', 'uitnodigen te ver weg')
    bump()
    Mock.clientCallbacks['rp_gangs:confirmInvite'] = function() return false end
    Mock.players[4].coords = at(3, 0)
    Test.eq(Mock.callback('rp_gangs:invite', 1, 4).msg, 'gang.invite_declined', 'uitnodiging geweigerd')
    Mock.clientCallbacks['rp_gangs:confirmInvite'] = function() return true end

    -- rekruut (grade 0) heeft geen rechten
    bump()
    Test.eq(Mock.callback('rp_gangs:invite', 2, 4).msg, 'gang.no_permission', 'rekruut kan niet uitnodigen')
    local id2, id3 = Mock.xPlayers[2].identifier, Mock.xPlayers[3].identifier
    Test.eq(Mock.callback('rp_gangs:kick', 2, id3).msg, 'gang.no_permission', 'rekruut kan niet kicken')
    -- leider promoot: tot maximaal één onder zichzelf
    bump()
    Test.ok(Mock.callback('rp_gangs:setGrade', 1, id2, 3).ok, 'lid → grade 3')
    bump()
    Test.eq(Mock.callback('rp_gangs:setGrade', 1, id3, 4).msg, 'gang.grade_too_high', 'niemand tot leider verheffen')
    bump()
    -- grade 3 mag kicken (lager) maar niet de leider en niet gelijken
    local idLeader = Mock.xPlayers[1].identifier
    Test.eq(Mock.callback('rp_gangs:kick', 2, idLeader).msg, 'gang.grade_too_high', 'leider niet te kicken')
    bump()
    Test.eq(Mock.callback('rp_gangs:setGrade', 2, id3, 3).msg, 'gang.grade_too_high', 'niet tot eigen niveau promoveren')
    bump()
    Test.eq(Mock.callback('rp_gangs:setGrade', 2, idLeader, 0).msg, 'gang.grade_too_high', 'leider niet degraderen')
    bump()
    Test.ok(Mock.callback('rp_gangs:kick', 2, id3).ok, 'grade 3 kickt rekruut')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM rp_gang_members WHERE identifier = ?', { id3 }), 0, 'uit DB verwijderd')
    Test.eq(Mock.players[3].state.gangId, 0, 'state bag leeg')
    -- vol
    bump()
    local old = GangCfg.MaxMembers; GangCfg.MaxMembers = 2
    Test.eq(Mock.callback('rp_gangs:invite', 1, 3).msg, 'gang.full', 'gang vol')
    GangCfg.MaxMembers = old
    -- lid dat al in andere gang zit
    addP(5, { bank = 100000, coords = at(4, 0) }); makeGang('Blauw', 5, {})
    bump()
    Test.eq(Mock.callback('rp_gangs:invite', 1, 5).msg, 'gang.target_in_gang', 'zit al in gang')
end)

Test.case('gangkas: rechten en limieten; verlaten/opheffen', function()
    reset()
    local leader = addP(1, { bank = 100000, money = 50000 }); addP(2, { coords = at(1, 0), money = 1000 })
    local g = makeGang('Kas', 1, { 2 })
    bump()
    Test.eq(Mock.callback('rp_gangs:deposit', 2, 100).msg, 'gang.no_permission', 'rekruut kan niet storten')
    Test.ok(Mock.callback('rp_gangs:deposit', 1, 30000).ok, 'leider stort')
    Test.eq(g.bank, 30000, 'kas bijgewerkt'); Test.eq(DB.scalar('SELECT bank FROM rp_gangs WHERE id = ?', { g.id }), 30000, 'kas in DB')
    Test.eq(leader.money, 20000, 'contant afgeschreven')
    bump()
    Test.eq(Mock.callback('rp_gangs:deposit', 1, 999999).msg, 'gang.no_cash', 'meer dan contant')
    bump()
    Test.eq(Mock.callback('rp_gangs:withdraw', 2, 10).msg, 'gang.no_permission', 'rekruut kan niet opnemen')
    Test.eq(Mock.callback('rp_gangs:withdraw', 1, GangCfg.BankWithdrawMaxPerAction + 1).msg, 'gang.amount_invalid', 'opnamelimiet')
    bump()
    Test.ok(Mock.callback('rp_gangs:withdraw', 1, 5000).ok, 'opname')
    Test.eq(g.bank, 25000, 'kas na opname'); Test.eq(leader.money, 25000, 'contant erbij')
    bump()
    Test.eq(Mock.callback('rp_gangs:withdraw', 1, -1).msg, 'gang.amount_invalid', 'negatieve opname')
    g.bank = 1000; bump()
    Test.eq(Mock.callback('rp_gangs:withdraw', 1, 5000).msg, 'gang.bank_low', 'kas te laag')

    -- leider kan niet weg zolang er leden zijn
    Test.eq(Mock.callback('rp_gangs:leave', 1).msg, 'gang.leader_cannot_leave', 'leider blijft')
    Test.ok(Mock.callback('rp_gangs:leave', 2).ok, 'lid vertrekt')
    bump()
    Test.eq(Mock.callback('rp_gangs:disband', 2).msg, 'gang.no_permission', 'niet-lid kan niet opheffen')
    g.bank = 7000
    local bankBefore = leader.accounts.bank
    Test.ok(Mock.callback('rp_gangs:disband', 1).ok, 'opheffen')
    Test.eq(leader.accounts.bank, bankBefore + 7000, 'kas aan leider uitbetaald')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM rp_gangs'), 0, 'gang verwijderd')
end)

Test.case('territorium claimen: voorwaarden', function()
    reset()
    addP(1, { bank = 200000, coords = c3(GROVE.coords) }); addP(2, { coords = c3(GROVE.coords) })
    local g = makeGang('Claim', 1, {})
    g.bank = 100000
    bump()
    Test.eq(Mock.callback('rp_gangs:claim', 1, 'grove').msg, 'gang.need_online', 'te weinig leden online')
    Mock.callback('rp_gangs:invite', 1, 2); bump()
    Mock.players[1].coords = at(0, 0)
    Test.eq(Mock.callback('rp_gangs:claim', 1, 'grove').msg, 'gang.not_in_territory', 'buiten gebied')
    Mock.players[1].coords = c3(GROVE.coords); bump()
    Test.eq(Mock.callback('rp_gangs:claim', 2, 'grove').msg, 'gang.no_permission', 'rekruut kan niet claimen')
    local bank = g.bank
    local r = Mock.callback('rp_gangs:claim', 1, 'grove')
    Test.ok(r.ok, 'geclaimd')
    Test.eq(g.bank, bank - GangCfg.Territory.claimCost, 'claimkosten uit gangkas')
    Test.eq(Gang.territories.grove.gang_id, g.id, 'eigenaar')
    Test.eq(DB.scalar('SELECT gang_id FROM rp_gang_territories WHERE territory = ?', { 'grove' }), g.id, 'in DB')
    Test.ok(#Mock.eventsNamed('rp_gangs:territories') >= 1, 'clients bijgewerkt')
    bump()
    Test.eq(Mock.callback('rp_gangs:claim', 1, 'grove').msg, 'gang.territory_taken', 'al bezet')
    bump()
    Test.eq(Mock.callback('rp_gangs:claim', 1, 'nergens').msg, 'gang.no_permission', 'onbekend gebied')
end)

local function setupWar(killsToWin)
    reset()
    GangCfg.War.winKills = killsToWin or 3
    local ids = { 1, 2, 3, 4, 5, 6 }
    for _, i in ipairs(ids) do addP(i, { bank = 200000, coords = c3(GROVE.coords) }) end
    local A = makeGang('Aanvallers', 1, { 2, 3 }, '#ff0000')
    local B = makeGang('Verdedigers', 4, { 5, 6 }, '#0000ff')
    A.bank = 100000; B.bank = 100000
    Gang.territories.grove.gang_id = B.id; Gang.territories.grove.lockedUntil = 0
    for _, i in ipairs(ids) do Mock.players[i].coords = at(GROVE.coords.x + i, GROVE.coords.y, GROVE.coords.z) end
    return A, B
end

local function joinWar(srcs)
    for _, s in ipairs(srcs) do
        local r = Mock.callback('combat:join', s, 'war_grove')
        assert(r.ok, ('join oorlog mislukt voor %d: %s'):format(s, tostring(r.reason)))
        Mock.advance(1500)
    end
end

Test.case('ganggevecht: aanvaller wint → territorium verandert, zone alleen voor beide gangs', function()
    local A, B = setupWar(3)
    local bankA = A.bank
    bump()
    -- uitdagen: eigen gebied/onbezet/te weinig online
    Test.eq(Mock.callback('rp_gangs:declareWar', 2, 'grove').msg, 'gang.no_permission', 'rekruut kan geen oorlog verklaren')
    Mock.xPlayers[5].job = Mock.xPlayers[5].job; Mock.removePlayer(5); Mock.removePlayer(6); bump()
    Test.eq(Mock.callback('rp_gangs:declareWar', 1, 'grove').msg, 'gang.rival_offline', 'verdediger te weinig online')
    addP(5, { coords = at(GROVE.coords.x + 5, GROVE.coords.y, GROVE.coords.z) }); addP(6, { coords = at(GROVE.coords.x + 6, GROVE.coords.y, GROVE.coords.z) })
    bump()
    local r = Mock.callback('rp_gangs:declareWar', 1, 'grove')
    Test.ok(r.ok, 'oorlog verklaard')
    Test.eq(A.bank, bankA - GangCfg.War.cost, 'oorlogskosten')
    bump()
    Test.eq(Mock.callback('rp_gangs:declareWar', 1, 'grove').msg, 'gang.war_running', 'tweede oorlog om hetzelfde gebied')
    Test.no(Combat.Zones.war_grove, 'zone bestaat pas na voorbereiding')

    Mock.advance(GangCfg.War.prepareSeconds * 1000 + 1000); Mock.runTimeouts()
    local zone = Combat.Zones.war_grove
    Test.ok(zone and zone.temporary and zone.access, 'tijdelijke zone aangemaakt')
    Test.eq(zone.rewards, false, 'geen beloningen in oorlog')

    -- buitenstaander mag er niet in
    addP(9, { coords = at(GROVE.coords.x + 9, GROVE.coords.y, GROVE.coords.z) })
    Test.eq(Mock.callback('combat:join', 9, 'war_grove').reason, 'combat.no_access', 'buitenstaander geweigerd')
    joinWar({ 1, 2, 4, 5 })
    Test.eq(Combat.Players[1].team, 1, 'aanvaller = team 1'); Test.eq(Combat.Players[4].team, 2, 'verdediger = team 2')

    -- spawn-kill telt niet
    Mock.advance(CombatCfg.Rules.spawnProtectionSeconds * 1000 + 100)
    Combat.Players[4].spawnedAt = Combat.now() - 2000  -- slechts 2s geleefd
    Mock.fire('combat:died', 4, 1, 0)
    Test.eq(GangCfg and Gang.territories.grove.gang_id, B.id, 'nog van B')

    -- drie echte kills door aanvaller
    for i = 1, 3 do
        Mock.advance(30000)
        local victim = ({ 4, 5, 4 })[i]
        if not Combat.Players[victim].alive then Mock.callback('combat:respawn', victim); Mock.advance(CombatCfg.Rules.spawnProtectionSeconds * 1000 + 9000) end
        Combat.Players[victim].spawnedAt = Combat.now() - 20000
        Mock.fire('combat:died', victim, 1, 0)
    end
    Test.eq(Gang.territories.grove.gang_id, A.id, 'territorium veroverd door aanvaller')
    Test.eq(DB.scalar('SELECT gang_id FROM rp_gang_territories WHERE territory = ?', { 'grove' }), A.id, 'eigenaar in DB')
    Test.no(Combat.Zones.war_grove, 'zone opgeruimd')
    Test.ok(Combat.Players[1] == nil, 'deelnemers uit de zone gehaald')
    Test.eq(#DB.query('SELECT 1 FROM combat_stats WHERE kills > 0'), 0, 'oorlog telt niet mee in persoonlijke stats')
    Test.ok(Gang.territories.grove.lockedUntil > os.time(), 'gebied vergrendeld na oorlog')
    bump()
    Test.eq(Mock.callback('rp_gangs:declareWar', 4, 'grove').msg, 'gang.territory_locked', 'meteen terugwinnen kan niet')
end)

Test.case('ganggevecht: aanvaller te weinig kills → verdediger houdt gebied', function()
    local A, B = setupWar(15)
    Mock.callback('rp_gangs:declareWar', 1, 'grove')
    Mock.advance(GangCfg.War.prepareSeconds * 1000 + 1000); Mock.runTimeouts()
    Test.ok(Combat.Zones.war_grove, 'zone actief')
    joinWar({ 1, 4 })
    Mock.advance(30000)
    Combat.Players[4].spawnedAt = Combat.now() - 20000
    Mock.fire('combat:died', 4, 1, 0)             -- 1 kill < attackerMinKills (3)
    Mock.advance(GangCfg.War.durationSeconds * 1000 + 1000); Mock.runTimeouts()
    Test.eq(Gang.territories.grove.gang_id, B.id, 'verdediger houdt gebied')
    Test.no(Combat.Zones.war_grove, 'zone opgeruimd na tijd')
end)

Test.case('oorlog afgebroken voor start: kosten terug', function()
    local A, B = setupWar(3)
    local before = A.bank
    Mock.callback('rp_gangs:declareWar', 1, 'grove')
    Test.eq(A.bank, before - GangCfg.War.cost, 'kosten betaald')
    Mock.removePlayer(4); Mock.removePlayer(5); Mock.removePlayer(6)
    Mock.advance(GangCfg.War.prepareSeconds * 1000 + 1000); Mock.runTimeouts()
    Test.eq(A.bank, before, 'kosten terugbetaald')
    Test.no(Combat.Zones.war_grove, 'geen zone')
    Test.eq(Gang.territories.grove.gang_id, B.id, 'gebied ongewijzigd')
end)

Test.case('zwarte markt: alleen leden, gebied vereist, daglimiet, zwart geld', function()
    reset()
    local BM = GangCfg.BlackMarket
    local xp = addP(1, { bank = 200000, coords = c3(BM.coords) })
    xp.accounts.black_money = 50000
    local outsider = addP(2, { coords = c3(BM.coords) })
    outsider.accounts.black_money = 50000
    Test.eq(slow('rp_gangs:market:buy', 2, 'item', 'lockpick', 1).msg, 'gang.market_members_only', 'niet-lid')
    local g = makeGang('Markt', 1, {})
    bump()
    local info = slow('rp_gangs:market:info', 1)
    Test.ok(info.ok and #info.weapons == 2 and info.needTerritory, 'info')
    Test.ok(slow('rp_gangs:market:buy', 1, 'item', 'lockpick', 2).ok, 'item gekocht')
    Test.eq(xp.accounts.black_money, 50000 - 2 * 450, 'betaald met zwart geld')
    Test.eq(xp.inventory.lockpick, 2, 'item ontvangen')
    Mock.advance(BM.purchaseCooldownSeconds * 1000 + 1)
    Test.eq(slow('rp_gangs:market:buy', 1, 'weapon', 'WEAPON_PISTOL', 1).msg, 'gang.market_need_territory', 'wapens vereisen gebied')
    Gang.territories.grove.gang_id = g.id
    Mock.advance(BM.purchaseCooldownSeconds * 1000 + 1)
    Test.eq(slow('rp_gangs:market:buy', 1, 'item', 'lockpick', 20).msg, 'gang.market_daily', 'daglimiet items')
    Test.ok(slow('rp_gangs:market:buy', 1, 'weapon', 'WEAPON_PISTOL', 1).ok, 'wapen gekocht')
    Test.ok(xp.hasWeapon('WEAPON_PISTOL'), 'wapen in loadout')
    Mock.advance(BM.purchaseCooldownSeconds * 1000 + 1)
    Test.eq(slow('rp_gangs:market:buy', 1, 'weapon', 'WEAPON_PISTOL', 1).msg, 'gang.market_daily', 'daglimiet wapens')
    Mock.advance(BM.purchaseCooldownSeconds * 1000 + 1)
    Test.eq(slow('rp_gangs:market:buy', 1, 'weapon', 'WEAPON_RPG', 1).msg, 'gang.invalid', 'onbekend wapen')
    Mock.advance(BM.purchaseCooldownSeconds * 1000 + 1)
    Test.ok(slow('rp_gangs:market:buy', 1, 'item', 'lockpick', 1).ok, 'item gekocht')
    Test.eq(slow('rp_gangs:market:buy', 1, 'item', 'lockpick', 1).msg, 'gang.market_cooldown', 'aankoopcooldown')
    Test.eq(#Mock.logsOf('money') >= 1 and 1 or 0, 1, 'transacties gelogd')
    -- tijdens PvP
    Mock.advance(BM.purchaseCooldownSeconds * 1000 + 1)
    Mock.registry.combat_core.IsInCombat = function() return true end
    Test.eq(slow('rp_gangs:market:buy', 1, 'item', 'lockpick', 1).msg, 'gang.in_combat', 'niet tijdens PvP')
end)

Test.case('activiteit + hehler: te snel = verdacht, cooldown, daglimiet', function()
    reset()
    Mock.registry.combat_core = nil
    for _, f in ipairs({}) do end
    local act = GangCfg.Activities[1]
    local xp = addP(1, { coords = c3(act.coords) })
    local r = slow('rp_gangs:activity:start', 1, 'scrap')
    Test.ok(r.ok and r.seconds == act.seconds, 'start')
    Mock.advance(2000)
    Test.eq(slow('rp_gangs:activity:finish', 1, 'scrap').msg, 'gang.invalid', 'te snel klaar')
    Test.ok(#Mock.logsOf('suspicious') >= 1, 'verdacht gelogd')
    Test.eq(slow('rp_gangs:activity:finish', 1, 'scrap').msg, 'gang.invalid', 'niet zonder start')
    Mock.advance(3000)
    slow('rp_gangs:activity:start', 1, 'scrap')
    Mock.advance(act.seconds * 1000)
    local f = slow('rp_gangs:activity:finish', 1, 'scrap')
    Test.ok(f.ok, 'afgerond')
    Test.eq(xp.inventory.schroot, act.count, 'items ontvangen')
    Test.eq(slow('rp_gangs:activity:start', 1, 'scrap').msg, 'gang.activity_cooldown', 'cooldown')

    -- hehler
    Mock.players[1].coords = c3(GangCfg.Fence.coords)
    xp.inventory.schroot = 500
    local s = slow('rp_gangs:fence:sell', 1, 'schroot', 100)
    Test.ok(s.ok, 'verkocht')
    local cap = GangCfg.Fence.dailyAmountCap
    Test.eq(xp.accounts.black_money, cap, 'beperkt tot daglimiet')
    Test.eq(xp.inventory.schroot, 500 - cap / GangCfg.Fence.prices.schroot, 'alleen verkochte items afgenomen')
    Test.eq(slow('rp_gangs:fence:sell', 1, 'schroot', 5).msg, 'gang.fence_cap', 'dagcap bereikt')
    Test.eq(slow('rp_gangs:fence:sell', 1, 'lockpick', 1).msg, 'gang.invalid', 'hehler koopt dit niet')
    Test.eq(slow('rp_gangs:fence:sell', 1, 'schroot', -3).msg, 'gang.invalid', 'negatief aantal')
end)
