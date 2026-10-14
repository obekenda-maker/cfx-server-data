--[[
    rp_jobs/server/main.lua – gedeelde helpers, dienst in/uit, societies, dagelijkse limieten.

    Exports:
        exports.rp_jobs:GetDaily(identifier, action)        -> { count, amount }
        exports.rp_jobs:AddDaily(identifier, action, count, amount)
        exports.rp_jobs:IsOnDutyJob(src, jobName)           -> bool
]]

Jobs = {}

local function today() return os.date('%Y-%m-%d') end

function Jobs.coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

function Jobs.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- Afstand tussen twee spelers (server-coördinaten) of nil
function Jobs.playerDistance(a, b)
    local ca, cb = Jobs.coordsOf(a), Jobs.coordsOf(b)
    if not ca or not cb then return nil end
    return Jobs.dist(ca, cb)
end

function Jobs.jobName(xPlayer)
    local job = xPlayer.job or (xPlayer.getJob and xPlayer.getJob())
    return job and job.name or 'unemployed'
end

--- Rate-limit per speler+sleutel (ms)
local last = {}
function Jobs.throttle(src, key, ms)
    local id = src .. ':' .. key
    local now = GetGameTimer()
    if (last[id] or -1e9) + ms > now then return false end
    last[id] = now
    return true
end

AddEventHandler('playerDropped', function()
    local prefix = source .. ':'
    for k in pairs(last) do
        if k:sub(1, #prefix) == prefix then last[k] = nil end
    end
end)

--- Geld overmaken / pakken helpers -----------------------------------------
--- Haalt `amount` bij een speler: eerst contant, dan bank. Geeft werkelijk afgeschreven bedrag.
function Jobs.charge(xPlayer, amount, reason)
    amount = math.floor(amount)
    if amount <= 0 then return 0 end
    local cash = xPlayer.getMoney()
    local fromCash = math.min(cash, amount)
    if fromCash > 0 then xPlayer.removeMoney(fromCash, reason) end
    local rest = amount - fromCash
    local fromBank = 0
    if rest > 0 then
        local bank = xPlayer.getAccount('bank').money
        fromBank = math.min(bank, rest)
        if fromBank > 0 then xPlayer.removeAccountMoney('bank', fromBank, reason) end
    end
    return fromCash + fromBank
end

--- Stort in een society-rekening (esx_addonaccount). Geeft true bij succes.
function Jobs.depositSociety(account, amount)
    if not account or amount <= 0 then return false end
    local done = false
    local ok = pcall(function()
        TriggerEvent('esx_addonaccount:getSharedAccount', account, function(acc)
            if acc then
                acc.addMoney(amount)
                done = true
            end
        end)
    end)
    return ok and done
end

---------------------------------------------------------------------------
-- Dagelijkse limieten (tabel rp_cooldowns)
---------------------------------------------------------------------------
local function getDaily(identifier, action)
    local row = MySQL.single.await(
        'SELECT `count`, `amount` FROM rp_cooldowns WHERE identifier = ? AND `action` = ? AND `day` = ?',
        { identifier, action, today() })
    if row then return { count = row.count, amount = row.amount } end
    return { count = 0, amount = 0 }
end

local function addDaily(identifier, action, count, amount)
    MySQL.insert.await(
        'INSERT INTO rp_cooldowns (identifier, `action`, `day`, `count`, `amount`) VALUES (?, ?, ?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `count` = `count` + VALUES(`count`), `amount` = `amount` + VALUES(`amount`)',
        { identifier, action, today(), count or 0, amount or 0 })
end

exports('GetDaily', getDaily)
exports('AddDaily', addDaily)
exports('IsOnDutyJob', function(src, jobName)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer ~= nil and Jobs.jobName(xPlayer) == jobName
end)
Jobs.getDaily, Jobs.addDaily = getDaily, addDaily

-- Oude dagregels opruimen
CreateThread(function()
    Wait(20000)
    pcall(function() MySQL.update('DELETE FROM rp_cooldowns WHERE `day` < (CURDATE() - INTERVAL 7 DAY)') end)
end)

---------------------------------------------------------------------------
-- Societies registreren bij esx_society
---------------------------------------------------------------------------
CreateThread(function()
    Wait(3000) -- esx_society moet gestart zijn
    for _, s in ipairs(JobsCfg.Societies) do
        local account = 'society_' .. s.job
        TriggerEvent('esx_society:registerSociety', s.job, s.label, account, account, account, { type = s.type })
    end
end)

---------------------------------------------------------------------------
-- Dienst in/uit (server beslist; afstand wordt server-side gecontroleerd)
---------------------------------------------------------------------------
lib.callback.register('rp_jobs:toggleDuty', function(source, index)
    index = tonumber(index)
    local duty = index and JobsCfg.Duty[index]
    if not duty then return { ok = false, msg = 'jobs.duty_invalid' } end
    if not Jobs.throttle(source, 'duty', 2000) then return { ok = false, msg = 'jobs.too_fast' } end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { ok = false, msg = 'jobs.duty_invalid' } end

    local c = Jobs.coordsOf(source)
    if not c or Jobs.dist(c, duty.coords) > JobsCfg.DutyDistance + 4.0 then
        return { ok = false, msg = 'jobs.too_far' }
    end

    local current = xPlayer.job
    local offName = JobsCfg.OffDutyPrefix .. duty.job
    local jobs = ESX.GetJobs()
    local newName
    if current.name == duty.job then
        newName = offName
    elseif current.name == offName then
        newName = duty.job
    else
        return { ok = false, msg = 'jobs.not_employee', param = duty.label }
    end

    local grade = tonumber(current.grade) or 0
    if not jobs[newName] or not jobs[newName].grades[tostring(grade)] then
        return { ok = false, msg = 'jobs.duty_missing', param = newName }
    end
    xPlayer.setJob(newName, grade)

    local onDuty = newName == duty.job
    exports.server_logs:Log('general', onDuty and 'Dienst begonnen' or 'Dienst beëindigd',
        ('%s – %s'):format(exports.server_logs:Describe(source), duty.label))
    return { ok = true, onDuty = onDuty, msg = onDuty and 'jobs.duty_on' or 'jobs.duty_off', param = duty.label }
end)
