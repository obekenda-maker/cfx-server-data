--[[
    combat_core/server/damage.lua – server-side schadecontrole via `weaponDamageEvent`.

    Doel (niet vertrouwen op de client):
      * deelnemer → niet-deelnemer   : geannuleerd (bystanders/RP-spelers blijven veilig)
      * niet-deelnemer → deelnemer   : geannuleerd
      * andere zone / eigen team / beschermd slachtoffer / dode deelnemer : geannuleerd
      * optioneel (Outside.mode = 'disabled'): speler-op-speler schade buiten zones geannuleerd
      * registreert wie wie als laatste raakte (voor strictDamageCheck en combat-tag)

    Het event en de velden (`hitGlobalId`, `hitGlobalIds`) staan in de FiveM-documentatie;
    alles zit in pcall zodat een afwijkende payload nooit een scripterror geeft.
]]

local violations = {} -- [source] = { count, lastLog }

local function victimsFromEvent(data)
    local ids = {}
    if type(data) ~= 'table' then return ids end
    if type(data.hitGlobalId) == 'number' and data.hitGlobalId ~= 0 then
        ids[#ids + 1] = data.hitGlobalId
    end
    if type(data.hitGlobalIds) == 'table' then
        for _, id in ipairs(data.hitGlobalIds) do
            if type(id) == 'number' and id ~= 0 then ids[#ids + 1] = id end
        end
    end
    local out = {}
    for _, netId in ipairs(ids) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 1 then
            local owner = NetworkGetEntityOwner(entity)
            if owner and owner > 0 and GetPlayerPed(owner) == entity then
                out[#out + 1] = owner
            end
        end
    end
    return out
end

local function violation(sender, text)
    local v = violations[sender] or { count = 0, lastLog = 0 }
    violations[sender] = v
    v.count = v.count + 1
    local now = Combat.now()
    if v.count >= 5 and now - v.lastLog > 30000 then
        v.lastLog = now
        exports.server_logs:Log('suspicious', 'Geblokkeerde PvP-schade',
            ('%s: %s (%d× geblokkeerd)'):format(exports.server_logs:Describe(sender), text, v.count))
    end
end

--- Beslist of schade van `sender` op `victim` doorgaat. Geeft true=toestaan, false=annuleren, reden.
function Combat.evaluateDamage(sender, victim)
    local a, b = Combat.Players[sender], Combat.Players[victim]
    local now = Combat.now()

    if a and b then
        local zone = Combat.Zones[a.zone]
        if a.zone ~= b.zone then return false, 'andere zone' end
        if not a.alive or not b.alive then return false, 'dode deelnemer' end
        if zone and zone.mode == 'team' and a.team == b.team then return false, 'teamgenoot' end
        if now < b.protectedUntil then return false, 'beschermd slachtoffer' end
        -- toegestaan: registreer
        b.lastDamageBy = sender
        b.lastDamageAt = now
        a.lastDamageAt = now
        if CombatCfg.Rules.protectionBreaksOnFire and a.protectedUntil > now then
            a.protectedUntil = now
        end
        return true
    elseif a and not b then
        return false, 'deelnemer valt niet-deelnemer aan'
    elseif b and not a then
        return false, 'niet-deelnemer valt deelnemer aan'
    elseif CombatCfg.Outside.mode == 'disabled' then
        return false, 'PvP buiten zones uitgeschakeld'
    end
    return true
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    local ok, err = pcall(function()
        for _, victim in ipairs(victimsFromEvent(data)) do
            if victim ~= sender then
                local allow, why = Combat.evaluateDamage(sender, victim)
                if not allow then
                    CancelEvent()
                    violation(sender, why)
                end
            end
        end
    end)
    if not ok then Combat.debug('weaponDamageEvent fout:', err) end
end)

AddEventHandler('playerDropped', function()
    violations[source] = nil
end)
