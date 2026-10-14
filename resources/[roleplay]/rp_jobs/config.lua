--[[
    RP_JOBS – instellingen voor banen.
    De jobs en jobgrades (naam, label, SALARIS) staan in sql/02_jobs_items.sql (ESX-tabellen jobs/job_grades).
    Pas daar salarissen aan; ESX keert het salaris uit volgens de paycheck-instellingen van es_extended.

    Conventie: een job die "op dienst" is heeft de naam X, "af dienst" heet 'off' .. X (bijv. police / offpolice).
    Coördinaten: controleer in-game met /coords (admin).
]]

JobsCfg = {}

JobsCfg.OffDutyPrefix = 'off'

---------------------------------------------------------------------------
-- JOBCATALOGUS – de ENIGE bron voor jobs, jobgrades en salarissen.
--
--   name        : ESX-jobnaam (kleine letters)
--   label       : weergavenaam
--   public      : true = burgers kunnen zich aanmelden bij het Jobcentrum (alleen grade 0)
--   whitelisted : true = alleen via bossmenu/admin (ESX-vlag `whitelisted`)
--   offDuty     : true = er wordt ook een 'off'-variant (af dienst, salaris 0) aangemaakt
--   info        : tekstsleutel met uitleg voor /baan (staat in server_config/locale_nl.lua)
--   grades      : { name, label, salary } – salaris per ESX-uitbetaling; de HOOGSTE grade heet 'boss'
--                 als de job een bedrijfskas/bossmenu heeft (JobsCfg.Societies).
--
-- Een wijziging toepassen:
--   1. pas hier aan,
--   2. `python3 scripts/gen_jobs_sql.py` (werkt sql/02_jobs_items.sql bij) en importeer die SQL, OF
--      typ in de SERVERCONSOLE `jobsync` (schrijft de catalogus naar de database),
--   3. herstart de server (ESX leest jobs alleen bij het opstarten).
-- Bij elke serverstart waarschuwt rp_jobs in de console als de database afwijkt van deze catalogus.
-- De ESX-standaardjob 'unemployed' (werkloos) staat bewust niet hier: die levert ESX zelf.
---------------------------------------------------------------------------
JobsCfg.Catalog = {
    {
        name = 'police', label = 'Politie', public = false, whitelisted = true, offDuty = true, info = 'jobs.info_police',
        grades = {
            { name = 'cadet',      label = 'Cadet',       salary = 350 },
            { name = 'agent',      label = 'Agent',       salary = 500 },
            { name = 'brigadier',  label = 'Brigadier',   salary = 650 },
            { name = 'inspecteur', label = 'Inspecteur',  salary = 800 },
            { name = 'boss',       label = 'Commissaris', salary = 1000 },
        },
    },
    {
        name = 'ambulance', label = 'Ambulance', public = false, whitelisted = true, offDuty = true, info = 'jobs.info_ambulance',
        grades = {
            { name = 'ambulancier', label = 'Ambulancier', salary = 400 },
            { name = 'verpleger',   label = 'Verpleger',   salary = 550 },
            { name = 'arts',        label = 'Arts',        salary = 750 },
            { name = 'boss',        label = 'Chef',        salary = 950 },
        },
    },
    {
        name = 'mechanic', label = 'Monteur', public = true, whitelisted = false, offDuty = true, info = 'jobs.info_mechanic',
        grades = {
            { name = 'leerling', label = 'Leerling', salary = 250 },
            { name = 'monteur',  label = 'Monteur',  salary = 400 },
            { name = 'boss',     label = 'Eigenaar', salary = 650 },
        },
    },
    {
        name = 'taxi', label = 'Taxichauffeur', public = true, whitelisted = false, offDuty = false, info = 'jobs.info_taxi',
        grades = {
            { name = 'chauffeur', label = 'Chauffeur', salary = 200 },
            { name = 'boss',      label = 'Manager',   salary = 400 },
        },
    },
    {
        name = 'trucker', label = 'Vrachtwagenchauffeur', public = true, whitelisted = false, offDuty = false, info = 'jobs.info_trucker',
        grades = { { name = 'chauffeur', label = 'Chauffeur', salary = 150 } },
    },
    {
        name = 'courier', label = 'Bezorger', public = true, whitelisted = false, offDuty = false, info = 'jobs.info_courier',
        grades = { { name = 'bezorger', label = 'Bezorger', salary = 100 } },
    },
}

--- Jobcentrum: hier melden burgers zich aan voor `public`-jobs (grade 0) of stoppen ze ermee.
JobsCfg.JobCenter = {
    label                 = 'Jobcentrum',
    coords                = vec3(-268.0, -957.0, 31.2),
    distance              = 2.5,
    blip                  = { sprite = 351, colour = 2 },
    minSecondsBetween     = 600,   -- minimaal zoveel seconden tussen twee baanwissels (voorkomt job-hoppen)
    maxChangesPerDay      = 6,
}

---------------------------------------------------------------------------
-- Dienst in/uit
---------------------------------------------------------------------------
JobsCfg.Duty = {
    { job = 'police',    label = 'Politiebureau',     coords = vec3(441.0, -981.0, 30.7),  blip = { sprite = 60,  colour = 3 } },
    { job = 'ambulance', label = 'Ziekenhuis',        coords = vec3(307.7, -595.0, 43.3),  blip = { sprite = 61,  colour = 1 } },
    { job = 'mechanic',  label = 'Monteurs-garage',   coords = vec3(-337.0, -137.0, 39.0), blip = { sprite = 446, colour = 5 } },
}
JobsCfg.DutyDistance = 2.0

