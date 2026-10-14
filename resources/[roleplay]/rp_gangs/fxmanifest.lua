fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rp_gangs'
description 'Gangs, ganggrades, territoria, ganggevechten (via combat_core), zwarte markt en illegale activiteiten'
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
    'server/territory.lua',
    'server/market.lua',
}

client_scripts {
    '@server_config/interact.lua',
    'client/main.lua',
    'client/market.lua',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'es_extended',
    'server_config',
    'server_logs',
    'combat_core',
    'rp_jobs',
}
