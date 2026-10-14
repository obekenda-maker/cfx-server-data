--[[
    rp_jobs/server/police.lua – boeien, fouilleren, begeleiden, boetes.
    Alle acties: agent moet job 'police' hebben (op dienst) en binnen afstand staan (server-coördinaten).
]]

local P = JobsCfg.Police

local function stateBag(src)
    local ok, bag = pcall(function() return Player(src).state end)
    return ok and bag or nil
end

local function validate(source, targetId)
    local xCop = ESX.GetPlayerFromId(source)
    if not xCop or Jobs.jobName(xCop) ~= P.job then return nil, 'jobs.not_police' end
    targetId = tonumber(targetId)
    if not targetId or targetId == source then return nil, 'jobs.no_target' end
    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return nil, 'jobs.no_target' end
    local d = Jobs.playerDistance(source, targetId)
    if not d or d > P.actionDistance then return nil, 'jobs.too_far' end
    return xCop, nil, xTarget, targetId
end

local function inventorySummary(xTarget)
    local items = {}
    local inv = xTarget.getInventory()
    for _, item in ipairs(inv or {}) do
        if (item.count or 0) > 0 then items[#items + 1] = { label = item.label or item.name, count = item.count } end
    end
    local weapons = {}
    for _, w in ipairs(xTarget.getLoadout() or {}) do
        weapons[#weapons + 1] = { label = w.label or w.name, ammo = w.ammo or 0 }
    end
    return {
        cash = xTarget.getMoney(),
        black = (xTarget.getAccount('black_money') or { money = 0 }).money,
        items = items, weapons = weapons,
    }
end

lib.callback.register('rp_jobs:police:action', function(source, action, targetId, extra)
    if type(action) ~= 'string' then return { ok = false, msg = 'jobs.invalid' } end
    if not Jobs.throttle(source, 'police', 800) then return { ok = false, msg = 'jobs.too_fast' } end

    local xCop, err, xTarget, target = validate(source, targetId)
    if not xCop then return { ok = false, msg = err } end
    local bag = stateBag(target)

    if action == 'cuff' then
        if bag and bag.isCuffed then return { ok = false, msg = 'jobs.already_cuffed' } end
        if bag then bag:set('isCuffed', true, true) end
        -- uit PvP halen als de verdachte meedeed
        pcall(function() exports.combat_core:ForceLeave(target, 'combat.left_forced') end)
        TriggerClientEvent('rp_jobs:setCuffed', target, true)
        exports.server_logs:Log('general', 'Geboeid', ('%s boeide %s'):format(
            exports.server_logs:Describe(source), exports.server_logs:Describe(target)))
        return { ok = true, msg = 'jobs.cuffed_ok' }

    elseif action == 'uncuff' then
        if not (bag and bag.isCuffed) then return { ok = false, msg = 'jobs.not_cuffed' } end
        bag:set('isCuffed', false, true)
        bag:set('escortedBy', nil, true)
        TriggerClientEvent('rp_jobs:setCuffed', target, false)
        TriggerClientEvent('rp_jobs:escort', target, nil)
        return { ok = true, msg = 'jobs.uncuffed_ok' }

    elseif action == 'search' then
        if P.searchRequiresCuffs and not (bag and bag.isCuffed) then return { ok = false, msg = 'jobs.search_needs_cuffs' } end
        exports.server_logs:Log('general', 'Fouillering', ('%s fouilleerde %s'):format(
            exports.server_logs:Describe(source), exports.server_logs:Describe(target)))
        TriggerClientEvent('rp_jobs:notifyTarget', target, 'jobs.being_searched')
        return { ok = true, data = inventorySummary(xTarget) }

    elseif action == 'escort' then
        if not (bag and bag.isCuffed) then return { ok = false, msg = 'jobs.not_cuffed' } end
        local current = bag.escortedBy
        if current then
            bag:set('escortedBy', nil, true)
            TriggerClientEvent('rp_jobs:escort', target, nil)
            return { ok = true, msg = 'jobs.escort_stop' }
        end
        bag:set('escortedBy', source, true)
        TriggerClientEvent('rp_jobs:escort', target, source)
        return { ok = true, msg = 'jobs.escort_start' }

    elseif action == 'fine' then
        local amount = math.floor(tonumber(extra and extra.amount) or 0)
        local reason = tostring(extra and extra.reason or ''):sub(1, 80)
        if amount < 1 or amount > P.maxFine then return { ok = false, msg = 'jobs.fine_invalid', param = P.maxFine } end
        local charged = Jobs.charge(xTarget, amount, 'Boete: ' .. reason)
        if charged <= 0 then return { ok = false, msg = 'jobs.fine_no_money' } end
        Jobs.depositSociety(P.societyAccount, charged)
        ServerCfg.Notify(target, 'error', 'jobs.fined', charged, reason)
        exports.server_logs:Log('money', 'Politieboete', ('%s gaf %s een boete van €%d (%s)'):format(
            exports.server_logs:Describe(source), exports.server_logs:Describe(target), charged, reason))
        return { ok = true, msg = 'jobs.fine_ok', param = charged }
    end

    return { ok = false, msg = 'jobs.invalid' }
end)

-- Geboeid blijven na reconnect voorkomen: state bag verdwijnt met de speler; niets op te ruimen.
