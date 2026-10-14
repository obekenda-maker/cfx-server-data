--[[
    COMBAT_CORE – alle instellingen voor PvP-zones, loadouts, beloningen en regels.
    Teksten staan in server_config/locale_nl.lua.

    LET OP: controleer alle coördinaten in-game (admin-commando /coords).
]]

CombatCfg = {}

CombatCfg.Debug = false

---------------------------------------------------------------------------
-- Regels binnen combat zones
---------------------------------------------------------------------------
CombatCfg.Rules = {
    tickMs                  = 1000,   -- server-controle van zonegrenzen
    zoneMargin              = 8.0,    -- meter tolerantie buiten de straal
    leaveConfirmTicks       = 3,      -- zoveel ticks buiten zone voordat automatisch wordt verlaten
    joinCooldownSeconds     = 5,      -- wachttijd na verlaten voor opnieuw deelnemen

    respawnSeconds          = 5,      -- minimale wachttijd na overlijden (server dwingt dit af)
    respawnMaxPerMinute     = 8,      -- misbruikbeperking
    spawnProtectionSeconds  = 4,
    protectionBreaksOnFire  = true,   -- beschermtijd vervalt zodra de speler schiet
    combatTagSeconds        = 10,     -- na schade/schieten geen handmatig verlaten (/pvpverlaat)

    bystanderEjectSeconds   = 15,     -- niet-deelnemers in een zone worden hierna naar buiten gezet
    protectBystanders       = true,   -- niet-deelnemers zijn onkwetsbaar + mogen niet schieten
    blockVehicles           = true,   -- geen voertuigen in zones
    blockItemUse            = true,   -- geen eten/medkits e.d. in zones (via exports.combat_core:IsInCombat)
    healOnJoin              = true,

    -- Kill-validatie
    maxKillDistance         = 800.0,  -- server-afstand killer ↔ slachtoffer
    strictDamageCheck       = false,  -- true = kill alleen geldig als server een weaponDamageEvent van de killer zag
    killWindowSeconds       = 20,     -- hoe recent die schade mag zijn (bij strictDamageCheck)
    mutualKillWindowMs      = 3000,   -- killer mag zelf max zoveel ms eerder dood zijn gegaan (wederzijdse kill)
    countEnvironmentDeaths  = true,   -- val/zelfmoord telt als death
    killfeedScope           = 'zone', -- 'zone' (alleen deelnemers) of 'all' (iedereen)

    -- Snapshots zodat combat geen roleplay-systemen kan misbruiken
    freezeNeedsInZone       = true,   -- honger/dorst worden bij verlaten hersteld
    restoreRpLoadout        = true,   -- ESX-loadout wordt na verlaten hersteld (combatwapens verdwijnen)
    auditWeaponsAfterLeave  = true,   -- server controleert of combatwapens zijn blijven hangen
}

---------------------------------------------------------------------------
-- Regels BUITEN combat zones
--   mode = 'rp'        → normaal GTA-gedrag; kills buiten zones geven GEEN combatbeloning,
--                        en worden als mogelijke RDM gelogd (zie rp_jobs death.lua)
--   mode = 'disabled'  → spelers kunnen elkaar buiten zones niet beschadigen
--                        (client: team + friendly fire uit; server: weaponDamageEvent geannuleerd)
---------------------------------------------------------------------------
CombatCfg.Outside = {
    mode = 'rp',
}

---------------------------------------------------------------------------
-- Teams (FFA-zones gebruiken deze niet)
---------------------------------------------------------------------------
CombatCfg.DefaultTeams = {
    { id = 1, label = 'Rood',  color = '#e74c3c', blipColour = 1 },
    { id = 2, label = 'Blauw', color = '#2d9cff', blipColour = 3 },
}

---------------------------------------------------------------------------
-- Loadouts (alleen client-native wapens; worden NOOIT in de ESX-database opgeslagen)
---------------------------------------------------------------------------
CombatCfg.Loadouts = {
    standaard = {
        label   = 'Standaard',
        health  = 200,
        armor   = 50,
        weapons = {
            { name = 'WEAPON_COMBATPISTOL', ammo = 150 },
            { name = 'WEAPON_CARBINERIFLE', ammo = 240 },
        },
    },
    sniper = {
        label   = 'Scherpschutter',
        health  = 200,
        armor   = 25,
        weapons = {
            { name = 'WEAPON_PISTOL',      ammo = 100 },
            { name = 'WEAPON_SNIPERRIFLE', ammo = 40 },
        },
    },
    close = {
        label   = 'Close combat',
        health  = 200,
        armor   = 75,
        weapons = {
            { name = 'WEAPON_PUMPSHOTGUN', ammo = 60 },
            { name = 'WEAPON_MICROSMG',    ammo = 240 },
            { name = 'WEAPON_KNIFE',       ammo = 1 },
        },
    },
}

