--[[ rp_gangs/client/main.lua – /gang-menu, territoria en uitnodigingen ]]

local T = ServerCfg.T
local function notify(kind, key, ...) ServerCfg.Notify(nil, kind, key, ...) end
local function result(res)
    if res and res.msg then notify(res.ok and 'success' or 'error', res.msg, res.param) end
    return res and res.ok
end

---------------------------------------------------------------------------
-- Uitnodiging (server → client callback)
---------------------------------------------------------------------------
lib.callback.register('rp_gangs:confirmInvite', function(gangLabel, inviterName)
    local answer = lib.alertDialog({
        header = T('gang.invite_header'),
        content = T('gang.invite_content', inviterName, gangLabel),
        centered = true, cancel = true,
        labels = { confirm = T('gang.invite_yes'), cancel = T('gang.invite_no') },
    })
    return answer == 'confirm'
end)

---------------------------------------------------------------------------
-- Territoria (blips)
---------------------------------------------------------------------------
local territories = {}   -- [id] = { data, blips }

local function hexToRgb(hex)
    if type(hex) ~= 'string' or #hex ~= 7 then return 255, 255, 255 end
    return tonumber(hex:sub(2, 3), 16) or 255, tonumber(hex:sub(4, 5), 16) or 255, tonumber(hex:sub(6, 7), 16) or 255
end

local function clearBlips()
    for _, entry in pairs(territories) do
        for _, b in ipairs(entry.blips or {}) do if DoesBlipExist(b) then RemoveBlip(b) end end
    end
    territories = {}
end

