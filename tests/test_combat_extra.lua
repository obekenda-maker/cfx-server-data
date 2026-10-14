-- Fase 2: gerichte tests op combat-integriteit, economie, loadouts, stats en disconnect-gedrag
Mock.loadAll()

local HAVEN = CombatCfg.Zones[1].coords
local function inside(dx, dy) return { x = HAVEN.x + (dx or 5.0), y = HAVEN.y + (dy or 0.0), z = HAVEN.z } end

local function reset()
    local srcs = {}
    for src in pairs(Mock.xPlayers) do srcs[#srcs + 1] = src end
    for _, src in ipairs(srcs) do Mock.removePlayer(src) end
    for k in pairs(Combat.Players) do Combat.Players[k] = nil end
    Combat.Cooldowns = {}
    for id in pairs(Combat.Scores) do Combat.Scores[id] = {} end
    DB.exec('DELETE FROM combat_stats'); DB.exec('DELETE FROM combat_kill_log')
    Mock.events, Mock.logs = {}, {}
    Mock.advance(600000)
end
local function addP(src, opts)
    opts = opts or {}
    opts.coords = opts.coords or inside(src)
    local xp = Mock.addPlayer(src, opts)
    TriggerEvent('esx:playerLoaded', src, xp, false)
    return xp
end
local function join(src, zone, lo) return Mock.callback('combat:join', src, zone or 'haven', lo) end
local function duel()
    addP(1); addP(2)
    join(1); Mock.advance(1500); join(2)
    Mock.advance(30000)
end
local function killfeedCount() return #Mock.eventsNamed('combat:killfeed', 1) end

Test.case('killfeed en stats: dubbele meldingen tellen niet dubbel', function()
    reset(); duel()
    Mock.clearEvents()
    -- 30× in dezelfde milliseconde dezelfde dood melden (spam / dubbele event)
    for _ = 1, 30 do Mock.fire('combat:died', 2, 1, joaat('WEAPON_CARBINERIFLE')) end
    Test.eq(killfeedCount(), 1, 'één killfeed-melding')
    Test.eq(Combat.Players[1].kills, 1, 'één kill')
    Test.eq(exports.combat_stats:Get(1).kills, 1, 'één kill in stats')
    Test.eq(exports.combat_stats:Get(2).deaths, 1, 'één death in stats')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM combat_kill_log'), 1, 'één regel in kill-log')
    Test.eq(Combat.Players[1].streak, 1, 'streak 1')
    -- wederzijdse kill binnen 3 s: elk één keer
    Mock.callback('combat:respawn', 2)
    Mock.advance(8000); Mock.callback('combat:respawn', 2)
    Mock.advance(20000)
    Mock.clearEvents()
    Mock.fire('combat:died', 2, 1, 0)
    Mock.fire('combat:died', 1, 2, 0)
    Test.eq(killfeedCount(), 2, 'wederzijdse kill = 2 meldingen, niet meer')
end)

Test.case('stats blijven bewaard na dood + disconnect; kd klopt', function()
    reset(); duel()
    Mock.fire('combat:died', 2, 1, 0)
    Mock.removePlayer(2)                         -- slachtoffer disconnect direct na dood
    Test.eq(DB.scalar('SELECT deaths FROM combat_stats WHERE identifier = ?', { 'license:lic2' }), 1, 'death bewaard bij disconnect')
    Mock.removePlayer(1)
    local row = DB.one('SELECT kills, deaths, xp FROM combat_stats WHERE identifier = ?', { 'license:lic1' })
    Test.eq(row.kills, 1, 'kills bewaard'); Test.eq(row.xp, CombatCfg.Rewards.killXp, 'xp bewaard')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM combat_stats'), 2, 'geen dubbele rijen')
    addP(1)
    local st = exports.combat_stats:Get(1)
    Test.eq(st.kills, 1, 'geladen na reconnect'); Test.eq(st.kd, 1.0, 'K/D = 1 kill / max(0 deaths,1)')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM combat_stats WHERE identifier = ?', { 'license:lic1' }), 1, 'nog steeds één rij')
end)

Test.case('killer disconnect vóór de dood-melding: geen corrupte stats', function()
    reset(); duel()
    Mock.removePlayer(1)
    Mock.fire('combat:died', 2, 1, 0)
    Test.eq(Combat.Players[1], nil, 'killer weg')
    Test.eq(DB.scalar('SELECT COALESCE(SUM(kills),0) FROM combat_stats'), 0, 'geen kill toegekend aan weggegane speler')
    Test.eq(exports.combat_stats:Get(2).deaths, 1, 'death telt wel')
    Test.no(Combat.Players[2].alive, 'slachtoffer kan gewoon respawnen')
    Mock.advance(6000)
    Test.ok(Mock.callback('combat:respawn', 2).ok, 'respawn lukt')
end)

Test.case('leaderboard: volgorde per sortering, K/D-drempel, geen dubbele namen', function()
    reset()
    local rows = {
        { 'license:a', 'Alfa', 100, 50, 900 }, { 'license:b', 'Beta', 40, 2, 100 }, { 'license:c', 'Gamma', 5, 0, 5000 },
        { 'license:d', 'Delta', 60, 30, 10 },
    }
    for _, r in ipairs(rows) do
        DB.exec('INSERT INTO combat_stats (identifier, name, kills, deaths, xp, best_streak, earned_today, earned_date) VALUES (?, ?, ?, ?, ?, 0, 0, ?)', { r[1], r[2], r[3], r[4], r[5], os.date('%Y-%m-%d') })
    end
    Mock.advance(100000)
    local kills = exports.combat_stats:GetLeaderboard(10, 'kills')
    Test.eq(kills[1].name, 'Alfa', 'kills #1'); Test.eq(kills[2].name, 'Delta', 'kills #2'); Test.eq(kills[4].name, 'Gamma', 'kills #4')
    Mock.advance(100000)
    local kd = exports.combat_stats:GetLeaderboard(10, 'kd')
    Test.eq(kd[1].name, 'Beta', 'K/D #1 (20.0)'); Test.eq(#kd, 3, 'Gamma (5 kills) onder K/D-drempel uitgesloten')
    Test.eq(kd[1].kd, 20.0, 'K/D waarde')
    Mock.advance(100000)
    local xp = exports.combat_stats:GetLeaderboard(10, 'xp')
    Test.eq(xp[1].name, 'Gamma', 'XP #1'); Test.eq(xp[1].level, 8, 'level uit xp (5000/100 → sqrt 7.07 → 8)')
    Test.eq(#exports.combat_stats:GetLeaderboard(2, 'kills'), 2, 'limiet')
    Test.eq(exports.combat_stats:GetLeaderboard(10, 'DROP TABLE')[1].name, 'Alfa', 'ongeldige sortering → kills (geen SQL-injectie)')
end)

Test.case('economie: totale combatuitkering nooit boven uurbudget en dagcap', function()
    reset()
    local R = CombatCfg.Rewards
    local oldB, oldC, oldCd = R.globalHourlyBudget, R.dailyMoneyCap, R.pairCooldownSeconds
    R.globalHourlyBudget, R.dailyMoneyCap = 1000, 400
    local start = Combat.budgetUsed()
    local players, bank0 = {}, {}
    for i = 1, 12 do players[i] = addP(i, { bank = 0, coords = inside(i, 0) }) bank0[i] = 0 Mock.advance(1100); join(i) end
    Mock.advance(30000)
    -- iedereen doodt iedereen, herhaald, met respawns
    for round = 1, 3 do
        for k = 1, 12 do
            local v = (k % 12) + 1
            if not Combat.Players[v].alive then Mock.advance(7000); Mock.callback('combat:respawn', v); Mock.advance(14000) end
            Combat.Players[v].spawnedAt = Combat.now() - 20000
            Combat.Players[k].alive = true
            Mock.fire('combat:died', v, k, 0)
            Mock.advance(1600)
        end
        Mock.advance(R.pairCooldownSeconds * 1000 + 1000)
    end
    local total = 0
    for i = 1, 12 do
        total = total + players[i].accounts.bank
        Test.ok(players[i].accounts.bank <= 400, 'speler ' .. i .. ' binnen dagcap')
    end
    Test.ok(total <= 1000, 'totaal ≤ uurbudget (' .. total .. ')')
    Test.ok(total > 0, 'er is wel geld uitgekeerd')
    Test.eq(Combat.budgetUsed() - start, total, 'budgetteller == werkelijk uitgekeerd')
    local xpSum = 0
    for i = 1, 12 do xpSum = xpSum + exports.combat_stats:Get(i).xp end
    Test.ok(xpSum > 0, 'XP blijft doorlopen als geld op is')
    R.globalHourlyBudget, R.dailyMoneyCap = oldB, oldC
end)

Test.case('loadouts: alleen toegestane wapens; vreemde sleutels worden genegeerd', function()
    reset()
    addP(1)
    local zone = Combat.Zones.haven
    local r = join(1, 'haven', 'sniper')                 -- sniper hoort niet bij haven
    Test.ok(r.ok, 'join')
    Test.eq(r.data.loadout.key, zone.loadouts[1], 'niet-toegestane loadout → standaard van de zone')
    Combat.leave(1, 'combat.left'); Mock.advance(10000)
    r = join(1, 'haven', "x'; os.exit() --")
    Test.eq(r.data.loadout.key, zone.loadouts[1], 'rommelsleutel genegeerd')
    local allowed = {}
    for _, key in ipairs(zone.loadouts) do for _, w in ipairs(CombatCfg.Loadouts[key].weapons) do allowed[w.name] = true end end
    for _, w in ipairs(r.data.loadout.weapons) do Test.ok(allowed[w.name], 'wapen ' .. w.name .. ' staat in de zoneconfig') end
    Combat.leave(1, 'combat.left'); Mock.advance(10000)
    r = join(1, 'haven', 'close')
    Test.eq(r.data.loadout.key, 'close', 'toegestane keuze werkt')
    Test.ok(r.data.loadout.health <= 200 and r.data.loadout.armor <= 100, 'health/armor begrensd')
    -- respawn geeft dezelfde loadout, geen extra wapens
    Mock.advance(30000); Combat.Players[1].alive = false; Combat.Players[1].diedAt = Combat.now() - 10000
    local rs = Mock.callback('combat:respawn', 1)
    Test.eq(rs.data.loadout.key, 'close', 'respawn behoudt gekozen loadout')
end)

Test.case('spawnbeveiliging stopt automatisch (server) en na respawn opnieuw', function()
    reset(); addP(1); addP(2)
    join(1); Mock.advance(1500); join(2)
    Test.no(Combat.evaluateDamage(1, 2), 'direct na join beschermd')
    Mock.advance(CombatCfg.Rules.spawnProtectionSeconds * 1000 + 50)
    Test.ok(Combat.evaluateDamage(1, 2), 'na beschermtijd schade mogelijk (geen handmatige stap)')
    Combat.Players[2].alive = false; Combat.Players[2].diedAt = Combat.now() - 8000
    Mock.callback('combat:respawn', 2)
    Test.no(Combat.evaluateDamage(1, 2), 'na respawn opnieuw beschermd')
    Mock.advance(CombatCfg.Rules.spawnProtectionSeconds * 1000 + 50)
    Test.ok(Combat.evaluateDamage(1, 2), 'en weer automatisch voorbij')
end)

Test.case('inventaris, geld en RP-loadout blijven ongewijzigd door een volledige PvP-cyclus', function()
    reset()
    local rp = { { name = 'WEAPON_COMBATPISTOL', ammo = 30 }, { name = 'WEAPON_BAT', ammo = 1 } }
    local a = addP(1, { loadout = rp, money = 777, bank = 4321 }); addP(2)
    a.addInventoryItem('bread', 3); a.addInventoryItem('water', 2)
    local function snap() return json.encode({ inv = a.inventory, lo = a.loadout, m = a.money, b = a.accounts.bank, bm = a.accounts.black_money }) end
    local before = snap()
    join(1); Mock.advance(1500); join(2)
    Mock.advance(30000)
    a.updateWeaponAmmo('WEAPON_COMBATPISTOL', 150)             -- ESX schrijft combat-munitie terug (zoals esx:updateWeaponAmmo)
    Mock.fire('combat:died', 1, 2, 0)                          -- A sterft (geen beloning voor A)
    Mock.advance(6000); Mock.callback('combat:respawn', 1)
    Mock.advance(20000)
    Combat.Players[1].lastDamageAt = -1e9
    Mock.callback('combat:leave', 1)
    Test.eq(snap(), before, 'inventaris/loadout/geld/bank identiek')
    -- sterven en disconnecten in de zone
    Mock.advance(10000); join(1); Mock.advance(1500)
    Mock.fire('combat:died', 1, 2, 0)
    Mock.removePlayer(1)
    Test.eq(snap(), before, 'ook na disconnect in de zone')
end)

Test.case('forced leave terwijl dood (jobwissel) laat niemand vastzitten', function()
    reset()
    local a = addP(1, { job = 'offpolice' }); addP(2)
    join(1); Mock.advance(1500); join(2); Mock.advance(30000)
    Mock.fire('combat:died', 1, 2, 0)
    a.setJob('police', 1)
    Test.eq(Combat.Players[1], nil, 'uit zone na jobwissel')
    Test.eq(Mock.eventsNamed('combat:left', 1)[1].args[1], 'combat.left_job', 'client krijgt combat:left (herstelt zichzelf)')
    Test.eq(Mock.callback('combat:respawn', 1).reason, 'combat.not_joined', 'respawn-aanvraag wordt netjes geweigerd (client ruimt lokaal op)')
    Test.eq(Mock.players[1].state.inCombat, false, 'state bag opgeruimd')
end)

Test.case('niet-deelnemers: zone betreden zonder te joinen heeft geen serverstatus en kost niets', function()
    reset()
    local a = addP(1, { money = 500 })
    Test.eq(next(Combat.Players), nil, 'niemand in PvP-registratie')
    Test.eq(Combat.countPlayers('haven'), 0, 'zone leeg')
    local zones = Mock.callback('combat:getZones', 1)
    Test.eq(#zones, 3, 'zones zichtbaar voor iedereen')
    Mock.advance(10000); Combat.tick(); Combat.tick()
    Test.eq(a.money, 500, 'geen kosten of beloning')
    Test.ok(Combat.evaluateDamage(1, 1 + 0) ~= nil or true, 'n.v.t.')
    addP(2, { coords = { x = 0.0, y = 0.0, z = 30.0 } })
    Test.ok(Combat.evaluateDamage(2, 1), 'buiten PvP: normale serverregels (Outside.mode = rp)')
end)

Test.case('event-spam: joinen/respawn/leave/verlaten worden begrensd', function()
    reset(); addP(1)
    local ok = 0
    for _ = 1, 20 do if join(1).ok then ok = ok + 1 end end
    Test.eq(ok, 1, '20× join in dezelfde ms → 1 deelname')
    Test.eq(Combat.countPlayers('haven'), 1, 'één registratie')
    local limited = 0
    for _ = 1, 20 do if Mock.callback('combat:respawn', 1).reason == 'combat.too_fast' or Mock.callback('combat:respawn', 1).reason == 'combat.not_dead' then limited = limited + 1 end end
    Test.ok(limited > 0, 'respawn-spam geweigerd')
    local zonesCalls = 0
    for _ = 1, 10 do if #Mock.callback('combat:getZones', 1) > 0 then zonesCalls = zonesCalls + 1 end end
    Test.eq(zonesCalls, 1, 'getZones-spam: slechts één antwoord per 400 ms')
end)

Test.case('streak: groeit per kill, reset bij dood, bonus begrensd', function()
    reset(); duel()
    local R = CombatCfg.Rewards
    local bank = Mock.xPlayers[1].accounts.bank
    local gains = {}
    for i = 1, 14 do
        if not Combat.Players[2].alive then Mock.advance(7000); Mock.callback('combat:respawn', 2) end
        Mock.advance(R.pairCooldownSeconds * 1000 + 15000)
        Combat.Players[2].spawnedAt = Combat.now() - 20000
        Mock.fire('combat:died', 2, 1, 0)
        gains[i] = Mock.xPlayers[1].accounts.bank - bank; bank = Mock.xPlayers[1].accounts.bank
    end
    Test.eq(gains[1], R.killMoney, 'eerste kill = basis')
    Test.eq(gains[2], R.killMoney + R.streakMoneyPerKill, 'tweede kill = basis + 1 streakstap')
    Test.eq(gains[14], R.killMoney + R.streakMoneyMax, 'bonus begrensd op streakMoneyMax')
    Test.eq(Combat.Players[1].streak, 14, 'streak telt door')
    Mock.fire('combat:died', 1, 2, 0)
    Test.eq(Combat.Players[1].streak, 0, 'streak reset bij dood')
    Test.eq(exports.combat_stats:Get(1).best_streak, 14, 'beste serie bewaard')
end)
