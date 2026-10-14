fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'combat_stats'
description 'Combatstatistieken: kills, deaths, K/D, XP, level, dagcap en leaderboard'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    '@server_config/config.lua',
    '@server_config/locale_nl.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'es_extended',
    'server_config',
}
