--[[
    Gedeelde client-helper voor interactiepunten (E-prompt, marker, blip).
    Laden in een resource via client_scripts { '@server_config/interact.lua', ... }
    Vereist ox_lib (lib.points, lib.showTextUI) in diezelfde resource.

        Interact.point({
            coords   = vec3(...),
            distance = 2.0,                       -- activatieafstand
            label    = '[E] Doe iets',            -- TextUI-tekst
            canUse   = function() return true end,-- optioneel; false = geen prompt
            onUse    = function() ... end,
            marker   = { type = 1, r = 255, g = 106, b = 0, a = 90, scale = 1.2 },  -- optioneel
        })
        Interact.blip({ coords = vec3(...), sprite = 60, colour = 3, label = 'Naam', scale = 0.8 })
]]

Interact = Interact or {}

function Interact.point(opts)
    local key = opts.key or 38 -- E
    local shown = false

    local function hide()
        if shown then
            lib.hideTextUI()
            shown = false
        end
    end

    local point = lib.points.new({
        coords = opts.coords,
        distance = opts.distance or 2.0,
        onExit = hide,
        nearby = function()
            local usable = (opts.canUse == nil) or opts.canUse()
            if usable then
                if not shown then
                    lib.showTextUI(opts.label or '[E]')
                    shown = true
                end
                if IsControlJustReleased(0, key) then
                    hide()
                    opts.onUse()
                end
            else
                hide()
            end
        end,
    })

    if opts.marker then
        local m = opts.marker
        lib.points.new({
            coords = opts.coords,
            distance = (m.drawDistance or 14.0),
            nearby = function()
                DrawMarker(m.type or 1, opts.coords.x, opts.coords.y, opts.coords.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    m.scale or 1.2, m.scale or 1.2, 0.4, m.r or 255, m.g or 106, m.b or 0, m.a or 90,
                    false, false, 2, false, nil, nil, false)
            end,
        })
    end
    return point
end

function Interact.blip(opts)
    local blip = AddBlipForCoord(opts.coords.x, opts.coords.y, opts.coords.z)
    SetBlipSprite(blip, opts.sprite or 1)
    SetBlipColour(blip, opts.colour or 0)
    SetBlipScale(blip, opts.scale or 0.8)
    SetBlipAsShortRange(blip, opts.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(opts.label or '')
    EndTextCommandSetBlipName(blip)
    return blip
end

--- Dichtstbijzijnde andere speler (server-id) binnen `distance` meter, of nil.
function Interact.closestPlayer(distance)
    local id = lib.getClosestPlayer(GetEntityCoords(PlayerPedId()), distance or 3.0, false)
    if id then return GetPlayerServerId(id) end
    return nil
end
