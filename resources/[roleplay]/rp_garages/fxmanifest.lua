fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rp_garages'
description 'Voertuigen kopen, bezitten, opslaan (garage) en terughalen (garage/depot) – gebruikt ESX owned_vehicles'
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

client_scripts {
    '@server_config/interact.lua',
    'client/main.lua',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'es_extended',
    'server_config',
    'server_logs',
}
