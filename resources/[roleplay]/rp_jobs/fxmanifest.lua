fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rp_jobs'
description 'Banen: politie, ambulance (dood/revive), monteur, taxi, vrachtwagenchauffeur, bezorger'
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
    'server/catalog.lua',
    'server/police.lua',
    'server/medic.lua',
    'server/mechanic.lua',
    'server/taxi.lua',
    'server/delivery.lua',
}

client_scripts {
    '@server_config/interact.lua',
    'client/main.lua',
    'client/jobcenter.lua',
    'client/police.lua',
    'client/medic.lua',
    'client/mechanic.lua',
    'client/taxi.lua',
    'client/delivery.lua',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'es_extended',
    'esx_society',
    'server_config',
    'server_logs',
}
