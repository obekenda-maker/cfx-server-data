fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rp_shops'
description 'Winkels (eten/drinken/EHBO), Ammu-Nation met wapenlicentie en bruikbare items'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    '@server_config/config.lua',
    '@server_config/locale_nl.lua',
    'config.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    '@server_config/interact.lua',
    'client/main.lua',
}

dependencies {
    'ox_lib',
    'es_extended',
    'esx_status',
    'esx_basicneeds',
    'esx_license',
    'server_config',
    'server_logs',
}
