--[[
    RP_GANGS – alle instellingen voor gangs, territoria, ganggevechten en illegale handel.
    Coördinaten: controleer in-game met /coords (admin).
    Gangs zijn onderdeel van de roleplay-wereld: ganggevechten vinden ALLEEN plaats in een tijdelijke
    combat zone van combat_core waar alleen de twee betrokken gangs aan mee kunnen doen (opt-in).
]]

GangCfg = {}

---------------------------------------------------------------------------
-- Oprichten
---------------------------------------------------------------------------
GangCfg.Creation = {
    cost         = 50000,        -- wordt afgeschreven (geldput)
    account      = 'bank',
    maxGangs     = 12,
    nameMin      = 3,
    nameMax      = 24,
    inviteDistance = 4.0,
    cooldownMs   = 1500,
}

---------------------------------------------------------------------------
-- Grades en rechten
-- Rechten: invite, kick, promote, bank_deposit, bank_withdraw, war, blackmarket, disband
---------------------------------------------------------------------------
GangCfg.Grades = {
    [0] = { label = 'Rekruut',     perms = {} },
    [1] = { label = 'Soldaat',     perms = { bank_deposit = true, blackmarket = true } },
    [2] = { label = 'Luitenant',   perms = { bank_deposit = true, blackmarket = true, invite = true } },
    [3] = { label = 'Rechterhand', perms = { bank_deposit = true, blackmarket = true, invite = true, kick = true, promote = true, war = true } },
    [4] = { label = 'Leider',      perms = { bank_deposit = true, bank_withdraw = true, blackmarket = true, invite = true, kick = true, promote = true, war = true, disband = true } },
}
GangCfg.LeaderGrade = 4
GangCfg.MaxMembers  = 20
GangCfg.BankWithdrawMaxPerAction = 20000

---------------------------------------------------------------------------
-- Territoria
--  claimCost  : uit de gangkas (geldput)
--  minOnline  : minimaal aantal leden online om te claimen / uit te dagen
--  incomePerHour : uitkering aan de gangkas per uur (alleen bij >= minOnline leden online)
---------------------------------------------------------------------------
GangCfg.Territories = {
    { id = 'grove',  label = 'Grove Street',  coords = vec3(112.0, -1943.0, 20.8),  radius = 70.0 },
    { id = 'davis',  label = 'Davis',         coords = vec3(-14.0, -1442.0, 31.1),  radius = 70.0 },
    { id = 'mirror', label = 'Mirror Park',   coords = vec3(1163.0, -323.0, 69.2),  radius = 80.0 },
}
GangCfg.Territory = {
    claimCost      = 25000,
    minOnline      = 2,
    maxPerGang     = 2,
    incomePerHour  = 400,
    lockMinutes    = 120,        -- na een claim/oorlog kan het gebied zolang niet worden uitgedaagd
    blipAlpha      = 90,
}

---------------------------------------------------------------------------
-- Ganggevecht (oorlog) om een territorium
---------------------------------------------------------------------------
GangCfg.War = {
    cost           = 15000,      -- uit de gangkas van de uitdager (geldput)
    minOnlineEach  = 2,          -- beide gangs minimaal zoveel leden online
    prepareSeconds = 90,
    durationSeconds = 900,
    winKills       = 15,         -- eerst tot zoveel kills wint direct
    attackerMinKills = 3,        -- uitdager moet minimaal zoveel kills hebben om te winnen
    loadouts       = nil,        -- nil = alle loadouts van combat_core; of bijv. { 'standaard', 'close' }
    radiusFactor   = 1.0,
}

---------------------------------------------------------------------------
-- Zwarte markt (alleen voor gangleden met recht 'blackmarket')
--  account       : 'black_money' of 'money'
--  needTerritory : gang moet minimaal 1 territorium bezitten om wapens te kopen
---------------------------------------------------------------------------
GangCfg.BlackMarket = {
    label = 'Zwarte markt',
    coords = vec3(1241.0, -3257.0, 7.1),
    distance = 2.0,
    account = 'black_money',
    needTerritory = true,
    purchaseCooldownSeconds = 20,
    items = {
        { item = 'lockpick', label = 'Lockpick', price = 450, dailyLimit = 10 },
    },
    weapons = {
        { weapon = 'WEAPON_PISTOL',   label = 'Pistool',   price = 7000,  ammo = 36, dailyLimit = 1 },
        { weapon = 'WEAPON_MICROSMG', label = 'Micro SMG', price = 24000, ammo = 60, dailyLimit = 1 },
    },
}

---------------------------------------------------------------------------
-- Illegale activiteiten
--  minPolice : minimaal aantal agenten op dienst
---------------------------------------------------------------------------
GangCfg.Activities = {
    {
        id = 'scrap', label = 'Schroot verzamelen', coords = vec3(2352.0, 3132.0, 48.2), distance = 3.0,
        seconds = 20, item = 'schroot', count = 3, cooldownSeconds = 90, dailyLimit = 30, minPolice = 0,
    },
}
GangCfg.Fence = {
    label = 'Hehler',
    coords = vec3(-1127.0, -1534.0, 4.4), distance = 2.0,
    account = 'black_money',
    prices = { schroot = 75 },
    dailyAmountCap = 6000,
}
