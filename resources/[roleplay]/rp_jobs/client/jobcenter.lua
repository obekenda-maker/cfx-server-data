--[[ rp_jobs/client/jobcenter.lua – Jobcentrum (aanmelden/stoppen) en /baan (uitleg bij je huidige baan) ]]

local T = ServerCfg.T
local JC = JobsCfg.JobCenter

local function openJobCenter()
    local data = lib.callback.await('rp_jobs:jobcenter:list', false)
    if not data then return end
    local options = {}
    for _, j in ipairs(data.jobs) do
        options[#options + 1] = {
            title = j.label, icon = 'briefcase', disabled = (data.current == j.name),
            description = T('jobs.jc_line', j.salary, T(j.info .. '_short')),
            onSelect = function()
                local answer = lib.alertDialog({
                    header = j.label, content = T(j.info), centered = true, cancel = true, size = 'lg',
                    labels = { confirm = T('jobs.jc_apply'), cancel = T('jobs.jc_back') },
                })
                if answer == 'confirm' then RPJ.result(lib.callback.await('rp_jobs:jobcenter:apply', false, j.name)) end
            end,
        }
    end
    options[#options + 1] = {
        title = T('jobs.jc_quit_title'), icon = 'right-from-bracket', disabled = (data.current == 'unemployed'),
        onSelect = function() RPJ.result(lib.callback.await('rp_jobs:jobcenter:apply', false, 'unemployed')) end,
    }
    lib.registerContext({ id = 'rp_jobcenter', title = JC.label, options = options })
    lib.showContext('rp_jobcenter')
end

CreateThread(function()
    Interact.blip({ coords = JC.coords, sprite = JC.blip.sprite, colour = JC.blip.colour, label = JC.label })
    Interact.point({
        coords = JC.coords, distance = JC.distance, label = T('jobs.jc_prompt', JC.label),
        marker = { type = 1, r = 46, g = 204, b = 113, a = 90 }, onUse = openJobCenter,
    })
end)

--- Uitleg bij je huidige baan (ook voor 'af dienst'-varianten en werklozen)
RegisterCommand('baan', function()
    local name = RPJ.jobName() or 'unemployed'
    local base = name:gsub('^' .. JobsCfg.OffDutyPrefix, '')
    local key = 'jobs.info_unemployed'
    for _, j in ipairs(JobsCfg.Catalog) do
        if j.name == base then key = j.info end
    end
    local job = ESX.GetPlayerData().job
    lib.alertDialog({
        header = T('jobs.info_header', (job and job.label) or T('hud.job_none'), (job and job.grade_label) or ''),
        content = T(key), centered = true, size = 'lg',
    })
end, false)
TriggerEvent('chat:addSuggestion', '/baan', T('jobs.cmd_job'))
