fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'admin_tools'
description 'Beheer: kick, ban (database), waarschuwingen, spelerscontrole, teleport, adminmenu en /coords'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    '@server_config/config.lua',
    '@server_config/locale_nl.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'es_extended',
    'server_config',
    'server_logs',
}
