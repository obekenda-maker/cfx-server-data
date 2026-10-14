--[[ rp_interactions/client/main.lua – 3D-tekst (/me, /do), ID-kaart, handen omhoog ]]

local T = ServerCfg.T
local texts = {}   -- [serverId] = { { text, kind, expires } ... }

RegisterNetEvent('rp_interactions:show', function(src, kind, text, name)
    texts[src] = texts[src] or {}
    local list = texts[src]
    list[#list + 1] = { text = text, kind = kind, expires = GetGameTimer() + InterCfg.TextSeconds * 1000 }
    while #list > 3 do table.remove(list, 1) end
    -- ook in de chat voor wie er bij stond
    TriggerEvent('chat:addMessage', {
        color = kind == 'me' and { 255, 106, 0 } or { 45, 156, 255 },
        multiline = true,
        args = { kind == 'me' and ('* %s %s'):format(name, text) or ('** %s (%s)'):format(text, name) },
    })
end)

local function draw3d(coords, text, color)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.34, 0.34)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(color[1], color[2], color[3], 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

CreateThread(function()
    while true do
        if next(texts) then
            Wait(0)
            local now = GetGameTimer()
            local myPos = GetEntityCoords(PlayerPedId())
            for src, list in pairs(texts) do
                local player = GetPlayerFromServerId(src)
                if player ~= -1 then
                    local ped = GetPlayerPed(player)
                    local pos = GetEntityCoords(ped)
                    if #(pos - myPos) < InterCfg.ChatRadius + 5.0 then
                        local line = 0
                        for i = #list, 1, -1 do
                            local entry = list[i]
                            if entry.expires > now then
                                local color = entry.kind == 'me' and { 255, 106, 0 } or { 45, 156, 255 }
                                local shown = (entry.kind == 'me' and '* ' or '** ') .. entry.text
                                draw3d(vec3(pos.x, pos.y, pos.z + 1.0 + line * 0.14), shown, color)
                                line = line + 1
                            end
                        end
                    end
                end
                -- opruimen
                for i = #list, 1, -1 do if list[i].expires <= now then table.remove(list, i) end end
                if #list == 0 then texts[src] = nil end
            end
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('rp_interactions:showId', function(card, own)
    lib.alertDialog({
        header = own and T('inter.id_own') or T('inter.id_other'),
        content = T('inter.id_card', card.name, tostring(card.dob), tostring(card.sex), tostring(card.height)),
        centered = true,
    })
end)

---------------------------------------------------------------------------
-- Handen omhoog (toggle)
---------------------------------------------------------------------------
local handsUp = false
RegisterCommand('handenomhoog', function()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then return end
    handsUp = not handsUp
    if handsUp then
        RequestAnimDict('missminuteman_1ig_2')
        while not HasAnimDictLoaded('missminuteman_1ig_2') do Wait(10) end
        TaskPlayAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 8.0, -8.0, -1, 49, 0.0, false, false, false)
    else
        ClearPedTasks(ped)
    end
end, false)
RegisterKeyMapping('handenomhoog', T('inter.key_hands'), 'keyboard', 'X')

TriggerEvent('chat:addSuggestion', '/me', T('inter.cmd_me'), { { name = 'tekst', help = '...' } })
TriggerEvent('chat:addSuggestion', '/do', T('inter.cmd_do'), { { name = 'tekst', help = '...' } })
TriggerEvent('chat:addSuggestion', '/id', T('inter.cmd_id'))
TriggerEvent('chat:addSuggestion', '/geefgeld', T('inter.cmd_givemoney'), { { name = 'id', help = 'Speler-ID' }, { name = 'bedrag', help = '€' } })
TriggerEvent('chat:addSuggestion', '/geefitem', T('inter.cmd_giveitem'), { { name = 'id', help = 'Speler-ID' }, { name = 'item', help = 'Itemnaam' }, { name = 'aantal', help = '1' } })
TriggerEvent('chat:addSuggestion', '/handenomhoog', T('inter.key_hands'))
