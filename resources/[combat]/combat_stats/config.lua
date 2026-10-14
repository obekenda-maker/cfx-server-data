StatsCfg = {
    -- level = floor(sqrt(xp / xpBase)) + 1   → level 2 = 1×base, level 3 = 4×base, level 4 = 9×base ...
    xpBase        = 100,
    maxLevel      = 100,

    flushSeconds  = 30,     -- hoe vaak gewijzigde statistieken naar de database worden geschreven
    boardCacheSec = 30,     -- leaderboard-cache
    boardMax      = 25,     -- maximaal op te vragen rijen
    kdMinKills    = 10,     -- minimaal aantal kills om op de K/D-ranglijst te komen
}
