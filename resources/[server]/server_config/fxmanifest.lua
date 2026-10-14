fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'server_config'
description 'Centrale serverconfiguratie, Nederlandse teksten en gedeelde helpers'
version '1.0.0'

-- Andere resources laden deze bestanden via:
--   shared_scripts { '@server_config/config.lua', '@server_config/locale_nl.lua' }
shared_scripts {
    'config.lua',
    'locale_nl.lua',
}

files {
    'config.lua',
    'locale_nl.lua',
    'interact.lua',
}
