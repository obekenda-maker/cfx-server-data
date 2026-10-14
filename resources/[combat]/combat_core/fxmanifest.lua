fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'combat_core'
description 'Combat zones, PvP-regels, spawn, loadouts, beloningen en killfeed-events (server-autoritatief)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    '@server_config/config.lua',
    '@server_config/locale_nl.lua',
    'config.lua',
    'shared/util.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/zones.lua',
    'server/rules.lua',
    'server/rewards.lua',
    'server/damage.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/zones.lua',
    'client/death.lua',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'es_extended',
    'server_config',
    'server_logs',
    'combat_stats',
}