local function applyTerritories(list)
    clearBlips()
    for _, t in ipairs(list or {}) do
        local blips = {}
        local radius = AddBlipForRadius(t.coords.x, t.coords.y, t.coords.z, t.radius)
        SetBlipAlpha(radius, GangCfg.Territory.blipAlpha)
        if t.ownerColor then
            SetBlipColour(radius, 0)
            local r, g, b = hexToRgb(t.ownerColor)
            SetBlipSecondaryColour(radius, r, g, b)
        else
            SetBlipColour(radius, 4)
        end
        blips[#blips + 1] = radius

        local center = AddBlipForCoord(t.coords.x, t.coords.y, t.coords.z)
        SetBlipSprite(center, t.war and 84 or 310)
        SetBlipScale(center, 0.8)
        SetBlipColour(center, t.war and 1 or 0)
        SetBlipAsShortRange(center, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(T('gang.blip_territory', t.label, t.ownerLabel or T('gang.unowned')))
        EndTextCommandSetBlipName(center)
        blips[#blips + 1] = center
        territories[t.id] = { data = t, blips = blips }
    end
end

RegisterNetEvent('rp_gangs:territories', applyTerritories)

AddEventHandler('esx:playerLoaded', function()
    applyTerritories(lib.callback.await('rp_gangs:getTerritories', false))
end)
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() and ESX.IsPlayerLoaded() then
        applyTerritories(lib.callback.await('rp_gangs:getTerritories', false))
    end
end)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearBlips() end
end)

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------
local openMenu

local function moneyInput(title, label, max)
    local input = lib.inputDialog(title, { { type = 'number', label = label, min = 1, max = max, required = true } })
    return input and input[1] or nil
end

local function memberMenu(info, member)
    local options = {}
    if info.perms.promote and member.grade < info.grade then
        for grade = 0, info.grade - 1 do
            if grade ~= member.grade then
                options[#options + 1] = {
                    title = T('gang.set_grade', GangCfg.Grades[grade].label), icon = 'arrow-up-wide-short',
                    onSelect = function()
                        result(lib.callback.await('rp_gangs:setGrade', false, member.identifier, grade))
                        openMenu()
                    end,
                }
            end
        end
    end
    if info.perms.kick and member.grade < info.grade then
        options[#options + 1] = {
            title = T('gang.kick'), icon = 'user-xmark',
            onSelect = function()
                if lib.alertDialog({ header = T('gang.kick'), content = T('gang.kick_confirm', member.name), centered = true, cancel = true }) == 'confirm' then
                    result(lib.callback.await('rp_gangs:kick', false, member.identifier))
                end
                openMenu()
            end,
        }
    end
    if #options == 0 then options[1] = { title = T('gang.no_actions'), readOnly = true, icon = 'ban' } end
    lib.registerContext({ id = 'rp_gang_member', title = member.name, menu = 'rp_gang_members', options = options })
    lib.showContext('rp_gang_member')
end

local function territoryMenu(info)
    local list = lib.callback.await('rp_gangs:getTerritories', false) or {}
    local options = {}
    for _, t in ipairs(list) do
        local desc = t.ownerLabel and T('gang.owned_by', t.ownerLabel) or T('gang.unowned')
        if t.locked then desc = desc .. ' • ' .. T('gang.locked') end
        if t.war then desc = desc .. ' • ' .. T('gang.at_war') end
        options[#options + 1] = {
            title = t.label, description = desc, icon = 'map-location-dot', disabled = not info.perms.war,
            onSelect = function()
                if not t.ownerLabel then
                    result(lib.callback.await('rp_gangs:claim', false, t.id))
                elseif t.ownerLabel ~= info.label then
                    if lib.alertDialog({
                        header = T('gang.war_header'), content = T('gang.war_content', t.label, GangCfg.War.cost),
                        centered = true, cancel = true,
                    }) == 'confirm' then
                        result(lib.callback.await('rp_gangs:declareWar', false, t.id))
                    end
                else
                    notify('inform', 'gang.own_territory')
                end
                openMenu()
            end,
        }
    end
    lib.registerContext({ id = 'rp_gang_territories', title = T('gang.territories'), menu = 'rp_gang_main', options = options })
    lib.showContext('rp_gang_territories')
end

openMenu = function()
    local info = lib.callback.await('rp_gangs:getInfo', false)
    if not info then return end

    if not info.inGang then
        lib.registerContext({
            id = 'rp_gang_main', title = T('gang.menu_title'),
            options = {
                {
                    title = T('gang.create'), description = T('gang.create_desc', info.cost), icon = 'skull',
                    onSelect = function()
                        local input = lib.inputDialog(T('gang.create'), {
                            { type = 'input', label = T('gang.name'), required = true, min = GangCfg.Creation.nameMin, max = GangCfg.Creation.nameMax },
                            { type = 'input', label = T('gang.color'), default = '#ff0000', required = true, min = 7, max = 7 },
                        })
                        if input then
                            result(lib.callback.await('rp_gangs:create', false, input[1], input[2]))
                        end
                    end,
                },
            },
        })
        lib.showContext('rp_gang_main')
        return
    end

    local options = {
        { title = info.label, description = T('gang.you_are', info.gradeLabel, info.bank), icon = 'users', readOnly = true },
        {
            title = T('gang.members', #info.members, info.maxMembers), icon = 'user-group', arrow = true,
            onSelect = function()
                local sub = {}
                for _, m in ipairs(info.members) do
                    sub[#sub + 1] = {
                        title = m.name, icon = m.online and 'circle-check' or 'circle',
                        description = m.gradeLabel .. (m.online and ' • online' or ''),
                        onSelect = function() memberMenu(info, m) end,
                    }
                end
                lib.registerContext({ id = 'rp_gang_members', title = T('gang.members_title'), menu = 'rp_gang_main', options = sub })
                lib.showContext('rp_gang_members')
            end,
        },
        {
            title = T('gang.invite'), icon = 'user-plus', disabled = not info.perms.invite,
            onSelect = function()
                local target = Interact.closestPlayer(GangCfg.Creation.inviteDistance)
                if not target then notify('error', 'gang.no_target') return end
                result(lib.callback.await('rp_gangs:invite', false, target))
                openMenu()
            end,
        },
        { title = T('gang.territories'), icon = 'map', arrow = true, onSelect = function() territoryMenu(info) end },
        {
            title = T('gang.deposit'), icon = 'piggy-bank', disabled = not info.perms.bank_deposit,
            onSelect = function()
                local amount = moneyInput(T('gang.deposit'), T('gang.amount'), 10000000)
                if amount then result(lib.callback.await('rp_gangs:deposit', false, amount)) end
                openMenu()
            end,
        },
        {
            title = T('gang.withdraw'), icon = 'hand-holding-dollar', disabled = not info.perms.bank_withdraw,
            onSelect = function()
                local amount = moneyInput(T('gang.withdraw'), T('gang.amount'), GangCfg.BankWithdrawMaxPerAction)
                if amount then result(lib.callback.await('rp_gangs:withdraw', false, amount)) end
                openMenu()
            end,
        },
        {
            title = T('gang.leave'), icon = 'door-open',
            onSelect = function()
                if lib.alertDialog({ header = T('gang.leave'), content = T('gang.leave_confirm'), centered = true, cancel = true }) == 'confirm' then
                    result(lib.callback.await('rp_gangs:leave', false))
                end
            end,
        },
    }
    if info.perms.disband then
        options[#options + 1] = {
            title = T('gang.disband'), icon = 'trash',
            onSelect = function()
                if lib.alertDialog({ header = T('gang.disband'), content = T('gang.disband_confirm'), centered = true, cancel = true }) == 'confirm' then
                    result(lib.callback.await('rp_gangs:disband', false))
                end
            end,
        }
    end
    lib.registerContext({ id = 'rp_gang_main', title = T('gang.menu_title'), options = options })
    lib.showContext('rp_gang_main')
end

RegisterCommand('gang', function() openMenu() end, false)
TriggerEvent('chat:addSuggestion', '/gang', T('gang.cmd_gang'))
