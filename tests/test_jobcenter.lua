-- Tests jobcatalogus ↔ database, jobsync en Jobcentrum
Mock.loadAll()
local JC = JobsCfg.JobCenter
local function at(v) return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0 } end
local function reset()
    local srcs = {}
    for src in pairs(Mock.xPlayers) do srcs[#srcs + 1] = src end
    for _, src in ipairs(srcs) do Mock.removePlayer(src) end
    DB.exec('DELETE FROM rp_cooldowns')
    Mock.events, Mock.logs = {}, {}
    Mock.registry.combat_core = Mock.registry.combat_core
    Mock.advance(900000)
end
local function bump() Mock.advance(3000) end

Test.case('catalogus en database zijn gelijk na import van de gegenereerde SQL', function()
    local diffs = Jobs.catalogDiff()
    Test.eq(#diffs, 0, 'geen verschillen (' .. table.concat(diffs, '; ') .. ')')
    local jobs, grades = Jobs.catalogRows()
    Test.eq(#jobs, 9, '6 jobs + 3 af-dienst-varianten')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM job_grades'), #grades, 'aantal grade-regels in DB = catalogus')
    Test.eq(DB.scalar("SELECT salary FROM job_grades WHERE job_name = 'offpolice' AND grade = 4"), 0, 'af dienst betaalt 0')
    Test.eq(DB.scalar("SELECT whitelisted FROM jobs WHERE name = 'police'"), 1, 'politie whitelisted')
    Test.eq(DB.scalar("SELECT whitelisted FROM jobs WHERE name = 'taxi'"), 0, 'taxi open')
end)

Test.case('afwijking wordt gemeld; jobsync herstelt (alleen op expliciet commando, alleen superadmin/console)', function()
    reset()
    local old = JobsCfg.Catalog[1].grades[2].salary
    JobsCfg.Catalog[1].grades[2].salary = 777
    local diffs = Jobs.catalogDiff()
    Test.eq(#diffs, 1, 'één afwijking gemeld')
    Test.ok(diffs[1]:find('police', 1, true) and diffs[1]:find('777', 1, true), 'melding noemt job en bedrag')
    Test.eq(DB.scalar("SELECT salary FROM job_grades WHERE job_name = 'police' AND grade = 1"), 500, 'database is NIET automatisch aangepast')

    Mock.addPlayer(1, { group = 'admin' }); Mock.addPlayer(2, { group = 'superadmin' })
    Mock.commands.jobsync(1)
    Test.eq(DB.scalar("SELECT salary FROM job_grades WHERE job_name = 'police' AND grade = 1"), 500, 'admin (geen superadmin) kan niet syncen')
    Mock.commands.jobsync(2)
    Test.eq(DB.scalar("SELECT salary FROM job_grades WHERE job_name = 'police' AND grade = 1"), 777, 'superadmin synct')
    Test.eq(#Jobs.catalogDiff(), 0, 'daarna gelijk')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM job_grades WHERE job_name = ?', { 'police' }), 5, 'geen dubbele grade-regels na sync')
    Test.ok(#Mock.logsOf('admin') >= 1, 'sync gelogd')
    -- console mag ook, en andere (niet-catalogus) jobs blijven onaangeroerd
    DB.exec("INSERT INTO jobs (name, label, whitelisted) VALUES ('eigenjob', 'Eigen', 0)")
    DB.exec("INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES ('eigenjob', 0, 'x', 'X', 1, '{}', '{}')")
    JobsCfg.Catalog[1].grades[2].salary = old
    Mock.commands.jobsync(0)
    Test.eq(DB.scalar("SELECT salary FROM job_grades WHERE job_name = 'police' AND grade = 1"), old, 'console synct terug')
    Test.eq(DB.scalar("SELECT COUNT(*) FROM job_grades WHERE job_name = 'eigenjob'"), 1, 'eigen jobs buiten de catalogus blijven staan')
end)

Test.case('jobcentrum: alleen public jobs, afstand, cooldown, daglimiet, geen ontsnapping uit politie/ambulance', function()
    reset()
    local civ = Mock.addPlayer(1, { job = 'unemployed', coords = at(JC.coords) })
    local list = Mock.callback('rp_jobs:jobcenter:list', 1)
    local names = {}
    for _, j in ipairs(list.jobs) do names[j.name] = true end
    Test.ok(names.taxi and names.trucker and names.courier and names.mechanic, 'burgerbanen zichtbaar')
    Test.no(names.police or names.ambulance, 'politie/ambulance niet in het jobcentrum')

    Test.eq(Mock.callback('rp_jobs:jobcenter:apply', 1, 'police').msg, 'jobs.invalid', 'whitelisted job niet te kiezen')
    bump(); Test.eq(Mock.callback('rp_jobs:jobcenter:apply', 1, 'bestaatniet').msg, 'jobs.invalid', 'onbekende job')
    bump(); Test.eq(Mock.callback('rp_jobs:jobcenter:apply', 1, 'offpolice').msg, 'jobs.invalid', 'off-variant niet te kiezen')
    bump()
    local r = Mock.callback('rp_jobs:jobcenter:apply', 1, 'taxi')
    Test.ok(r.ok, 'aangemeld als taxichauffeur')
    Test.eq(civ.job.name, 'taxi', 'job gezet'); Test.eq(civ.job.grade, 0, 'altijd grade 0')
    bump()
    Test.eq(Mock.callback('rp_jobs:jobcenter:apply', 1, 'courier').msg, 'jobs.jc_wait', 'cooldown tussen baanwissels')
    Mock.advance(JC.minSecondsBetween * 1000 + 1000)
    Test.ok(Mock.callback('rp_jobs:jobcenter:apply', 1, 'courier').ok, 'na cooldown wisselen')
    Mock.advance(JC.minSecondsBetween * 1000 + 1000)
    Test.ok(Mock.callback('rp_jobs:jobcenter:apply', 1, 'unemployed').ok, 'stoppen = werkloos')
    Test.eq(civ.job.name, 'unemployed', 'werkloos')
    -- daglimiet
    DB.exec("INSERT INTO rp_cooldowns (identifier, `action`, `day`, `count`, `amount`) VALUES (?, 'jobchange', ?, 99, 0) ON DUPLICATE KEY UPDATE `count` = 99", { civ.identifier, os.date('%Y-%m-%d') })
    Mock.advance(JC.minSecondsBetween * 1000 + 1000)
    Test.eq(Mock.callback('rp_jobs:jobcenter:apply', 1, 'taxi').msg, 'jobs.jc_daily', 'daglimiet baanwissels')

    -- politie/ambulance kunnen niet via het jobcentrum stoppen; op afstand/tijdens PvP niet
    local cop = Mock.addPlayer(2, { job = 'police', coords = at(JC.coords) })
    Test.eq(Mock.callback('rp_jobs:jobcenter:apply', 2, 'unemployed').msg, 'jobs.jc_locked', 'politie kan niet zomaar stoppen')
    Mock.xPlayers[2].job.name = 'offpolice'; Mock.advance(3000)
    Test.eq(Mock.callback('rp_jobs:jobcenter:apply', 2, 'taxi').msg, 'jobs.jc_locked', 'ook niet "af dienst"')
    local far = Mock.addPlayer(3, { coords = { x = 0.0, y = 0.0, z = 30.0 } })
    Test.eq(Mock.callback('rp_jobs:jobcenter:apply', 3, 'taxi').msg, 'jobs.too_far', 'te ver weg')
    Test.eq(Mock.callback('rp_jobs:jobcenter:list', 3), nil, 'lijst alleen bij het jobcentrum')
    Mock.players[3].coords = at(JC.coords); Mock.advance(3000)
    Mock.registry.combat_core = { IsInCombat = function() return true end }
    Test.eq(Mock.callback('rp_jobs:jobcenter:apply', 3, 'taxi').msg, 'jobs.in_pvp', 'niet tijdens PvP')
    Mock.registry.combat_core = nil
    Test.eq(Mock.callback('rp_jobs:jobcenter:apply', 3, 'taxi').msg, 'jobs.too_fast', 'rate-limit')
end)