---------------------------------------------------------------------------
-- Zones
--  mode      : 'ffa' of 'team'
--  coords    : middelpunt, radius in meter
--  loadouts  : toegestane loadout-sleutels (eerste = standaard)
--  spawns    : optioneel eigen spawnpunten (vec4). Zonder `spawns` worden
--              automatisch punten op een ring (65% van de straal) gegenereerd; de
--              grondhoogte wordt door de client bepaald. Teams spawnen in eigen sector.
--  exit      : optioneel vec4 om niet-deelnemers naar toe te sturen
--  entryFee  : instap kost (geldput = economie-sink), entryFeeAccount: 'money'|'bank'
--  scoreLimit: (team) eerste team met zoveel kills wint de ronde
--  rewardMultiplier : vermenigvuldiger op geld+XP voor deze zone
--  minLevel  : minimaal combatlevel
---------------------------------------------------------------------------
CombatCfg.Zones = {
    {
        id = 'haven',
        label = 'Haven Arena',
        coords = vec3(905.0, -2200.0, 30.5),
        radius = 120.0,
        mode = 'ffa',
        maxPlayers = 24,
        minLevel = 1,
        entryFee = 0,
        entryFeeAccount = 'money',
        rewardMultiplier = 1.0,
        loadouts = { 'standaard', 'close' },
        blip = { sprite = 84, colour = 1, scale = 0.9 },
    },
    {
        id = 'vliegveld',
        label = 'Vliegveld Teamfight',
        coords = vec3(1700.0, 3260.0, 41.0),
        radius = 170.0,
        mode = 'team',
        teams = nil, -- nil = CombatCfg.DefaultTeams
        scoreLimit = 30,
        maxPlayers = 30,
        minLevel = 1,
        entryFee = 0,
        entryFeeAccount = 'money',
        rewardMultiplier = 1.2,
        loadouts = { 'standaard', 'sniper' },
        blip = { sprite = 84, colour = 3, scale = 0.9 },
    },
    {
        id = 'steengroeve',
        label = 'Steengroeve',
        coords = vec3(2950.0, 2750.0, 43.0),
        radius = 100.0,
        mode = 'ffa',
        maxPlayers = 16,
        minLevel = 1,
        entryFee = 100,
        entryFeeAccount = 'money',
        rewardMultiplier = 1.5,
        loadouts = { 'sniper', 'standaard' },
        blip = { sprite = 84, colour = 17, scale = 0.9 },
    },
}

---------------------------------------------------------------------------
-- Beloningen – bewust beperkt zodat de economie niet kan ontsporen
---------------------------------------------------------------------------
CombatCfg.Rewards = {
    enabled            = true,

    killMoney          = 100,        -- basis per kill
    killMoneyAccount   = 'bank',     -- 'money' | 'bank' | 'black_money'
    killXp             = 25,

    streakMoneyPerKill = 10,         -- extra per kill in de huidige serie
    streakMoneyMax     = 100,        -- maximale streakbonus per kill
    streakXpPerKill    = 2,
    streakXpMax        = 20,

    teamWinMinPlayers  = 4,          -- minimaal aantal spelers in de zone (en beide teams bezet) voor een teambonus
    teamWinBonus       = 300,        -- geld voor elk winnend teamlid aanwezig in de zone
    teamWinXp          = 50,

    dailyMoneyCap      = 3000,       -- per speler per dag (combatgeld)
    globalHourlyBudget = 60000,      -- totaal combatgeld dat de server per uur mag uitgeven
    pairCooldownSeconds = 120,       -- zelfde killer→slachtoffer geeft hierbinnen geen beloning/stat
    minAliveSeconds    = 10,         -- slachtoffer moet minimaal zo lang geleefd hebben (na spawn)

    logAllKills        = false,      -- true = elke kill naar Discord (#combat)
    logRewardAtLeast   = 250,        -- anders alleen beloningen vanaf dit bedrag
    killLogDays        = 30,         -- combat_kill_log bewaren
}

---------------------------------------------------------------------------
-- Jobregels. Sleutel = ESX job-naam. Niet vermelde jobs gebruiken `default`.
--  canJoin           : mag deelnemen aan PvP
--  rewardMultiplier  : vermenigvuldiger op beloningen
--  reason            : sleutel uit de NL-teksten (locale) bij weigering
-- Af-dienst-jobs (offpolice, offambulance, ...) vallen onder `default`.
---------------------------------------------------------------------------
CombatCfg.JobRules = {
    default   = { canJoin = true,  rewardMultiplier = 1.0 },
    police    = { canJoin = false, reason = 'combat.job_blocked_duty' },
    ambulance = { canJoin = false, reason = 'combat.job_blocked_duty' },
    mechanic  = { canJoin = true,  rewardMultiplier = 1.0 },
}

---------------------------------------------------------------------------
-- Wapenlabels voor de killfeed (Nederlands). Onbekende wapens → 'Onbekend wapen'.
---------------------------------------------------------------------------
CombatCfg.WeaponLabels = {
    WEAPON_UNARMED        = 'Vuisten',
    WEAPON_KNIFE          = 'Mes',
    WEAPON_PISTOL         = 'Pistool',
    WEAPON_COMBATPISTOL   = 'Combat pistool',
    WEAPON_HEAVYPISTOL    = 'Zwaar pistool',
    WEAPON_MICROSMG       = 'Micro SMG',
    WEAPON_SMG            = 'SMG',
    WEAPON_ASSAULTRIFLE   = 'Aanvalsgeweer',
    WEAPON_CARBINERIFLE   = 'Karabijn',
    WEAPON_PUMPSHOTGUN    = 'Pompgeweer',
    WEAPON_SNIPERRIFLE    = 'Sluipschuttersgeweer',
    WEAPON_BAT            = 'Honkbalknuppel',
    WEAPON_RUN_OVER_BY_CAR = 'Aangereden',
    WEAPON_FALL           = 'Val',
}
