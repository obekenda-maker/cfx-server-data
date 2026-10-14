--[[
    rp_gangs/server/market.lua – zwarte markt (wapenhandel), illegale activiteiten en hehler.
    Regels staan in config.lua. Daglimieten worden bewaard in rp_cooldowns (via rp_jobs-exports).
]]

local BM, Fence = GangCfg.BlackMarket, GangCfg.Fence
local inCombat = ServerCfg.InCombat
local pay = ServerCfg.Pay
local activeActivity = {}    -- [source] = { id, startedAt }
local activityCooldown = {}  -- ["identifier:id"] = os.time() waarvoor weer mag
local purchaseAt = {}        -- [source] = GetGameTimer()

--- Alle daglimieten van een speler voor vandaag in één query: { [action] = {count, amount} }
local function dailyAll(identifier)
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT `action`, `count`, `amount` FROM rp_cooldowns WHERE identifier = ? AND `day` = ?',
            { identifier, os.date('%Y-%m-%d') })
    end)
    local out = {}
    for _, r in ipairs(ok and rows or {}) do out[r.action] = { count = r.count, amount = r.amount } end
    return out
end

local function daily(identifier, action)
    local ok, d = pcall(function() return exports.rp_jobs:GetDaily(identifier, action) end)
    if ok and d then return d end
    return { count = 9999, amount = 9999 }   -- bij twijfel: geen verkoop
end

local function addDaily(identifier, action, count, amount)
    pcall(function() exports.rp_jobs:AddDaily(identifier, action, count, amount) end)
end

local function policeOnDuty()
    local n = 0
    for _, id in ipairs(ESX.GetPlayers()) do
        local x = ESX.GetPlayerFromId(tonumber(id))
        if x and x.job and x.job.name == 'police' then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Zwarte markt
