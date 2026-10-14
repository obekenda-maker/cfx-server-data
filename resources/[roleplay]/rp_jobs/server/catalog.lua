--[[
    rp_jobs/server/catalog.lua – jobcatalogus ↔ database, jobcentrum voor burgers.

    * Bij elke start: vergelijkt JobsCfg.Catalog met de tabellen jobs/job_grades en WAARSCHUWT bij verschil.
      Er wordt NIETS automatisch aangepast.
    * Serverconsole-commando `jobsync` (of ESX-groep superadmin): schrijft de catalogus expliciet naar de database.
      Daarna de server herstarten (ESX laadt jobs alleen bij het opstarten).
    * Jobcentrum: burgers melden zich aan voor `public`-jobs (alleen grade 0) of stoppen ermee.
]]

local JC = JobsCfg.JobCenter
local byName = {}
for _, j in ipairs(JobsCfg.Catalog) do byName[j.name] = j end

--- Verwachte rijen uit de catalogus (met af-dienst-varianten)
function Jobs.catalogRows()
    local jobs, grades = {}, {}
    for _, j in ipairs(JobsCfg.Catalog) do
        local wl = j.whitelisted and 1 or 0
        jobs[#jobs + 1] = { name = j.name, label = j.label, whitelisted = wl }
        for i, g in ipairs(j.grades) do
            grades[#grades + 1] = { job = j.name, grade = i - 1, name = g.name, label = g.label, salary = g.salary }
        end
        if j.offDuty then
            local off = JobsCfg.OffDutyPrefix .. j.name
            jobs[#jobs + 1] = { name = off, label = j.label .. ' (af dienst)', whitelisted = wl }
            for i, g in ipairs(j.grades) do
                grades[#grades + 1] = { job = off, grade = i - 1, name = g.name, label = g.label, salary = 0 }
            end
        end
    end
    return jobs, grades
end

--- Lijst met verschillen tussen catalogus en database (leeg = gelijk)
function Jobs.catalogDiff()
    local jobs, grades = Jobs.catalogRows()
    local diffs = {}
    local dbJobs, dbGrades = {}, {}
    for _, r in ipairs(MySQL.query.await('SELECT name, label, whitelisted FROM jobs') or {}) do dbJobs[r.name] = r end
    for _, r in ipairs(MySQL.query.await('SELECT job_name, grade, name, label, salary FROM job_grades') or {}) do
        dbGrades[r.job_name .. ':' .. r.grade] = r
    end
    for _, j in ipairs(jobs) do
        local r = dbJobs[j.name]
        if not r then diffs[#diffs + 1] = ('job %s ontbreekt in de database'):format(j.name)
        elseif r.label ~= j.label or (tonumber(r.whitelisted) or 0) ~= j.whitelisted then
            diffs[#diffs + 1] = ('job %s: label/whitelist wijkt af'):format(j.name)
        end
    end
    for _, g in ipairs(grades) do
        local r = dbGrades[g.job .. ':' .. g.grade]
        if not r then diffs[#diffs + 1] = ('grade %s/%d ontbreekt'):format(g.job, g.grade)
        elseif r.name ~= g.name or r.label ~= g.label or tonumber(r.salary) ~= g.salary then
            diffs[#diffs + 1] = ('grade %s/%d (%s): DB %s €%s ≠ catalogus %s €%d'):format(g.job, g.grade, g.name, r.name, tostring(r.salary), g.name, g.salary)
        end
    end
    return diffs
end

--- Schrijft de catalogus naar de database (alleen jobs uit de catalogus worden aangeraakt)
function Jobs.catalogSync()
    local jobs, grades = Jobs.catalogRows()
    local names = {}
    for _, j in ipairs(jobs) do
        MySQL.insert.await('INSERT INTO jobs (name, label, whitelisted) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label), whitelisted = VALUES(whitelisted)',
            { j.name, j.label, j.whitelisted })
        names[#names + 1] = j.name
    end
    local marks = {}
    for i = 1, #names do marks[i] = '?' end
    MySQL.update.await(('DELETE FROM job_grades WHERE job_name IN (%s)'):format(table.concat(marks, ',')), names)
    for _, g in ipairs(grades) do
        MySQL.insert.await('INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { g.job, g.grade, g.name, g.label, g.salary, '{}', '{}' })
    end
    return #jobs, #grades
end

CreateThread(function()
    Wait(2000)
    local ok, diffs = pcall(Jobs.catalogDiff)
    if not ok then
        print('^3[rp_jobs]^7 Jobcatalogus kon niet met de database worden vergeleken (tabellen jobs/job_grades aanwezig?).')
    elseif #diffs > 0 then
        print(('^3[rp_jobs]^7 De jobs in de database wijken af van JobsCfg.Catalog (%d verschil/len):'):format(#diffs))
        for i = 1, math.min(#diffs, 8) do print('   - ' .. diffs[i]) end
        print('   Importeer sql/02_jobs_items.sql (na `python3 scripts/gen_jobs_sql.py`) of typ `jobsync` in de serverconsole, en herstart daarna de server.')
    end
end)

RegisterCommand('jobsync', function(source)
    if source ~= 0 then
        local x = ESX.GetPlayerFromId(source)
        if not x or x.getGroup() ~= 'superadmin' then return end
    end
    local nj, ng = Jobs.catalogSync()
    local who = source == 0 and 'Console' or exports.server_logs:Describe(source)
    exports.server_logs:Log('admin', 'Jobs gesynchroniseerd', ('%s schreef de jobcatalogus naar de database (%d jobs, %d grades). Herstart vereist.'):format(who, nj, ng))
    print(('^2[rp_jobs]^7 %d jobs en %d grades naar de database geschreven. HERSTART de server zodat ESX ze laadt.'):format(nj, ng))
end, false)

---------------------------------------------------------------------------
-- Jobcentrum
---------------------------------------------------------------------------
local lastChange = {}   -- [identifier] = GetGameTimer() (ms)

lib.callback.register('rp_jobs:jobcenter:list', function(source)
    if not Jobs.throttle(source, 'jclist', 700) then return nil end
    local x = ESX.GetPlayerFromId(source)
    if not x or not ServerCfg.PlayerNear(source, JC.coords, JC.distance + 6.0) then return nil end
    local list = {}
    for _, j in ipairs(JobsCfg.Catalog) do
        if j.public then list[#list + 1] = { name = j.name, label = j.label, info = j.info, salary = j.grades[1].salary } end
    end
    return { jobs = list, current = Jobs.jobName(x) }
end)

lib.callback.register('rp_jobs:jobcenter:apply', function(source, jobName)
    local x = ESX.GetPlayerFromId(source)
    if not x then return { ok = false, msg = 'jobs.invalid' } end
    if not Jobs.throttle(source, 'jcapply', 2000) then return { ok = false, msg = 'jobs.too_fast' } end
    if not ServerCfg.PlayerNear(source, JC.coords, JC.distance + 4.0) then return { ok = false, msg = 'jobs.too_far' } end
    if ServerCfg.InCombat(source) then return { ok = false, msg = 'jobs.in_pvp' } end

    local current = Jobs.jobName(x)
    local entry = byName[current] or byName[(current:gsub('^' .. JobsCfg.OffDutyPrefix, ''))]
    if entry and not entry.public then return { ok = false, msg = 'jobs.jc_locked' } end  -- politie/ambulance stoppen via hun bazen

    local target = jobName == 'unemployed' and 'unemployed' or byName[jobName]
    if not target or (target ~= 'unemployed' and not target.public) then return { ok = false, msg = 'jobs.invalid' } end
    if current == jobName then return { ok = false, msg = 'jobs.jc_already' } end
    if not ESX.GetJobs()[jobName] then return { ok = false, msg = 'jobs.duty_missing', param = jobName } end

    local now = GetGameTimer()
    local since = lastChange[x.identifier] and (now - lastChange[x.identifier]) / 1000
    if since and since < JC.minSecondsBetween then
        return { ok = false, msg = 'jobs.jc_wait', param = math.ceil(JC.minSecondsBetween - since) }
    end
    if Jobs.getDaily(x.identifier, 'jobchange').count >= JC.maxChangesPerDay then return { ok = false, msg = 'jobs.jc_daily' } end

    x.setJob(jobName, 0)
    lastChange[x.identifier] = now
    Jobs.addDaily(x.identifier, 'jobchange', 1, 0)
    exports.server_logs:Log('general', 'Baanwissel', ('%s: %s → %s'):format(exports.server_logs:Describe(source), current, jobName))
    return { ok = true, msg = jobName == 'unemployed' and 'jobs.jc_quit' or 'jobs.jc_hired', param = target ~= 'unemployed' and target.label or nil }
end)

CreateThread(function()
    while true do
        Wait(60 * 60 * 1000)
        local now = GetGameTimer()
        for id, t in pairs(lastChange) do if (now - t) / 1000 > JC.minSecondsBetween then lastChange[id] = nil end end
    end
end)
