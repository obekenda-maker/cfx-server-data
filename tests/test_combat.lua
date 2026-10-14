-- Tests voor combat_core + combat_stats (server-logica)
Mock.loadCore()
Mock.load('combat_stats', 'resources/[combat]/combat_stats/config.lua')
Mock.load('combat_stats', 'resources/[combat]/combat_stats/server/main.lua')
Mock.load('combat_core', 'resources/[combat]/combat_core/config.lua')
Mock.load('combat_core', 'resources/[combat]/combat_core/shared/util.lua')
for _, f in ipairs({ 'zones', 'rules', 'rewards', 'damage', 'main' }) do
    Mock.load('combat_core', 'resources/[combat]/combat_core/server/' .. f .. '.lua')
end

local HAVEN = CombatCfg.Zones[1].coords      -- FFA
local AIR   = CombatCfg.Zones[2].coords      -- team
local function inside(zoneCoords, dx) return { x = zoneCoords.x + (dx or 5.0), y = zoneCoords.y, z = zoneCoords.z } end

local function reset()
    Mock.events, Mock.logs = {}, {}
    local srcs = {}
    for src in pairs(Mock.xPlayers) do srcs[#srcs + 1] = src end
    for _, src in ipairs(srcs) do Mock.removePlayer(src) end
    DB.exec('DELETE FROM combat_stats')
    DB.exec('DELETE FROM combat_kill_log')
    for k in pairs(Combat.Players) do Combat.Players[k] = nil end
    Combat.Cooldowns = {}
    for id in pairs(Combat.Scores) do Combat.Scores[id] = {} end
    Mock.advance(300000)
end

local function setup(src, opts)
    opts = opts or {}
    local xp = Mock.addPlayer(src, { coords = opts.coords or inside(HAVEN, src), job = opts.job, money = opts.money, bank = opts.bank, loadout = opts.loadout, name = opts.name })
    TriggerEvent('esx:playerLoaded', src, xp, false)
    return xp
end

local function join(src, zone, lo)
    local r = Mock.callback('combat:join', src, zone or 'haven', lo)
    return r
end

-- start: ingebouwde thread laadt zones + stats DB-check
Mock.stepThreads()

Test.case('zones geladen', function()
    Test.eq(#Combat.ZoneOrder, 3, 'aantal zones')
    Test.ok(Combat.Zones.haven and Combat.Zones.vliegveld and Combat.Zones.steengroeve, 'zone ids')
    Test.eq(Combat.Zones.vliegveld.mode, 'team', 'teammodus')
end)

Test.case('deelnemen: buiten zone geweigerd, binnen toegestaan', function()
    reset()
    setup(1, { coords = { x = 0.0, y = 0.0, z = 30.0 } })
    local r = join(1)
    Test.no(r.ok, 'buiten zone')
    Test.eq(r.reason, 'combat.not_in_zone', 'reden buiten zone')
    Mock.players[1].coords = inside(HAVEN)
    Mock.advance(2000)
    r = join(1)
    Test.ok(r.ok, 'binnen zone')
    Test.ok(Combat.Players[1] ~= nil, 'speler geregistreerd')
    Test.eq(Mock.players[1].state.inCombat, true, 'state bag inCombat')
    Test.eq(r.data.loadout.key, 'standaard', 'standaard loadout')
    Test.ok(r.data.spawn and r.data.spawn.x, 'spawn aanwezig')
    -- spawn ligt binnen de zone
    Test.ok(CombatUtil.dist2d(r.data.spawn, HAVEN) <= CombatCfg.Zones[1].radius, 'spawn binnen straal')
    -- tweede keer joinen kan niet
    Mock.advance(2000)
    Test.eq(join(1).reason, 'combat.already_joined', 'dubbel joinen')
end)

Test.case('jobregels: politie geweigerd, af-dienst toegestaan', function()
    reset()
    setup(1, { job = 'police' })
    Test.eq(join(1).reason, 'combat.job_blocked_duty', 'politie op dienst')
    Mock.advance(2000)
    setup(2, { job = 'offpolice' })
    Test.ok(join(2).ok, 'af dienst mag meedoen')
    -- jobwissel tijdens PvP: naar politie → direct eruit
    Mock.xPlayers[2].setJob('police', 1)
    Test.ok(Combat.Players[2] == nil, 'verwijderd na jobwissel')
    Test.eq(Mock.eventsNamed('combat:left', 2)[1].args[1], 'combat.left_job', 'reden jobwissel')
end)

Test.case('entreegeld wordt afgeschreven en gelogd; te weinig geld = geweigerd', function()
    reset()
    local xp = setup(1, { money = 50, coords = inside(CombatCfg.Zones[3].coords) })
    local r = join(1, 'steengroeve')
    Test.eq(r.reason, 'combat.no_money', 'te weinig geld')
    Test.eq(xp.money, 50, 'geen afschrijving bij weigering')
    xp.money = 500
    Mock.advance(2000)
    r = join(1, 'steengroeve')
    Test.ok(r.ok, 'join met geld')
    Test.eq(xp.money, 400, 'entree afgeschreven')
    Test.ok(#Mock.logsOf('money') >= 1, 'geldlog')
end)

Test.case('kill: beloning, stats, killfeed, serie', function()
    reset()
    local a, b = setup(1), setup(2)
    join(1); Mock.advance(2000); join(2)
    Mock.advance(CombatCfg.Rules.spawnProtectionSeconds * 1000 + CombatCfg.Rewards.minAliveSeconds * 1000 + 1000)
    Mock.fire('combat:died', 2, 1, joaat('WEAPON_CARBINERIFLE'))
    Test.eq(Combat.Players[1].kills, 1, 'kills killer')
    Test.eq(Combat.Players[2].deaths, 1, 'deaths slachtoffer')
    Test.eq(a.accounts.bank, 5000 + CombatCfg.Rewards.killMoney * 1.0, 'bankbeloning')
    local st = exports.combat_stats:Get(1)
    Test.eq(st.kills, 1, 'stats kills')
    Test.eq(st.xp, CombatCfg.Rewards.killXp, 'stats xp')
    Test.eq(exports.combat_stats:Get(2).deaths, 1, 'stats deaths')
    Test.eq(exports.combat_stats:GetEarnedToday(1), CombatCfg.Rewards.killMoney, 'dagcap teller')
    local feed = Mock.eventsNamed('combat:killfeed', 1)[1]
    Test.ok(feed, 'killfeed event')
    Test.eq(feed.args[1].weapon, 'Karabijn', 'NL wapenlabel')
    Test.eq(feed.args[1].killer, 'Speler1', 'killfeed killer')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM combat_kill_log'), 1, 'kill gelogd in DB')
end)

Test.case('anti-farm: zelfde paar binnen cooldown = geen beloning/stat; daarna wel', function()
    reset()
    local a = setup(1); setup(2)
    join(1); Mock.advance(2000); join(2)
    Mock.advance(20000)
    Mock.fire('combat:died', 2, 1, 0)                   -- 1e kill: beloond
    local bank1 = a.accounts.bank
    Mock.callback('combat:respawn', 2)                  -- te vroeg
    Mock.advance(6000)
    local rs = Mock.callback('combat:respawn', 2)
    Test.ok(rs.ok, 'respawn na timer')
    Mock.advance(20000)                                 -- beschermtijd + levenstijd voorbij
    Mock.fire('combat:died', 2, 1, 0)                   -- 2e kill binnen 120 s: geen beloning
    Test.eq(a.accounts.bank, bank1, 'geen tweede beloning')
    Test.eq(Combat.Players[1].kills, 2, 'score telt wel')
    Test.eq(exports.combat_stats:Get(1).kills, 1, 'persistente stat telt niet mee')
    Mock.advance(CombatCfg.Rewards.pairCooldownSeconds * 1000 + 6000)
    Mock.callback('combat:respawn', 2); Mock.advance(20000)
    Mock.fire('combat:died', 2, 1, 0)
    Test.ok(a.accounts.bank > bank1, 'na cooldown weer beloning')
end)

Test.case('beschermd slachtoffer: kill afgewezen + suspicious-log', function()
    reset()
    setup(1); setup(2)
    join(1); Mock.advance(2000); join(2)
    -- slachtoffer net gejoind: nog beschermd
    Mock.fire('combat:died', 2, 1, 0)
    Test.eq(Combat.Players[1].kills, 0, 'geen kill')
    Test.eq(Combat.Players[2].deaths, 1, 'death telt wel')
    Test.ok(#Mock.logsOf('suspicious') >= 1, 'suspicious log')
end)

Test.case('client liegt: killer niet in zone / andere zone / te ver / dood', function()
    reset()
    setup(1); setup(2); setup(3, { coords = { x = 0.0, y = 0.0, z = 30.0 } })
    join(1); Mock.advance(2000); join(2)
    Mock.advance(30000)
    Mock.fire('combat:died', 2, 3, 0)          -- 3 doet niet mee
    Test.eq(Combat.Players[1].kills, 0, 'niet-deelnemer krijgt geen kill')
    Combat.Players[2].alive = true; Combat.Players[2].deaths = 0
    -- te ver
    Mock.players[1].coords = { x = HAVEN.x + 100.0, y = HAVEN.y, z = HAVEN.z }
    local save = CombatCfg.Rules.maxKillDistance
    CombatCfg.Rules.maxKillDistance = 20.0
    Mock.advance(3000)
    Mock.fire('combat:died', 2, 1, 0)
    Test.eq(Combat.Players[1].kills, 0, 'te grote afstand')
    CombatCfg.Rules.maxKillDistance = save
    -- niet-numerieke input wordt genegeerd
    Combat.Players[2].alive = true
    Mock.advance(3000)
    Mock.fire('combat:died', 2, 'hack', {})
    Test.ok(Combat.Players[2].alive, 'ongeldige types genegeerd')
end)

Test.case('dagcap en uurbudget begrenzen combatgeld', function()
    reset()
    local a = setup(1); setup(2)
    local R = CombatCfg.Rewards
    local oldCap, oldBudget = R.dailyMoneyCap, R.globalHourlyBudget
    R.dailyMoneyCap = 150
    join(1); Mock.advance(2000); join(2)
    Mock.advance(30000)
    Mock.fire('combat:died', 2, 1, 0)
    Test.eq(a.accounts.bank, 5100, 'eerste kill 100')
    Mock.advance(7000); Mock.callback('combat:respawn', 2); Mock.advance(CombatCfg.Rewards.pairCooldownSeconds * 1000 + 20000)
    Mock.fire('combat:died', 2, 1, 0)
    Test.eq(a.accounts.bank, 5150, 'tweede kill gekapt op daglimiet (+50)')
    Mock.advance(7000); Mock.callback('combat:respawn', 2); Mock.advance(CombatCfg.Rewards.pairCooldownSeconds * 1000 + 20000)
    Mock.fire('combat:died', 2, 1, 0)
    Test.eq(a.accounts.bank, 5150, 'derde kill: niets meer')
    Test.eq(exports.combat_stats:Get(1).kills, 3, 'stats tellen wel')
    R.dailyMoneyCap = oldCap

    -- globaal uurbudget
    reset()
    local c = setup(5, { coords = inside(HAVEN, 9) }); setup(6, { coords = inside(HAVEN, 10) })
    R.globalHourlyBudget = Combat.budgetUsed() + 100
    join(5); Mock.advance(2000); join(6)
    Mock.advance(30000)
    Mock.fire('combat:died', 6, 5, 0)
    Test.eq(c.accounts.bank, 5100, 'binnen budget')
    Mock.advance(7000); Mock.callback('combat:respawn', 6); Mock.advance(CombatCfg.Rewards.pairCooldownSeconds * 1000 + 20000)
    Mock.fire('combat:died', 6, 5, 0)
    Test.eq(c.accounts.bank, 5100, 'budget op: geen geld')
    R.globalHourlyBudget = oldBudget
end)

Test.case('teamzone: auto-balans, teamkill geweigerd, ronde-einde met bonus', function()
    reset()
    local air = CombatCfg.Zones[2]
    local xs = {}
    for i = 1, 4 do xs[i] = setup(i, { coords = inside(AIR, i) }); Mock.advance(1500); Test.ok(join(i, 'vliegveld').ok, 'join team ' .. i) end
    local t1, t2 = 0, 0
    for i = 1, 4 do if Combat.Players[i].team == 1 then t1 = t1 + 1 else t2 = t2 + 1 end end
    Test.eq(t1, 2, 'team 1 grootte'); Test.eq(t2, 2, 'team 2 grootte')
    Mock.advance(30000)
    -- zoek twee teamgenoten
    local mate
    for i = 2, 4 do if Combat.Players[i].team == Combat.Players[1].team then mate = i end end
    Mock.fire('combat:died', mate, 1, 0)
    Test.eq(Combat.Players[1].kills, 0, 'teamkill telt niet')
    Combat.Players[mate].alive = true
    -- ronde winnen
    Combat.Zones.vliegveld.scoreLimit = 2
    local enemy
    for i = 2, 4 do if Combat.Players[i].team ~= Combat.Players[1].team then enemy = i end end
    local bankBefore = Mock.xPlayers[1].accounts.bank
    Combat.Scores.vliegveld[Combat.Players[1].team] = 1
    Mock.advance(4000)
    Mock.fire('combat:died', enemy, 1, 0)
    Test.eq(Combat.Scores.vliegveld[Combat.Players[1].team], nil, 'scores gereset na ronde')
    Test.ok(Mock.xPlayers[1].accounts.bank >= bankBefore + CombatCfg.Rewards.teamWinBonus, 'teambonus uitgekeerd')
    Combat.Zones.vliegveld.scoreLimit = air.scoreLimit
end)

Test.case('respawn: wachttijd, rate-limit, nieuwe bescherming', function()
    reset()
    setup(1); setup(2)
    join(1); Mock.advance(2000); join(2)
    Mock.advance(30000)
    Mock.fire('combat:died', 2, 1, 0)
    local r = Mock.callback('combat:respawn', 2)
    Test.eq(r.reason, 'combat.respawn_wait', 'te vroeg')
    Mock.advance(CombatCfg.Rules.respawnSeconds * 1000)
    r = Mock.callback('combat:respawn', 2)
    Test.ok(r.ok, 'respawn mag')
    Test.ok(r.data.protection > 0, 'beschermtijd')
    Test.ok(Combat.Players[2].protectedUntil > Combat.now(), 'server kent bescherming')
    -- levende speler kan niet respawnen
    Mock.advance(1000)
    Test.eq(Mock.callback('combat:respawn', 2).reason, 'combat.not_dead', 'levend')
    -- rate limit
    local limit = CombatCfg.Rules.respawnMaxPerMinute
    local denied = false
    for i = 1, limit + 2 do
        Combat.Players[2].alive = false; Combat.Players[2].diedAt = Combat.now() - 10000
        Mock.advance(900)
        local rr = Mock.callback('combat:respawn', 2)
        if not rr.ok and rr.reason == 'combat.respawn_limit' then denied = true end
    end
    Test.ok(denied, 'respawn-limiet werkt')
end)

Test.case('verlaten: combat-tag, handmatig, buiten zone-tick, disconnect', function()
    reset()
    setup(1); setup(2)
    join(1); Mock.advance(2000); join(2)
    Mock.advance(30000)
    Combat.Players[1].lastDamageAt = Combat.now()
    local r = Mock.callback('combat:leave', 1)
    Test.eq(r.reason, 'combat.tagged', 'gevecht-tag blokkeert')
    Mock.advance(CombatCfg.Rules.combatTagSeconds * 1000 + 1)
    r = Mock.callback('combat:leave', 1)
    Test.ok(r.ok, 'verlaten na tag')
    Test.ok(Combat.Players[1] == nil, 'verwijderd')
    Test.eq(Mock.players[1].state.inCombat, false, 'state bag uit')
    Test.eq(#Mock.eventsNamed('combat:left', 1), 1, 'combat:left verstuurd')
    -- cooldown voor opnieuw joinen
    Test.eq(join(1).reason, 'combat.cooldown', 'join-cooldown')
    -- buiten zone → na N ticks eruit
    Mock.players[2].coords = { x = HAVEN.x + 500.0, y = HAVEN.y, z = HAVEN.z }
    for _ = 1, CombatCfg.Rules.leaveConfirmTicks - 1 do Combat.tick() end
    Test.ok(Combat.Players[2] ~= nil, 'nog niet verwijderd')
    Combat.tick()
    Test.ok(Combat.Players[2] == nil, 'verwijderd na grensovertreding')
    Test.eq(Mock.eventsNamed('combat:left', 2)[1].args[1], 'combat.left_outside', 'reden buiten zone')
    -- disconnect
    Mock.players[1].coords = inside(HAVEN); Mock.advance(10000)
    join(1)
    Mock.removePlayer(1)
    Test.ok(Combat.Players[1] == nil, 'verwijderd bij disconnect')
end)

Test.case('RP-loadout: snapshot, handhaving ammo, herstel payload', function()
    reset()
    local rp = { { name = 'WEAPON_COMBATPISTOL', ammo = 30, components = { 'COMPONENT_AT_PI_FLSH' } }, { name = 'WEAPON_BAT', ammo = 1 } }
    local xp = setup(1, { loadout = rp })
    join(1)
    local p = Combat.Players[1]
    Test.eq(#p.rpLoadout, 2, 'snapshot bevat beide wapens')
    Test.eq(#p.rpOverlap, 1, 'alleen overlappende wapens (combat pistool) worden bewaakt')
    -- ESX 'update' munitie met combatwaarde (zoals esx:updateWeaponAmmo zou doen)
    xp.updateWeaponAmmo('WEAPON_COMBATPISTOL', 99)
    Combat.tick()
    Test.eq(xp.loadout[1].ammo, 30, 'RP-munitie hersteld door tick')
    xp.updateWeaponAmmo('WEAPON_COMBATPISTOL', 77)
    Mock.advance(30000)
    Combat.leave(1, 'combat.left')
    Test.eq(xp.loadout[1].ammo, 30, 'RP-munitie hersteld bij verlaten')
    local left = Mock.eventsNamed('combat:left', 1)[1]
    Test.eq(left.args[2][1].name, 'WEAPON_COMBATPISTOL', 'herstelpayload naar client')
    Test.eq(left.args[2][1].components[1], 'COMPONENT_AT_PI_FLSH', 'componenten mee')
    -- audit: combatwapen blijft hangen
    Mock.players[1].selectedWeapon = joaat('WEAPON_CARBINERIFLE')
    Mock.advance(5000); Mock.runTimeouts()
    Test.eq(Mock.players[1].removedWeapon, joaat('WEAPON_CARBINERIFLE'), 'audit verwijdert combatwapen')
    Test.ok(#Mock.logsOf('suspicious') >= 1, 'audit gelogd')
end)

Test.case('schaderegels (weaponDamageEvent-logica)', function()
    reset()
    setup(1); setup(2); setup(3, { coords = { x = 0.0, y = 0.0, z = 30.0 } }); setup(4, { coords = { x = 10.0, y = 0.0, z = 30.0 } })
    join(1); Mock.advance(2000); join(2)
    Mock.advance(30000)
    Test.ok(Combat.evaluateDamage(1, 2), 'deelnemers onderling')
    Test.eq(Combat.Players[2].lastDamageBy, 1, 'laatste schade onthouden')
    Test.no(Combat.evaluateDamage(1, 3), 'deelnemer → niet-deelnemer geblokkeerd')
    Test.no(Combat.evaluateDamage(3, 1), 'niet-deelnemer → deelnemer geblokkeerd')
    Test.ok(Combat.evaluateDamage(3, 4), 'buiten zones normaal (mode rp)')
    CombatCfg.Outside.mode = 'disabled'
    Test.no(Combat.evaluateDamage(3, 4), 'buiten zones uit (mode disabled)')
    CombatCfg.Outside.mode = 'rp'
    Combat.Players[2].protectedUntil = Combat.now() + 5000
    Test.no(Combat.evaluateDamage(1, 2), 'beschermd slachtoffer')
    -- bescherming vervalt als je zelf schiet
    Combat.Players[1].protectedUntil = Combat.now() + 5000
    Combat.Players[2].protectedUntil = 0
    Combat.evaluateDamage(1, 2)
    Test.ok(Combat.Players[1].protectedUntil <= Combat.now(), 'bescherming gebroken bij schieten')
end)

Test.case('strictDamageCheck: kill zonder geziene schade wordt afgewezen', function()
    reset()
    setup(1); setup(2)
    join(1); Mock.advance(2000); join(2)
    Mock.advance(30000)
    CombatCfg.Rules.strictDamageCheck = true
    Mock.fire('combat:died', 2, 1, 0)
    Test.eq(Combat.Players[1].kills, 0, 'geen schade gezien → geen kill')
    Combat.Players[2].alive = true
    Combat.evaluateDamage(1, 2)
    Mock.advance(3000)
    Mock.fire('combat:died', 2, 1, 0)
    Test.eq(Combat.Players[1].kills, 1, 'met geziene schade → kill')
    CombatCfg.Rules.strictDamageCheck = false
end)

Test.case('tijdelijke zone met toegang (ganggevecht) via export', function()
    reset()
    Mock.registry.rp_gangs = { GetGangId = function(src) return ({ [1] = 10, [2] = 20, [3] = 30 })[src] end }
    setup(1); setup(2); setup(3)
    local ok = exports.combat_core:CreateTemporaryZone({
        id = 'war_test', label = 'Test oorlog', coords = { x = HAVEN.x, y = HAVEN.y, z = HAVEN.z }, radius = 80.0,
        mode = 'team', access = { gangs = { 10, 20 } }, rewards = false, countStats = false, durationSeconds = 600,
        teams = { { id = 1, label = 'Gang A', color = '#ff0000' }, { id = 2, label = 'Gang B', color = '#0000ff' } },
    })
    Test.ok(ok, 'zone aangemaakt')
    Test.eq(#Mock.eventsNamed('combat:zoneAdd'), 2, 'alleen leden krijgen de zone')
    Test.eq(join(3, 'war_test').reason, 'combat.no_access', 'buitenstaander geweigerd')
    Mock.advance(2000)
    local r1 = join(1, 'war_test'); Mock.advance(2000); local r2 = join(2, 'war_test')
    Test.ok(r1.ok and r2.ok, 'leden mogen')
    Test.eq(Combat.Players[1].team, 1, 'gang A = team 1')
    Test.eq(Combat.Players[2].team, 2, 'gang B = team 2')
    -- geen beloning, geen stat
    local bank = Mock.xPlayers[1].accounts.bank
    Mock.advance(30000)
    local killEvents = 0
    AddEventHandler('combat:kill', function(d) killEvents = killEvents + 1 end)
    Mock.fire('combat:died', 2, 1, 0)
    Test.eq(Mock.xPlayers[1].accounts.bank, bank, 'oorlog geeft geen geld')
    Test.eq(killEvents, 1, 'combat:kill event voor rp_gangs')
    Test.eq(Combat.Scores.war_test[1], 1, 'score van gang A')
    Test.ok(exports.combat_core:RemoveTemporaryZone('war_test'), 'zone verwijderd')
    Test.ok(Combat.Players[1] == nil, 'deelnemers verwijderd')
    Test.eq(#Mock.eventsNamed('combat:zoneRemove'), 1, 'clients ingelicht')
end)

Test.case('stats: flush naar DB + leaderboard + level', function()
    reset()
    setup(1, { name = 'Alfa' }); setup(2, { name = 'Beta' })
    exports.combat_stats:RecordKill(1, 400, 3)
    exports.combat_stats:RecordKill(1, 0, 4)
    exports.combat_stats:RecordDeath(2)
    Test.eq(exports.combat_stats:Get(1).level, 3, 'level uit XP (400 → 3)')
    Test.eq(exports.combat_stats:Get(1).best_streak, 4, 'beste serie')
    local board = exports.combat_stats:GetLeaderboard(5, 'kills')
    Test.eq(board[1].name, 'Alfa', 'leaderboard #1')
    Test.eq(DB.scalar('SELECT kills FROM combat_stats WHERE identifier = ?', { 'license:lic1' }), 2, 'gespoeld naar DB voor leaderboard')
    Test.eq(exports.combat_stats:Get(2).kd, 0.0, 'kd zonder kills')
end)

Test.case('item-gebruik check via export', function()
    reset()
    setup(1); Mock.advance(2000); join(1)
    Test.ok(exports.combat_core:IsInCombat(1), 'IsInCombat')
    Test.no(exports.combat_core:IsInCombat(99), 'niet in combat')
end)