---------------------------------------------------------------------------
lib.callback.register('rp_gangs:market:info', function(source)
    local gang = Gang.of(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not gang or not xPlayer then return { ok = false, msg = 'gang.market_members_only' } end
    if not Gang.can(source, 'blackmarket') then return { ok = false, msg = 'gang.no_permission' } end
    if not Gang.near(source, BM.coords, BM.distance + 6.0) then return { ok = false, msg = 'gang.too_far' } end

    local items, weapons = {}, {}
    local used = dailyAll(xPlayer.identifier)
    local function usedCount(key) return used['bm:' .. key] and used['bm:' .. key].count or 0 end
    for _, i in ipairs(BM.items) do
        items[#items + 1] = { key = i.item, label = i.label, price = i.price, left = math.max(0, i.dailyLimit - usedCount(i.item)) }
    end
    for _, w in ipairs(BM.weapons) do
        weapons[#weapons + 1] = { key = w.weapon, label = w.label, price = w.price, left = math.max(0, w.dailyLimit - usedCount(w.weapon)) }
    end
    return { ok = true, items = items, weapons = weapons, account = BM.account,
             hasTerritory = Gang.hasTerritory(gang.id), needTerritory = BM.needTerritory }
end)

lib.callback.register('rp_gangs:market:buy', function(source, kind, key, count)
    local gang = Gang.of(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not gang or not xPlayer then return { ok = false, msg = 'gang.market_members_only' } end
    if not Gang.can(source, 'blackmarket') then return { ok = false, msg = 'gang.no_permission' } end
    if not Gang.near(source, BM.coords, BM.distance + 4.0) then return { ok = false, msg = 'gang.too_far' } end
    if inCombat(source) then return { ok = false, msg = 'gang.in_combat' } end

    local now = GetGameTimer()
    if purchaseAt[source] and now - purchaseAt[source] < BM.purchaseCooldownSeconds * 1000 then
        return { ok = false, msg = 'gang.market_cooldown' }
    end

    local entry, isWeapon
    if kind == 'weapon' then
        for _, w in ipairs(BM.weapons) do if w.weapon == key then entry, isWeapon = w, true end end
    elseif kind == 'item' then
        for _, i in ipairs(BM.items) do if i.item == key then entry = i end end
    end
    if not entry then return { ok = false, msg = 'gang.invalid' } end

    if isWeapon and BM.needTerritory and not Gang.hasTerritory(gang.id) then
        return { ok = false, msg = 'gang.market_need_territory' }
    end

    count = isWeapon and 1 or math.floor(tonumber(count) or 1)
    if count < 1 or count > 20 then return { ok = false, msg = 'gang.invalid' } end

    local action = 'bm:' .. (isWeapon and entry.weapon or entry.item)
    local d = daily(xPlayer.identifier, action)
    if d.count + count > entry.dailyLimit then return { ok = false, msg = 'gang.market_daily' } end

    if isWeapon then
        if xPlayer.hasWeapon(entry.weapon) then return { ok = false, msg = 'gang.have_weapon' } end
    else
        if not xPlayer.canCarryItem(entry.item, count) then return { ok = false, msg = 'gang.cannot_carry' } end
    end

    local total = entry.price * count
    if not pay(xPlayer, BM.account, total, 'Zwarte markt') then return { ok = false, msg = 'gang.no_money', param = total } end

    if isWeapon then xPlayer.addWeapon(entry.weapon, entry.ammo) else xPlayer.addInventoryItem(entry.item, count) end
    addDaily(xPlayer.identifier, action, count, total)
    purchaseAt[source] = now

    local what = isWeapon and entry.weapon or (count .. 'x ' .. entry.item)
    exports.server_logs:Log('money', 'Zwarte markt aankoop', ('%s (%s) kocht %s voor €%d (%s)'):format(
        exports.server_logs:Describe(source), gang.label, what, total, BM.account))
    Gang.log('Zwarte markt', ('%s (%s) kocht %s'):format(exports.server_logs:Describe(source), gang.label, what))
    return { ok = true, msg = 'gang.market_bought' }
end)

---------------------------------------------------------------------------
-- Illegale activiteiten
---------------------------------------------------------------------------
local function activityById(id)
    for _, a in ipairs(GangCfg.Activities) do if a.id == id then return a end end
    return nil
end

lib.callback.register('rp_gangs:activity:start', function(source, id)
    local act = activityById(id)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not act or not xPlayer then return { ok = false, msg = 'gang.invalid' } end
    if not Gang.near(source, act.coords, act.distance + 3.0) then return { ok = false, msg = 'gang.too_far' } end
    if inCombat(source) then return { ok = false, msg = 'gang.in_combat' } end
    if policeOnDuty() < act.minPolice then return { ok = false, msg = 'gang.need_police', param = act.minPolice } end

    local cdKey = xPlayer.identifier .. ':' .. act.id
    if (activityCooldown[cdKey] or 0) > os.time() then return { ok = false, msg = 'gang.activity_cooldown' } end
    if daily(xPlayer.identifier, 'act:' .. act.id).count >= act.dailyLimit then return { ok = false, msg = 'gang.market_daily' } end
    if not xPlayer.canCarryItem(act.item, act.count) then return { ok = false, msg = 'gang.cannot_carry' } end

    activeActivity[source] = { id = act.id, startedAt = GetGameTimer() }
    return { ok = true, seconds = act.seconds }
end)

lib.callback.register('rp_gangs:activity:finish', function(source, id)
    local act = activityById(id)
    local run = activeActivity[source]
    local xPlayer = ESX.GetPlayerFromId(source)
    if not act or not run or run.id ~= id or not xPlayer then return { ok = false, msg = 'gang.invalid' } end
    activeActivity[source] = nil

    if GetGameTimer() - run.startedAt < act.seconds * 1000 - 1500 then
        exports.server_logs:Log('suspicious', 'Te snelle activiteit', ('%s voltooide %s sneller dan mogelijk'):format(
            exports.server_logs:Describe(source), act.id))
        return { ok = false, msg = 'gang.invalid' }
    end
    if not Gang.near(source, act.coords, act.distance + 4.0) then return { ok = false, msg = 'gang.too_far' } end
    if not xPlayer.canCarryItem(act.item, act.count) then return { ok = false, msg = 'gang.cannot_carry' } end

    xPlayer.addInventoryItem(act.item, act.count)
    addDaily(xPlayer.identifier, 'act:' .. act.id, 1, act.count)
    activityCooldown[xPlayer.identifier .. ':' .. act.id] = os.time() + act.cooldownSeconds
    return { ok = true, msg = 'gang.activity_done', param = act.count }
end)

---------------------------------------------------------------------------
-- Hehler: illegale spullen → zwart geld (met daglimiet)
---------------------------------------------------------------------------
lib.callback.register('rp_gangs:fence:sell', function(source, item, count)
    local xPlayer = ESX.GetPlayerFromId(source)
    local price = type(item) == 'string' and Fence.prices[item]
    if not xPlayer or not price then return { ok = false, msg = 'gang.invalid' } end
    if not Gang.near(source, Fence.coords, Fence.distance + 3.0) then return { ok = false, msg = 'gang.too_far' } end
    if inCombat(source) then return { ok = false, msg = 'gang.in_combat' } end
    count = math.floor(tonumber(count) or 0)
    if count < 1 or count > 100 then return { ok = false, msg = 'gang.invalid' } end

    local have = xPlayer.getInventoryItem(item)
    if not have or have.count < count then return { ok = false, msg = 'gang.no_item' } end

    local d = daily(xPlayer.identifier, 'fence')
    local room = Fence.dailyAmountCap - d.amount
    local sellCount = math.min(count, math.floor(room / price))
    if sellCount < 1 then return { ok = false, msg = 'gang.fence_cap' } end

    local total = sellCount * price
    xPlayer.removeInventoryItem(item, sellCount)
    if Fence.account == 'money' then xPlayer.addMoney(total, 'Hehler') else xPlayer.addAccountMoney(Fence.account, total, 'Hehler') end
    addDaily(xPlayer.identifier, 'fence', sellCount, total)
    exports.server_logs:Log('money', 'Hehler verkoop', ('%s verkocht %dx %s voor €%d (%s)'):format(
        exports.server_logs:Describe(source), sellCount, item, total, Fence.account))
    return { ok = true, msg = 'gang.fence_sold', param = total }
end)

-- Geheugen: verlopen activiteit-cooldowns opruimen (elk uur)
CreateThread(function()
    while true do
        Wait(3600 * 1000)
        local now = os.time()
        for key, untilT in pairs(activityCooldown) do
            if untilT <= now then activityCooldown[key] = nil end
        end
    end
end)

AddEventHandler('playerDropped', function()
    activeActivity[source], purchaseAt[source] = nil, nil
end)
