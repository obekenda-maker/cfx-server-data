--[[ rp_interactions/server/main.lua ]]

local throttle = ServerCfg.Throttle
local coordsOf = ServerCfg.CoordsOf
local distance = ServerCfg.PlayerDistance
local inCombat = ServerCfg.InCombat

--- Tekst opschonen: geen besturingstekens, beperkte lengte
local function clean(text)
    text = tostring(text or ''):gsub('[%c]', ' ')
    text = ServerCfg.Trim(text)
    return text:sub(1, InterCfg.ChatMaxLength)
end

local function nearbyPlayers(src, radius)
    local out = {}
    local origin = coordsOf(src)
    if not origin then return out end
    for _, id in ipairs(ESX.GetPlayers()) do
        id = tonumber(id)
        local c = coordsOf(id)
        if c and math.sqrt((c.x - origin.x) ^ 2 + (c.y - origin.y) ^ 2 + (c.z - origin.z) ^ 2) <= radius then
            out[#out + 1] = id
        end
    end
    return out
end

local function sayNearby(src, kind, text)
    text = clean(text)
    if text == '' then return end
    if not throttle(src, 'chat', InterCfg.ChatCooldownMs) then
        ServerCfg.Notify(src, 'error', 'inter.too_fast')
        return
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    local name = xPlayer and xPlayer.getName() or GetPlayerName(src)
    for _, target in ipairs(nearbyPlayers(src, InterCfg.ChatRadius)) do
        TriggerClientEvent('rp_interactions:show', target, src, kind, text, name)
    end
end

RegisterCommand('me', function(source, args)
    if source == 0 then return end
    sayNearby(source, 'me', table.concat(args, ' '))
end, false)

RegisterCommand('do', function(source, args)
    if source == 0 then return end
    sayNearby(source, 'do', table.concat(args, ' '))
end, false)

---------------------------------------------------------------------------
-- /id – toon je ID-kaart aan mensen dichtbij
---------------------------------------------------------------------------
RegisterCommand('id', function(source)
    if source == 0 then return end
    local x = ESX.GetPlayerFromId(source)
    if not x then return end
    if not throttle(source, 'id', 3000) then return end

    local function get(key, default)
        local ok, v = pcall(function() return x.get(key) end)
        if ok and v ~= nil and v ~= '' then return v end
        return default
    end
    local card = {
        name = x.getName(),
        dob = get('dateofbirth', '?'),
        sex = get('sex', '?'),
        height = get('height', '?'),
    }
    for _, target in ipairs(nearbyPlayers(source, InterCfg.IdRadius)) do
        TriggerClientEvent('rp_interactions:showId', target, card, target == source)
    end
end, false)

---------------------------------------------------------------------------
-- Geven: contant geld en items. Alles server-side gevalideerd.
---------------------------------------------------------------------------
local function resolveTarget(source, targetArg)
    local target = tonumber(targetArg)
    if not target or target == source then return nil, 'inter.no_target' end
    local xTarget = ESX.GetPlayerFromId(target)
    if not xTarget then return nil, 'inter.no_target' end
    local d = distance(source, target)
    if not d or d > InterCfg.GiveDistance then return nil, 'inter.too_far' end
    if inCombat(source) or inCombat(target) then return nil, 'inter.in_combat' end
    return xTarget, nil, target
end

RegisterCommand('geefgeld', function(source, args)
    if source == 0 then return end
    local xFrom = ESX.GetPlayerFromId(source)
    if not xFrom then return end
    if not throttle(source, 'give', InterCfg.GiveCooldownMs) then return ServerCfg.Notify(source, 'error', 'inter.too_fast') end

    local xTo, err, target = resolveTarget(source, args[1])
    if not xTo then return ServerCfg.Notify(source, 'error', err) end

    local amount = math.floor(tonumber(args[2]) or 0)
    if amount < 1 or amount > InterCfg.GiveMaxMoney then
        return ServerCfg.Notify(source, 'error', 'inter.amount_invalid', InterCfg.GiveMaxMoney)
    end
    if xFrom.getMoney() < amount then return ServerCfg.Notify(source, 'error', 'inter.no_money') end

    xFrom.removeMoney(amount, 'Gegeven aan speler')
    xTo.addMoney(amount, 'Ontvangen van speler')
    ServerCfg.Notify(source, 'success', 'inter.gave_money', amount, xTo.getName())
    ServerCfg.Notify(target, 'success', 'inter.got_money', amount, xFrom.getName())
    if amount >= InterCfg.GiveLogOver then
        exports.server_logs:Log('money', 'Geld gegeven', ('%s gaf €%d contant aan %s'):format(
            exports.server_logs:Describe(source), amount, exports.server_logs:Describe(target)))
    end
end, false)

RegisterCommand('geefitem', function(source, args)
    if source == 0 then return end
    local xFrom = ESX.GetPlayerFromId(source)
    if not xFrom then return end
    if not throttle(source, 'give', InterCfg.GiveCooldownMs) then return ServerCfg.Notify(source, 'error', 'inter.too_fast') end

    local xTo, err, target = resolveTarget(source, args[1])
    if not xTo then return ServerCfg.Notify(source, 'error', err) end

    local item = tostring(args[2] or '')
    local count = math.floor(tonumber(args[3]) or 1)
    if item == '' or count < 1 or count > InterCfg.GiveMaxItems then return ServerCfg.Notify(source, 'error', 'inter.item_invalid') end

    local have = xFrom.getInventoryItem(item)
    if not have or have.count < count then return ServerCfg.Notify(source, 'error', 'inter.no_item') end
    if not xTo.canCarryItem(item, count) then return ServerCfg.Notify(source, 'error', 'inter.cannot_carry') end

    xFrom.removeInventoryItem(item, count)
    xTo.addInventoryItem(item, count)
    ServerCfg.Notify(source, 'success', 'inter.gave_item', count, have.label or item, xTo.getName())
    ServerCfg.Notify(target, 'success', 'inter.got_item', count, have.label or item, xFrom.getName())
end, false)

