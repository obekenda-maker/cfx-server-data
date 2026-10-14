--[[
    rp_gangs/server/territory.lua – territoria, claimen, ganggevechten, gebiedsinkomsten.
    Een ganggevecht is een TIJDELIJKE combat zone (combat_core) met toegang alleen voor de twee gangs.
    Daarbuiten verandert er niets aan de PvP-regels: geen onbedoelde PvP in de rest van de wereld.
]]

local TCfg, WCfg = GangCfg.Territory, GangCfg.War
local cfgById = {}
for _, t in ipairs(GangCfg.Territories) do cfgById[t.id] = t end

local T = {}      -- [id] = { gang_id = n|nil, lockedUntil = unix|0 }
local wars = {}   -- [territoryId] = war
local killLast = {} -- ["killer>victim"] = ms

Gang.territories = T

local function ownerOf(id)
    local t = T[id]
    return t and t.gang_id and Gang.gangs[t.gang_id] or nil
end

function Gang.territoriesOf(gangId)
    local out = {}
    for _, cfg in ipairs(GangCfg.Territories) do
        local t = T[cfg.id]
        if t and t.gang_id == gangId then out[#out + 1] = { id = cfg.id, label = cfg.label } end
    end
    return out
end

local function countOwned(gangId)
    return #Gang.territoriesOf(gangId)
end

function Gang.hasTerritory(gangId)
    return countOwned(gangId) > 0
end

local function publicList()
    local list = {}
    for _, cfg in ipairs(GangCfg.Territories) do
        local t = T[cfg.id]
        local owner = ownerOf(cfg.id)
        list[#list + 1] = {
            id = cfg.id, label = cfg.label, radius = cfg.radius,
            coords = { x = cfg.coords.x, y = cfg.coords.y, z = cfg.coords.z },
            ownerLabel = owner and owner.label or nil, ownerColor = owner and owner.color or nil,
            locked = (t and t.lockedUntil or 0) > os.time(),
            war = wars[cfg.id] and wars[cfg.id].state or nil,
        }
    end
    return list
end

local function broadcast()
    TriggerClientEvent('rp_gangs:territories', -1, publicList())
end

function Gang.releaseTerritories(gangId)
    for _, t in pairs(T) do
        if t.gang_id == gangId then t.gang_id = nil end
    end
    broadcast()
end

local function setOwner(id, gangId, lockMinutes)
    local t = T[id]
    t.gang_id = gangId
    t.lockedUntil = os.time() + (lockMinutes or TCfg.lockMinutes) * 60
    -- let op: nooit nil in een parameterlijst (gaten in de tabel breken de msgpack-serialisatie naar oxmysql)
    if gangId then
        MySQL.update(
            'UPDATE rp_gang_territories SET gang_id = ?, claimed_at = NOW(), locked_until = FROM_UNIXTIME(?) WHERE territory = ?',
            { gangId, t.lockedUntil, id })
    else
        MySQL.update('UPDATE rp_gang_territories SET gang_id = NULL, locked_until = FROM_UNIXTIME(?) WHERE territory = ?',
            { t.lockedUntil, id })
    end
    broadcast()
end

---------------------------------------------------------------------------
-- Laden
---------------------------------------------------------------------------
function Gang.onReady()
    for _, cfg in ipairs(GangCfg.Territories) do
        MySQL.insert.await('INSERT IGNORE INTO rp_gang_territories (territory) VALUES (?)', { cfg.id })
    end
    local rows = MySQL.query.await('SELECT territory, gang_id, UNIX_TIMESTAMP(locked_until) AS locked FROM rp_gang_territories') or {}
    for _, r in ipairs(rows) do
        if cfgById[r.territory] then
            local gid = r.gang_id
            if gid and not Gang.gangs[gid] then gid = nil end
            T[r.territory] = { gang_id = gid, lockedUntil = tonumber(r.locked) or 0 }
        end
    end
    for id in pairs(cfgById) do T[id] = T[id] or { gang_id = nil, lockedUntil = 0 } end
end

lib.callback.register('rp_gangs:getTerritories', function()
    return publicList()
end)

---------------------------------------------------------------------------
-- Claimen
---------------------------------------------------------------------------
lib.callback.register('rp_gangs:claim', function(source, id)
    local cfg = cfgById[id]
    local gang = Gang.of(source)
    if not cfg or not gang or not Gang.can(source, 'war') then return { ok = false, msg = 'gang.no_permission' } end
    if not Gang.throttle(source, 'territory', 2000) then return { ok = false, msg = 'gang.too_fast' } end
    local t = T[id]
    if not t or t.gang_id then return { ok = false, msg = 'gang.territory_taken' } end
    if (t.lockedUntil or 0) > os.time() then return { ok = false, msg = 'gang.territory_locked' } end
    if not Gang.near(source, cfg.coords, cfg.radius) then return { ok = false, msg = 'gang.not_in_territory' } end
    if #Gang.onlineMembers(gang.id) < TCfg.minOnline then return { ok = false, msg = 'gang.need_online', param = TCfg.minOnline } end
    if countOwned(gang.id) >= TCfg.maxPerGang then return { ok = false, msg = 'gang.max_territories', param = TCfg.maxPerGang } end
    if not Gang.addBank(gang.id, -TCfg.claimCost) then return { ok = false, msg = 'gang.bank_low' } end

    setOwner(id, gang.id)
    Gang.notifyGang(gang.id, 'success', 'gang.territory_claimed', cfg.label)
    Gang.log('Territorium geclaimd', ('%s claimde **%s** (€%d uit de gangkas)'):format(gang.label, cfg.label, TCfg.claimCost))
    exports.server_logs:Log('money', 'Territorium geclaimd', ('Gang %s betaalde €%d'):format(gang.label, TCfg.claimCost))
    return { ok = true, msg = 'gang.territory_claimed', param = cfg.label }
end)

---------------------------------------------------------------------------
-- Oorlog
---------------------------------------------------------------------------
local function warOfGang(gangId)
    for _, w in pairs(wars) do
        if w.attacker == gangId or w.defender == gangId then return w end
    end
    return nil
end

local function endWar(war, reason)
    if war.ended then return end
    war.ended = true
    local cfg = cfgById[war.territory]
    local att, def = Gang.gangs[war.attacker], Gang.gangs[war.defender]

    if war.state == 'active' then
        pcall(function() exports.combat_core:RemoveTemporaryZone(war.zoneId) end)
    end

    local attackerWins = false
    if war.state == 'active' then
        if war.killsA >= WCfg.winKills then
            attackerWins = true
        elseif reason == 'time' and war.killsA > war.killsB and war.killsA >= WCfg.attackerMinKills then
            attackerWins = true
        end
    end
    wars[war.territory] = nil

    if war.state ~= 'active' then
        -- afgebroken voor de start: uitdager krijgt de kosten terug
        if att then Gang.addBank(att.id, WCfg.cost) end
        if att then Gang.notifyGang(att.id, 'inform', 'gang.war_cancelled') end
        if def then Gang.notifyGang(def.id, 'inform', 'gang.war_cancelled') end
        Gang.log('Ganggevecht afgebroken', ('%s: %s'):format(cfg.label, reason))
        broadcast()
        return
    end

    if attackerWins and att then
        setOwner(war.territory, att.id)
        if att then Gang.notifyGang(att.id, 'success', 'gang.war_won', cfg.label) end
        if def then Gang.notifyGang(def.id, 'error', 'gang.war_lost', cfg.label) end
    else
        setOwner(war.territory, def and def.id or nil)
        if def then Gang.notifyGang(def.id, 'success', 'gang.war_defended', cfg.label) end
        if att then Gang.notifyGang(att.id, 'error', 'gang.war_failed', cfg.label) end
    end
    Gang.log('Ganggevecht afgelopen', ('%s: %s %d – %d %s → %s'):format(
        cfg.label, att and att.label or '?', war.killsA, war.killsB, def and def.label or '?',
        attackerWins and (att and att.label or '?') or (def and def.label or 'niemand')))
end

local function startWar(war)
    if war.ended then return end
    local cfg = cfgById[war.territory]
    local att, def = Gang.gangs[war.attacker], Gang.gangs[war.defender]
    if not att or not def or #Gang.onlineMembers(att.id) < 1 or #Gang.onlineMembers(def.id) < 1 then
        return endWar(war, 'gang niet meer online of opgeheven')
    end

    war.zoneId = 'war_' .. war.territory
    local ok = exports.combat_core:CreateTemporaryZone({
        id = war.zoneId, label = 'Ganggevecht: ' .. cfg.label,
        coords = { x = cfg.coords.x, y = cfg.coords.y, z = cfg.coords.z }, radius = cfg.radius * WCfg.radiusFactor,
        mode = 'team', scoreLimit = 9999,
        teams = {
            { id = 1, label = att.label, color = att.color },
            { id = 2, label = def.label, color = def.color },
        },
        access = { gangs = { att.id, def.id } },
        rewards = false, countStats = false, loadouts = WCfg.loadouts,
        durationSeconds = WCfg.durationSeconds + 30,
        blip = { sprite = 84, colour = 1, scale = 1.0 },
    })
    if not ok then return endWar(war, 'combat zone kon niet worden aangemaakt') end

    war.state = 'active'
    war.startedAt = os.time()
    broadcast()
    Gang.notifyGang(att.id, 'warning', 'gang.war_started', cfg.label)
    Gang.notifyGang(def.id, 'warning', 'gang.war_started', cfg.label)
    Gang.log('Ganggevecht gestart', ('%s valt %s aan om **%s**'):format(att.label, def.label, cfg.label))

    SetTimeout(WCfg.durationSeconds * 1000, function() endWar(war, 'time') end)
end

lib.callback.register('rp_gangs:declareWar', function(source, id)
    local cfg = cfgById[id]
    local gang = Gang.of(source)
    if not cfg or not gang or not Gang.can(source, 'war') then return { ok = false, msg = 'gang.no_permission' } end
    if not Gang.throttle(source, 'territory', 2000) then return { ok = false, msg = 'gang.too_fast' } end

    local t = T[id]
    local owner = ownerOf(id)
    if not owner then return { ok = false, msg = 'gang.territory_free' } end
    if owner.id == gang.id then return { ok = false, msg = 'gang.own_territory' } end
    if wars[id] then return { ok = false, msg = 'gang.war_running' } end
    if warOfGang(gang.id) or warOfGang(owner.id) then return { ok = false, msg = 'gang.war_busy' } end
    if (t.lockedUntil or 0) > os.time() then return { ok = false, msg = 'gang.territory_locked' } end
    if not Gang.near(source, cfg.coords, cfg.radius + 30.0) then return { ok = false, msg = 'gang.not_in_territory' } end
    if #Gang.onlineMembers(gang.id) < WCfg.minOnlineEach then return { ok = false, msg = 'gang.need_online', param = WCfg.minOnlineEach } end
    if #Gang.onlineMembers(owner.id) < WCfg.minOnlineEach then return { ok = false, msg = 'gang.rival_offline' } end
    if not Gang.addBank(gang.id, -WCfg.cost) then return { ok = false, msg = 'gang.bank_low' } end

    local war = { territory = id, attacker = gang.id, defender = owner.id, state = 'prepare', killsA = 0, killsB = 0 }
    wars[id] = war
    broadcast()
    Gang.notifyGang(gang.id, 'warning', 'gang.war_declared_att', cfg.label, WCfg.prepareSeconds)
    Gang.notifyGang(owner.id, 'warning', 'gang.war_declared_def', gang.label, cfg.label, WCfg.prepareSeconds)
    Gang.log('Oorlog verklaard', ('%s verklaarde de oorlog aan %s om **%s** (kosten €%d)'):format(gang.label, owner.label, cfg.label, WCfg.cost))
    exports.server_logs:Log('money', 'Oorlogskosten', ('Gang %s betaalde €%d'):format(gang.label, WCfg.cost))

    SetTimeout(WCfg.prepareSeconds * 1000, function() startWar(war) end)
    return { ok = true, msg = 'gang.war_declared', param = cfg.label }
end)

-- Kills tellen (alleen in de oorlogszone, met anti-misbruik)
AddEventHandler('combat:kill', function(data)
    if type(data) ~= 'table' or type(data.zone) ~= 'string' then return end
    local id = data.zone:match('^war_(.+)$')
    local war = id and wars[id]
    if not war or war.state ~= 'active' then return end

    local now = GetGameTimer()
    local key = tostring(data.killer) .. '>' .. tostring(data.victim)
    if (data.victimAliveMs or 0) < 8000 then return end                 -- spawn-kills tellen niet
    if killLast[key] and now - killLast[key] < 15000 then return end    -- zelfde paar te snel
    killLast[key] = now

    if data.killerTeam == 1 then war.killsA = war.killsA + 1 else war.killsB = war.killsB + 1 end
    local text = ('%s %d – %d %s'):format(Gang.gangs[war.attacker].label, war.killsA, war.killsB, Gang.gangs[war.defender].label)
    Gang.notifyGang(war.attacker, 'inform', 'gang.war_score', text)
    Gang.notifyGang(war.defender, 'inform', 'gang.war_score', text)
    if war.killsA >= WCfg.winKills or war.killsB >= WCfg.winKills then
        endWar(war, 'kills')
    end
end)

---------------------------------------------------------------------------
-- Gebiedsinkomsten (geld naar de gangkas, alleen met genoeg leden online)
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(3600 * 1000)
        if Gang.ready and TCfg.incomePerHour > 0 then
            for id, t in pairs(T) do
                if t.gang_id and Gang.gangs[t.gang_id] and #Gang.onlineMembers(t.gang_id) >= TCfg.minOnline then
                    Gang.addBank(t.gang_id, TCfg.incomePerHour)
                    Gang.log('Gebiedsinkomsten', ('%s ontving €%d van %s'):format(Gang.gangs[t.gang_id].label, TCfg.incomePerHour, cfgById[id].label), 'gang')
                end
            end
        end
    end
end)

-- Oorlogen netjes afbreken bij herstart
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, war in pairs(wars) do
        if war.zoneId then pcall(function() exports.combat_core:RemoveTemporaryZone(war.zoneId) end) end
    end
end)
