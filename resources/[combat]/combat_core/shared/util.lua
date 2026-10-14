--[[ Gedeelde helpers combat_core (client + server) ]]

CombatUtil = {}

function CombatUtil.xyz(c)
    if c == nil then return nil end
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }
end

function CombatUtil.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0.0) - (b.z or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function CombatUtil.dist2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

--- Genereert spawnpunten op een ring rond het zonemiddelpunt.
--- Geeft lijst { {x=,y=,z=,h=,sector=n}, ... }. z is slechts een hint.
function CombatUtil.ringSpawns(center, radius, count, factor)
    count = count or 12
    factor = factor or 0.65
    local points = {}
    for i = 0, count - 1 do
        local angle = (2 * math.pi) * (i / count)
        local x = center.x + math.cos(angle) * radius * factor
        local y = center.y + math.sin(angle) * radius * factor
        -- kijk naar het middelpunt
        local heading = (math.deg(math.atan(center.y - y, center.x - x)) - 90.0) % 360.0
        points[#points + 1] = { x = x, y = y, z = center.z, h = heading, index = i, angle = angle }
    end
    return points
end
