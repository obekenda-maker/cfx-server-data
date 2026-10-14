fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rp_interactions'
description 'Speler-interacties: /me, /do, /id, geld en items geven, handen omhoog'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    '@server_config/config.lua',
    '@server_config/locale_nl.lua',
    'config.lua',
}

server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }

dependencies {
    'ox_lib',
    'es_extended',
    'server_config',
    'server_logs',
}