--- Bossmenu (esx_society). Alleen voor jobgrade met naam 'boss'.
JobsCfg.Boss = {
    { job = 'police',    coords = vec3(448.0, -973.0, 30.7) },
    { job = 'ambulance', coords = vec3(335.5, -594.0, 43.3) },
    { job = 'mechanic',  coords = vec3(-347.0, -133.0, 39.0) },
    { job = 'taxi',      coords = vec3(895.0, -179.0, 74.7) },
}

--- Societies (gedeelde bedrijfsrekeningen) – worden geregistreerd bij esx_society.
--- Tabelrijen hiervoor staan in sql/03_societies.sql
JobsCfg.Societies = {
    { job = 'police',    label = 'Politie',    type = 'public' },
    { job = 'ambulance', label = 'Ambulance',  type = 'public' },
    { job = 'mechanic',  label = 'Monteurs',   type = 'private' },
    { job = 'taxi',      label = 'Taxi',       type = 'private' },
}

---------------------------------------------------------------------------
-- Politie
---------------------------------------------------------------------------
JobsCfg.Police = {
    job            = 'police',
    actionDistance = 3.5,       -- server-controle afstand agent ↔ burger
    maxFine        = 5000,      -- maximale boete per keer
    searchRequiresCuffs = true,
    societyAccount = 'society_police',   -- boetes gaan hierheen (indien esx_addonaccount aanwezig)
}

---------------------------------------------------------------------------
-- Dood / ambulance
---------------------------------------------------------------------------
JobsCfg.Death = {
    callCooldownSeconds   = 30,      -- hulp melden
    respawnAfterSeconds   = 60,      -- vroegst mogelijke ziekenhuis-respawn
    autoRespawnSeconds    = 300,     -- automatisch naar ziekenhuis na zoveel seconden
    hospitalFee           = 500,     -- kosten (nooit meer dan de speler bezit)
    reviveFee             = 150,     -- betaalt patiënt aan society_ambulance bij revive door medic
    reviveHealth          = 140,     -- 100 = dood-grens, 200 = vol
    reviveDistance        = 4.0,
    reviveSeconds         = 8,
    medicJob              = 'ambulance',
    medicSociety          = 'society_ambulance',
    hospitals = {
        { label = 'Central Los Santos Medical Center', coords = vec4(341.0, -1397.3, 32.5, 48.5) },
        { label = 'Pillbox Hill Medical',              coords = vec4(298.0, -584.0, 43.3, 70.0) },
    },
    -- Dood buiten een combat zone door een andere speler = mogelijke RDM → Discord-log
    logPlayerKills        = true,
    rdmWarnThreshold      = 3,       -- dit aantal in een uur door dezelfde speler → opvallende melding
}

---------------------------------------------------------------------------
-- Monteur
---------------------------------------------------------------------------
JobsCfg.Mechanic = {
    job           = 'mechanic',
    repairItem    = 'repairkit',    -- item wordt verbruikt ('' = geen item nodig)
    repairSeconds = 12,
    maxDistance   = 4.0,
}

---------------------------------------------------------------------------
-- Taxi (de passagier betaalt: geld wordt overgedragen, niet gecreëerd)
---------------------------------------------------------------------------
JobsCfg.Taxi = {
    job            = 'taxi',
    baseFare       = 50,
    perKm          = 120,
    maxFare        = 1500,
    societyShare   = 0.20,          -- deel van het tarief gaat naar society_taxi
    societyAccount = 'society_taxi',
    maxDistance    = 6.0,
}

---------------------------------------------------------------------------
-- Bezorgbanen (vrachtwagenchauffeur + bezorger)
--  pay          : vast bedrag per route (server bepaalt, client kan het niet aanpassen)
--  dailyMax     : maximaal verdiend aan deze baan per dag
--  maxSpeed     : m/s waarmee de minimale reistijd wordt berekend (anti-teleport)
---------------------------------------------------------------------------
JobsCfg.Delivery = {
    trucker = {
        job = 'trucker', label = 'Vrachtwagenchauffeur',
        depot = { coords = vec3(153.2, -3211.9, 5.9), spawn = vec4(160.0, -3200.0, 5.9, 270.0), vehicle = 'mule', blip = { sprite = 477, colour = 47 } },
        dailyMax = 6000, maxSpeed = 40.0, finishDistance = 12.0, unloadSeconds = 8,
        routes = {
            { label = 'LTD Davis',          coords = vec3(-47.0, -1758.2, 29.4),  pay = 650 },
            { label = '24/7 Strawberry',    coords = vec3(25.7, -1347.3, 29.5),   pay = 600 },
            { label = 'LTD Mirror Park',    coords = vec3(1163.4, -323.8, 69.2),  pay = 800 },
            { label = 'LTD Little Seoul',   coords = vec3(-707.5, -914.3, 19.2),  pay = 750 },
            { label = 'LTD Grapeseed',      coords = vec3(1698.4, 4924.4, 42.1),  pay = 1400 },
        },
    },
    courier = {
        job = 'courier', label = 'Bezorger',
        depot = { coords = vec3(-1081.0, -248.0, 37.8), spawn = vec4(-1075.0, -255.0, 37.8, 205.0), vehicle = 'faggio2', blip = { sprite = 478, colour = 28 } },
        dailyMax = 3000, maxSpeed = 30.0, finishDistance = 6.0, unloadSeconds = 4,
        routes = {
            { label = 'Robs Liquor Morningwood', coords = vec3(-1222.9, -907.0, 12.3), pay = 300 },
            { label = 'LTD Little Seoul',        coords = vec3(-707.5, -914.3, 19.2),  pay = 280 },
            { label = '24/7 Strawberry',         coords = vec3(25.7, -1347.3, 29.5),   pay = 450 },
        },
    },
}
