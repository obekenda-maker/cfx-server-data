--[[
    SERVER_WELCOME – instellingen voor regels, akkoord en onboarding.
    Teksten: server_config/locale_nl.lua (sleutels welcome.*) en rules_nl.lua (de regels zelf).
]]

WelcomeCfg = {}

WelcomeCfg.Rules = {
    version            = 1,      -- VERHOOG dit getal als je de regels wijzigt: iedereen moet dan opnieuw akkoord geven
    requireAcceptance  = true,   -- false = regels worden alleen getoond, niemand wordt verplicht
    acceptTimeoutSeconds = 420,  -- wie in deze tijd (na laden, dus incl. personage aanmaken) niet akkoord geeft wordt door de SERVER gekickt
    kickOnDecline      = true,   -- "Niet akkoord" = van de server gezet
    chatFallbackCommand = 'akkoord',   -- noodoplossing als de knop niet werkt: typ /akkoord
}

WelcomeCfg.Onboarding = {
    enabled = true,              -- eerste keer (na akkoord) de uitleg tonen; later opnieuw met /welkom
}

--- Navigatiepunten die de onboarding op de kaart kan zetten (SetNewWaypoint).
--- LET OP: moeten overeenkomen met de echte locaties (tests/check_config.py controleert dit tegen rp_jobs/rp_garages).
WelcomeCfg.Waypoints = {
    jobcenter = { label = 'Jobcentrum',                coords = vec3(-268.0, -957.0, 31.2) },
    dealer    = { label = 'Autodealer (PDM)',          coords = vec3(-56.8, -1096.7, 26.4) },
    garage    = { label = 'Garage Legion Square',      coords = vec3(215.8, -810.1, 30.7) },
}

--- Stappen van de onboarding. title/text-sleutels staan in locale_nl.lua; waypoint is optioneel.
WelcomeCfg.Steps = {
    { key = 'welcome' },
    { key = 'character' },
    { key = 'work',    waypoint = 'jobcenter' },
    { key = 'vehicle', waypoint = 'dealer' },
    { key = 'shops' },
    { key = 'pvp' },
    { key = 'gangs' },
    { key = 'help' },
}

--- Commando's die in /help worden getoond (groepen → regels). Teksten via sleutels.
WelcomeCfg.Help = {
    { group = 'welcome.help_g_general', items = {
        { '/help', 'welcome.help_help' }, { '/regels', 'welcome.help_rules' }, { '/welkom', 'welcome.help_welcome' },
        { '/baan', 'welcome.help_job' }, { '/id', 'welcome.help_id' },
        { '/me  /do', 'welcome.help_medo' }, { '/geefgeld  /geefitem', 'welcome.help_give' }, { 'X', 'welcome.help_hands' },
    } },
    { group = 'welcome.help_g_pvp', items = {
        { '/pvp', 'welcome.help_pvp' }, { '/pvpverlaat', 'welcome.help_pvpleave' }, { 'F7 (vasthouden) of /top', 'welcome.help_top' },
    } },
    { group = 'welcome.help_g_jobs', items = {
        { '/politie  /boei  /ontboei  /fouilleer', 'welcome.help_police' }, { '/repareer', 'welcome.help_repair' }, { '/taxi', 'welcome.help_taxi' },
    } },
    { group = 'welcome.help_g_gangs', items = { { '/gang', 'welcome.help_gang' } } },
}
