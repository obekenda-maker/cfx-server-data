--[[
    Nederlandse teksten voor de hele server. Gebruik %s / %d voor variabelen.
    Pas hier gerust teksten aan; de sleutels (links) niet wijzigen.
]]

ServerCfg = ServerCfg or {}
ServerCfg.Locale = ServerCfg.Locale or {}

local L = ServerCfg.Locale

local function add(tbl)
    for k, v in pairs(tbl) do L[k] = v end
end

---------------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------------
add({
    ['combat.not_loaded']        = 'Je speler is nog niet geladen.',
    ['combat.zone_unknown']     = 'Deze combat zone bestaat niet.',
    ['combat.already_joined']   = 'Je doet al mee aan PvP.',
    ['combat.cooldown']         = 'Wacht heel even voordat je opnieuw kunt deelnemen.',
    ['combat.job_blocked_duty'] = 'Met je huidige baan kun je niet aan PvP deelnemen. Ga eerst uit dienst.',
    ['combat.no_access']        = 'Je hebt geen toegang tot deze zone.',
    ['combat.zone_full']        = 'Deze zone zit vol.',
    ['combat.level_low']        = 'Je hebt combatlevel %d nodig voor deze zone.',
    ['combat.not_in_zone']      = 'Je staat niet in de zone.',
    ['combat.in_vehicle']       = 'Stap eerst uit je voertuig.',
    ['combat.dead']             = 'Je kunt niet deelnemen terwijl je bewusteloos bent.',
    ['combat.cuffed']           = 'Je kunt niet deelnemen terwijl je geboeid bent.',
    ['combat.no_money']         = 'Je hebt €%d contant nodig voor de entree.',
    ['combat.too_fast']         = 'Rustig aan, probeer het zo opnieuw.',
    ['combat.not_joined']       = 'Je doet niet mee aan PvP.',
    ['combat.not_dead']         = 'Je leeft nog.',
    ['combat.tagged']           = 'Je zit in gevecht! Verlaten kan pas na %d seconden zonder schade.',
    ['combat.respawn_wait']     = 'Je kunt nog niet respawnen.',
    ['combat.respawn_limit']    = 'Je respawnt te vaak. Even wachten...',
    ['combat.joined']           = 'Je doet nu mee in %s. Veel succes!',
    ['combat.left']             = 'Je hebt de PvP verlaten. Je roleplay-wapens en -status zijn hersteld.',
    ['combat.left_outside']     = 'Je bent buiten de zone gegaan: PvP verlaten. Je roleplay-wapens zijn hersteld.',
    ['combat.left_job']         = 'Je baan is gewijzigd: PvP verlaten.',
    ['combat.left_forced']      = 'Je bent uit de PvP gehaald.',
    ['combat.weapon_unknown']   = 'Onbekend wapen',
    ['combat.kill_reward']      = 'Kill op %s: +€%d en +%d XP',
    ['combat.reward_capped']    = 'Daglimiet of serverbudget voor combatbeloningen bereikt: geen geld meer.',
    ['combat.kill_no_reward']   = 'Kill geteld voor de score, maar zonder beloning (herhaling of te snel).',
    ['combat.round_won']        = 'Team %s heeft de ronde gewonnen!',
    ['combat.round_bonus']      = 'Team %s wint de ronde! Bonus: +€%d',
    ['combat.round_lost']       = 'Team %s heeft de ronde gewonnen. Nieuwe ronde!',
    ['combat.choose_loadout']   = 'Kies je loadout',
    ['combat.loadout']          = 'Loadout',
    ['combat.prompt_header']    = 'PvP-zone: %s',
    ['combat.prompt_content']   = 'Je betreedt een PvP-zone (%s). Alleen spelers die meedoen kunnen elkaar beschadigen. Je roleplay-wapens en -inventaris blijven veilig en worden bij het verlaten hersteld. Entreegeld: €%d.\n\nWil je meedoen?',
    ['combat.prompt_yes']       = 'Deelnemen',
    ['combat.prompt_no']        = 'Nee, bedankt',
    ['combat.mode_team']        = 'Teamgevecht',
    ['combat.mode_ffa']         = 'Free-for-all',
    ['combat.blip_name']        = 'PvP: %s',
    ['combat.banner_enter']     = 'PvP-zone: %s',
    ['combat.banner_enter_sub'] = 'Alleen deelnemers kunnen schade doen',
    ['combat.banner_leave']     = 'Je verlaat %s',
    ['combat.banner_leave_sub'] = 'Normale serverregels gelden weer',
    ['combat.zone_enter']       = 'Je betreedt de PvP-zone %s.',
    ['combat.zone_leave']       = 'Je verlaat de PvP-zone %s.',
    ['combat.vehicle_hint']     = 'PvP-zone: stap uit en gebruik /pvp om mee te doen. Tot die tijd ben je beschermd.',
    ['combat.bystander_hint']   = 'Je doet niet mee en bent beschermd. Verlaat de zone binnen %d seconden of gebruik /pvp.',
    ['combat.ejected']          = 'Je bent uit de PvP-zone %s gezet.',
    ['combat.death_timer']      = 'Uitgeschakeld – respawn over %d s',
    ['combat.death_respawning'] = 'Respawnen...',
    ['combat.waypoint_set']     = 'Route naar %s ingesteld.',
    ['combat.cmd_pvp']          = 'Open het PvP-menu (zones, deelnemen, verlaten)',
    ['combat.cmd_leave']        = 'Verlaat de PvP-zone waar je in meedoet',
    ['combat.menu_title']       = 'PvP / Combat',
    ['combat.menu_current']     = 'Je doet mee in: %s',
    ['combat.menu_stats']       = 'Kills %d • Deaths %d • Serie %d',
    ['combat.menu_leave']       = 'PvP verlaten',
    ['combat.menu_leave_desc']  = 'Niet mogelijk in de eerste %d s na schade',
    ['combat.menu_zone_desc']   = '%s • %d/%d spelers • entree €%d',
    ['combat.menu_status']      = 'Status',
    ['combat.menu_here']        = 'Je staat in deze zone – klik om deel te nemen',
    ['combat.menu_away']        = 'Klik om een route te zetten',
    ['combat.menu_none']        = 'Geen zones beschikbaar',
})

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------
add({
    ['hud.key_leaderboard']  = 'Leaderboard tonen (ingedrukt houden)',
    ['hud.health']           = 'Gezondheid',
    ['hud.armor']            = 'Kogelvrij vest',
    ['hud.hunger']           = 'Honger',
    ['hud.thirst']           = 'Dorst',
    ['hud.cash']             = 'Contant',
    ['hud.bank']             = 'Bank',
    ['hud.job_none']         = 'Werkloos',
    ['hud.speed_kmh']        = 'km/u',
    ['hud.speed_mph']        = 'mph',
    ['hud.fuel']             = 'Brandstof',
    ['hud.gear']             = 'Versnelling',
    ['hud.engine']           = 'Motor',
    ['hud.ammo']             = 'Munitie',
    ['hud.combat_zone']      = 'PvP',
    ['hud.kills']            = 'Kills',
    ['hud.deaths']           = 'Deaths',
    ['hud.streak']           = 'Serie',
    ['hud.kd']               = 'K/D',
    ['hud.team']             = 'Team',
    ['hud.round_to']         = 'Eerste tot %d',
    ['hud.protected']        = 'Beschermd',
    ['hud.dead']             = 'Uitgeschakeld',
    ['hud.kill_text']        = '{killer} heeft {victim} geëlimineerd met {weapon}',
    ['hud.suicide_text']     = '{victim} is uitgeschakeld ({weapon})',
    ['hud.streak_text']      = 'serie van {n}',
    ['hud.board_title']      = 'Leaderboard',
    ['hud.board_sort_kills'] = 'Meeste kills',
    ['hud.board_sort_kd']    = 'Beste K/D',
    ['hud.board_sort_xp']    = 'Meeste XP',
    ['hud.board_rank']       = '#',
    ['hud.board_name']       = 'Speler',
    ['hud.board_level']      = 'Lvl',
    ['hud.board_empty']      = 'Nog geen statistieken.',
    ['hud.board_mine']       = 'Jouw statistieken',
    ['hud.board_xp']         = 'XP',
    ['hud.board_best']       = 'Beste serie',
    ['hud.cmd_top']          = 'Toon het leaderboard (kills, kd of xp)',
})
