--[[ admin_tools/client/main.lua – /admin menu, /coords, infovenster. Rechten worden server-side gecontroleerd. ]]

local T = ServerCfg.T
local function notify(kind, key, ...) ServerCfg.Notify(nil, kind, key, ...) end

RegisterNetEvent('admin_tools:showInfo', function(markdown)
    lib.alertDialog({ header = T('admin.info_title'), content = markdown, centered = true, size = 'lg' })
end)

local function act(action, target, extra)
    lib.callback.await('admin_tools:action', false, action, target, extra)
end

local function playerMenu(p)
    lib.registerContext({
        id = 'admin_player',
        title = ('%s [%d]'):format(p.name, p.id),
        menu = 'admin_players',
        options = {
            { title = T('admin.act_check'), icon = 'magnifying-glass', onSelect = function() act('check', p.id) end },
            { title = T('admin.act_warnings'), icon = 'clipboard-list', onSelect = function() act('warnings', p.id) end },
            { title = T('admin.act_warn'), icon = 'triangle-exclamation', onSelect = function()
                local input = lib.inputDialog(T('admin.act_warn'), { { type = 'input', label = T('admin.reason'), required = true, max = 200 } })
                if input then act('warn', p.id, { reason = input[1] }) end
            end },
            { title = T('admin.act_kick'), icon = 'user-slash', onSelect = function()
                local input = lib.inputDialog(T('admin.act_kick'), { { type = 'input', label = T('admin.reason'), required = true, max = 200 } })
                if input then act('kick', p.id, { reason = input[1] }) end
            end },
            { title = T('admin.act_ban'), icon = 'ban', onSelect = function()
                local input = lib.inputDialog(T('admin.act_ban'), {
                    { type = 'input', label = T('admin.duration'), description = '30m, 12h, 7d, perm', default = '24h', required = true },
                    { type = 'input', label = T('admin.reason'), required = true, max = 200 },
                })
                if input then act('ban', p.id, { duration = input[1], reason = input[2] }) end
            end },
            { title = T('admin.act_revive'), icon = 'heart-pulse', onSelect = function() act('revive', p.id) end },
            { title = T('admin.act_goto'), icon = 'location-arrow', onSelect = function() act('goto', p.id) end },
            { title = T('admin.act_bring'), icon = 'person-walking-arrow-loop-left', onSelect = function() act('bring', p.id) end },
            { title = T('admin.act_pvpkick'), icon = 'crosshairs', onSelect = function() act('pvpkick', p.id) end },
        },
    })
    lib.showContext('admin_player')
end

RegisterCommand('admin', function()
    local players = lib.callback.await('admin_tools:getPlayers', false)
    if not players then
        notify('error', 'admin.no_permission')
        return
    end
    local options = {}
    for _, p in ipairs(players) do
        options[#options + 1] = {
            title = ('[%d] %s'):format(p.id, p.name),
            description = ('%s • %s • %d ms'):format(p.job, p.group, p.ping),
            icon = 'user',
            onSelect = function() playerMenu(p) end,
        }
    end
    lib.registerContext({ id = 'admin_players', title = T('admin.menu_title'), options = options })
    lib.showContext('admin_players')
end, false)

RegisterCommand('coords', function()
    if not lib.callback.await('admin_tools:can', false, 'coords') then
        notify('error', 'admin.no_permission')
        return
    end
    local ped = PlayerPedId()
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local text = ('vec4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h)
    lib.setClipboard(text)
    print(text)
    notify('success', 'admin.coords_copied')
end, false)

TriggerEvent('chat:addSuggestion', '/admin', T('admin.cmd_admin'))
TriggerEvent('chat:addSuggestion', '/coords', T('admin.cmd_coords'))
TriggerEvent('chat:addSuggestion', '/kick', T('admin.cmd_kick'), { { name = 'id', help = 'Speler-ID' }, { name = 'reden', help = '' } })
TriggerEvent('chat:addSuggestion', '/ban', T('admin.cmd_ban'), { { name = 'id', help = 'Speler-ID' }, { name = 'duur', help = '30m | 12h | 7d | perm' }, { name = 'reden', help = '' } })
TriggerEvent('chat:addSuggestion', '/unban', T('admin.cmd_unban'), { { name = 'ban-id', help = '' } })
TriggerEvent('chat:addSuggestion', '/warn', T('admin.cmd_warn'), { { name = 'id', help = 'Speler-ID' }, { name = 'reden', help = '' } })
TriggerEvent('chat:addSuggestion', '/warnings', T('admin.cmd_warnings'), { { name = 'id', help = 'Speler-ID' } })
TriggerEvent('chat:addSuggestion', '/checkplayer', T('admin.cmd_check'), { { name = 'id', help = 'Speler-ID' } })
TriggerEvent('chat:addSuggestion', '/pvpkick', T('admin.act_pvpkick'), { { name = 'id', help = 'Speler-ID' } })
