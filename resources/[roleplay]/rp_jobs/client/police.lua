--[[ rp_jobs/client/police.lua – /politie-menu, boeien, fouilleren, begeleiden, boete ]]

local T = ServerCfg.T
local cuffed = false
local escortedBy = nil

---------------------------------------------------------------------------
-- Acties van de agent
---------------------------------------------------------------------------
local function act(action, extra)
    local target = Interact.closestPlayer(JobsCfg.Police.actionDistance)
    if not target then
        RPJ.notify('error', 'jobs.no_target')
        return
    end
    local res = lib.callback.await('rp_jobs:police:action', false, action, target, extra)
    if action == 'search' and res and res.ok and res.data then
        local d = res.data
        local lines = { ('**%s:** €%d  \n**%s:** €%d  \n'):format(T('jobs.search_cash'), d.cash, T('jobs.search_black'), d.black) }
        lines[#lines + 1] = '\n**' .. T('jobs.search_items') .. '**  \n'
        if #d.items == 0 then lines[#lines + 1] = '-  \n' end
        for _, i in ipairs(d.items) do lines[#lines + 1] = ('%dx %s  \n'):format(i.count, i.label) end
        lines[#lines + 1] = '\n**' .. T('jobs.search_weapons') .. '**  \n'
        if #d.weapons == 0 then lines[#lines + 1] = '-  \n' end
        for _, w in ipairs(d.weapons) do lines[#lines + 1] = ('%s (%d)  \n'):format(w.label, w.ammo) end
        lib.alertDialog({ header = T('jobs.search_title'), content = table.concat(lines), centered = true, size = 'md' })
    else
        RPJ.result(res)
    end
end

local function fineDialog()
    local input = lib.inputDialog(T('jobs.fine_title'), {
        { type = 'number', label = T('jobs.fine_amount'), min = 1, max = JobsCfg.Police.maxFine, required = true },
        { type = 'input', label = T('jobs.fine_reason'), required = true, max = 80 },
    })
    if input then act('fine', { amount = input[1], reason = input[2] }) end
end

local function openMenu()
    if RPJ.jobName() ~= JobsCfg.Police.job then
        RPJ.notify('error', 'jobs.not_police')
        return
    end
    lib.registerContext({
        id = 'rp_police_menu',
        title = T('jobs.police_menu'),
        options = {
            { title = T('jobs.act_cuff'),   icon = 'handcuffs',  onSelect = function() act('cuff') end },
            { title = T('jobs.act_uncuff'), icon = 'unlock',     onSelect = function() act('uncuff') end },
            { title = T('jobs.act_search'), icon = 'magnifying-glass', onSelect = function() act('search') end },
            { title = T('jobs.act_escort'), icon = 'person-walking-arrow-right', onSelect = function() act('escort') end },
            { title = T('jobs.act_fine'),   icon = 'file-invoice-dollar', onSelect = fineDialog },
        },
    })
    lib.showContext('rp_police_menu')
end

RegisterCommand('politie', openMenu, false)
RegisterCommand('boei', function() act('cuff') end, false)
RegisterCommand('ontboei', function() act('uncuff') end, false)
RegisterCommand('fouilleer', function() act('search') end, false)
TriggerEvent('chat:addSuggestion', '/politie', T('jobs.cmd_police'))

---------------------------------------------------------------------------
-- Geboeid zijn (op de verdachte)
---------------------------------------------------------------------------
local function loadAnim(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
end

RegisterNetEvent('rp_jobs:setCuffed', function(state)
    cuffed = state
    local ped = PlayerPedId()
    if state then
        loadAnim('mp_arresting')
        SetEnableHandcuffs(ped, true)
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0.0, false, false, false)
        RPJ.notify('error', 'jobs.you_cuffed')
    else
        SetEnableHandcuffs(ped, false)
        ClearPedTasks(ped)
        RPJ.notify('success', 'jobs.you_uncuffed')
    end
end)

RegisterNetEvent('rp_jobs:escort', function(copSrc)
    local ped = PlayerPedId()
    escortedBy = copSrc
    if copSrc then
        local idx = GetPlayerFromServerId(copSrc)
        if idx ~= -1 then
            AttachEntityToEntity(ped, GetPlayerPed(idx), 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0,
                false, false, false, false, 2, true)
        end
    else
        DetachEntity(ped, true, false)
    end
end)

CreateThread(function()
    while true do
        if cuffed then
            Wait(0)
            local ped = PlayerPedId()
            for _, control in ipairs({ 21, 22, 23, 24, 25, 36, 44, 47, 58, 59, 63, 64, 71, 72, 140, 141, 142, 143, 257, 263, 264 }) do
                DisableControlAction(0, control, true)
            end
            if not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) and not IsEntityDead(ped) then
                loadAnim('mp_arresting')
                TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0.0, false, false, false)
            end
        else
            Wait(500)
        end
    end
end)

-- Opruimen bij herstart van de resource
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    SetEnableHandcuffs(ped, false)
    DetachEntity(ped, true, false)
end)
