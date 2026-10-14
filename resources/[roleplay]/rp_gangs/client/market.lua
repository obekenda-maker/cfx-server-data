--[[ rp_gangs/client/market.lua – zwarte markt, illegale activiteiten, hehler ]]

local T = ServerCfg.T
local function notify(kind, key, ...) ServerCfg.Notify(nil, kind, key, ...) end
local function result(res)
    if res and res.msg then notify(res.ok and 'success' or 'error', res.msg, res.param) end
    return res and res.ok
end

local function itemLabel(name)
    for _, i in ipairs(ESX.GetPlayerData().inventory or {}) do
        if i.name == name then return i.label end
    end
    return name
end

local function openMarket()
    local info = lib.callback.await('rp_gangs:market:info', false)
    if not info or not info.ok then
        result(info)
        return
    end
    local options = {}
    for _, i in ipairs(info.items) do
        options[#options + 1] = {
            title = i.label, description = T('gang.market_line', i.price, i.left), icon = 'toolbox', disabled = i.left < 1,
            onSelect = function()
                local input = lib.inputDialog(i.label, { { type = 'number', label = T('shop.count'), default = 1, min = 1, max = math.max(i.left, 1), required = true } })
                if input then result(lib.callback.await('rp_gangs:market:buy', false, 'item', i.key, input[1])) end
            end,
        }
    end
    for _, w in ipairs(info.weapons) do
        local locked = info.needTerritory and not info.hasTerritory
        options[#options + 1] = {
            title = w.label, icon = 'gun', disabled = w.left < 1 or locked,
            description = locked and T('gang.market_need_territory') or T('gang.market_line', w.price, w.left),
            onSelect = function() result(lib.callback.await('rp_gangs:market:buy', false, 'weapon', w.key, 1)) end,
        }
    end
    lib.registerContext({ id = 'rp_blackmarket', title = GangCfg.BlackMarket.label, options = options })
    lib.showContext('rp_blackmarket')
end

local function runActivity(act)
    local res = lib.callback.await('rp_gangs:activity:start', false, act.id)
    if not res or not res.ok then result(res) return end
    local done = lib.progressBar({
        duration = res.seconds * 1000, label = T('gang.activity_progress', act.label),
        canCancel = true, disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@prop_human_bum_bin@base', clip = 'base', flag = 1 },
    })
    if done then result(lib.callback.await('rp_gangs:activity:finish', false, act.id)) end
end

local function openFence()
    local F = GangCfg.Fence
    local options = {}
    for item, price in pairs(F.prices) do
        options[#options + 1] = {
            title = itemLabel(item), description = T('gang.fence_line', price), icon = 'sack-dollar',
            onSelect = function()
                local input = lib.inputDialog(itemLabel(item), { { type = 'number', label = T('shop.count'), default = 1, min = 1, max = 100, required = true } })
                if input then result(lib.callback.await('rp_gangs:fence:sell', false, item, input[1])) end
            end,
        }
    end
    lib.registerContext({ id = 'rp_fence', title = F.label, options = options })
    lib.showContext('rp_fence')
end

CreateThread(function()
    local bm = GangCfg.BlackMarket
    Interact.point({
        coords = bm.coords, distance = bm.distance, label = T('gang.market_prompt'),
        marker = { type = 1, r = 155, g = 89, b = 182, a = 90 }, onUse = openMarket,
        canUse = function() return LocalPlayer.state.gangId ~= nil and LocalPlayer.state.gangId > 0 end,
    })
    for _, act in ipairs(GangCfg.Activities) do
        Interact.point({
            coords = act.coords, distance = act.distance, label = T('gang.activity_prompt', act.label),
            marker = { type = 1, r = 231, g = 76, b = 60, a = 80 }, onUse = function() runActivity(act) end,
        })
    end
    local f = GangCfg.Fence
    Interact.point({
        coords = f.coords, distance = f.distance, label = T('gang.fence_prompt'),
        marker = { type = 1, r = 241, g = 196, b = 15, a = 80 }, onUse = openFence,
    })
end)
