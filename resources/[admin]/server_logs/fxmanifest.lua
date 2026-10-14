fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'server_logs'
description 'Discord-webhook logging (met wachtrij/rate-limit) en database-audit'
version '1.0.0'

shared_scripts {
    '@server_config/config.lua',
    '@server_config/locale_nl.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

dependencies {
    'oxmysql',
    'server_config',
}
