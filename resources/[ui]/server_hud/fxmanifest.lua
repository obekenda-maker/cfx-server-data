fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'server_hud'
description 'Moderne NUI-HUD: status, geld, job, voertuig, munitie, combat, killfeed en leaderboard'
version '1.0.0'

ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    '@server_config/config.lua',
    '@server_config/locale_nl.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'ox_lib',
    'es_extended',
    'server_config',
}
