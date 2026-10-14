fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'server_welcome'
description 'Nederlandse loadscreen, serverregels met akkoord, onboarding voor nieuwe spelers en /help'
version '1.0.0'

loadscreen 'web/loading.html'
ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    '@server_config/config.lua',
    '@server_config/locale_nl.lua',
    'config.lua',
    'rules_nl.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/loading.html',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'es_extended',
    'server_config',
    'server_logs',
}
