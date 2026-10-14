--[[
    combat_stats – server

    Exports (server):
        exports.combat_stats:Ensure(src)                 -> stats-tabel of nil
        exports.combat_stats:Get(src)                    -> kopie met kd + level
        exports.combat_stats:RecordKill(src, xp, streak) -> nieuwe stats
        exports.combat_stats:AddXp(src, xp)
(src)         -> number
        exports.combat_stats:AddEarnedToday(src, amount)
        exports.combat_stats:GetLeaderboard(limit, sort) -> lijst  (sort: 'kills' | 'kd' | 'xp')
        exports.combat_stats:LevelFromXp(xp)
]]

local cache = {}   -- [identifier] = row
local dirty = {}   -- [identifier] = true
local srcToId = {} -- [source] = identifier
local boardCache = {} -- [sort] = { at = os.time(), rows = {...} }
local dbOk = false

local function today()
    return os.date('%Y-%m-%d')
end

local function levelFromXp(xp)
    local lvl = math.floor(math.sqrt((tonumber(xp) or 0) / StatsCfg.xpBase)) + 1
    return math.min(lvl, StatsCfg.maxLevel)
end

local function decorate(row)
    local copy = {}
    for k, v in pairs(row) do copy[k] = v end
    copy.kd = ServerCfg.Round(row.kills / math.max(row.deaths, 1), 2)
    copy.level = levelFromXp(row.xp)
    return copy
end

local function playerName(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        local ok, name = pcall(function() return xPlayer.getName() end)
        if ok and name and name ~= '' then return name end
    end
    return GetPlayerName(src) or 'Onbekend'
end

---------------------------------------------------------------------------
-- Laden / opslaan
---------------------------------------------------------------------------
local function load(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return nil end
    local identifier = xPlayer.identifier
    srcToId[src] = identifier

    if cache[identifier] then
        cache[identifier].name = playerName(src)
        return cache[identifier]
    end
    if not dbOk then return nil end

    local row = MySQL.single.await(
        'SELECT identifier, name, kills, deaths, best_streak, xp, earned_today, earned_date FROM combat_stats WHERE identifier = ?',
        { identifier })

    if not row then
        row = { identifier = identifier, name = playerName(src), kills = 0, deaths = 0, best_streak = 0,
                xp = 0, earned_today = 0, earned_date = today() }
        MySQL.insert.await(
            'INSERT INTO combat_stats (identifier, name, kills, deaths, best_streak, xp, earned_today, earned_date) VALUES (?, ?, 0, 0, 0, 0, 0, ?)',
            { identifier, row.name, row.earned_date })
    end

    row.name = playerName(src)
    if row.earned_date ~= today() then
        row.earned_today = 0
        row.earned_date = today()
        dirty[identifier] = true
    end
    cache[identifier] = row
    return row
end

local function flushOne(identifier)
    local row = cache[identifier]
    if not row or not dirty[identifier] then return end
    dirty[identifier] = nil
    MySQL.update(
        'UPDATE combat_stats SET name = ?, kills = ?, deaths = ?, best_streak = ?, xp = ?, earned_today = ?, earned_date = ? WHERE identifier = ?',
        { row.name, row.kills, row.deaths, row.best_streak, row.xp, row.earned_today, row.earned_date, identifier })
end

local function flushAll()
    for identifier in pairs(dirty) do flushOne(identifier) end
end

local function rowFor(src)
    local identifier = srcToId[src]
    if identifier and cache[identifier] then return cache[identifier] end
    return load(src)
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
exports('LevelFromXp', levelFromXp)

exports('Ensure', function(src)
    local row = rowFor(src)
    return row and decorate(row) or nil
end)

exports('Get', function(src)
    local row = rowFor(src)
    return row and decorate(row) or nil
end)

exports('RecordKill', function(src, xp, streak)
    local row = rowFor(src)
    if not row then return nil end
    row.kills = row.kills + 1
    row.xp = row.xp + math.max(0, math.floor(tonumber(xp) or 0))
    streak = tonumber(streak) or 0
    if streak > row.best_streak then row.best_streak = streak end
    dirty[row.identifier] = true
    return decorate(row)
end)

exports('AddXp', function(src, xp)
    local row = rowFor(src)
    if not row then return nil end
    row.xp = row.xp + math.max(0, math.floor(tonumber(xp) or 0))
    dirty[row.identifier] = true
    return decorate(row)
end)

exports('RecordDeath', function(src)
    local row = rowFor(src)
    if not row then return nil end
    row.deaths = row.deaths + 1
    dirty[row.identifier] = true
    return decorate(row)
end)

exports('GetEarnedToday', function(src)
    local row = rowFor(src)
    if not row then return 0 end
    if row.earned_date ~= today() then
        row.earned_today = 0
        row.earned_date = today()
        dirty[row.identifier] = true
    end
    return row.earned_today
end)

exports('AddEarnedToday', function(src, amount)
    local row = rowFor(src)
    if not row then return end
    if row.earned_date ~= today() then
        row.earned_today = 0
        row.earned_date = today()
    end
    row.earned_today = row.earned_today + math.max(0, math.floor(tonumber(amount) or 0))
    dirty[row.identifier] = true
end)

local SORTS = {
    kills = 'kills DESC, deaths ASC',
    xp    = 'xp DESC',
    kd    = '(kills / GREATEST(deaths, 1)) DESC, kills DESC',
}

local function getLeaderboard(limit, sort)
    if not dbOk then return {} end
    limit = math.max(1, math.min(tonumber(limit) or 10, StatsCfg.boardMax))
    if not SORTS[sort] then sort = 'kills' end

    local cached = boardCache[sort]
    if cached and (os.time() - cached.at) < StatsCfg.boardCacheSec and #cached.rows >= limit then
        local out = {}
        for i = 1, limit do out[i] = cached.rows[i] end
        return out
    end

    flushAll()
    local where = ''
    local params = {}
    if sort == 'kd' then
        where = 'WHERE kills >= ?'
        params[#params + 1] = StatsCfg.kdMinKills
    end
    params[#params + 1] = StatsCfg.boardMax

    local rows = MySQL.query.await(
        ('SELECT name, kills, deaths, best_streak, xp FROM combat_stats %s ORDER BY %s LIMIT ?'):format(where, SORTS[sort]),
        params) or {}

    for i, r in ipairs(rows) do
        r.rank = i
        r.kd = ServerCfg.Round(r.kills / math.max(r.deaths, 1), 2)
        r.level = levelFromXp(r.xp)
    end
    boardCache[sort] = { at = os.time(), rows = rows }

    local out = {}
    for i = 1, math.min(limit, #rows) do out[i] = rows[i] end
    return out
end
exports('GetLeaderboard', getLeaderboard)

lib.callback.register('combat_stats:getLeaderboard', function(_, sort, limit)
    return getLeaderboard(limit or ServerCfg.Hud.leaderboardRows, sort)
end)

lib.callback.register('combat_stats:getMine', function(source)
    local row = rowFor(source)
    return row and decorate(row) or nil
end)

---------------------------------------------------------------------------
-- Events / lifecycle
---------------------------------------------------------------------------
AddEventHandler('esx:playerLoaded', function(playerId)
    -- ESX geeft (playerId, xPlayer, isNew); we gebruiken alleen het id
    load(playerId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local identifier = srcToId[src]
    srcToId[src] = nil
    if identifier then
        flushOne(identifier)
        cache[identifier] = nil
        dirty[identifier] = nil
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then flushAll() end
end)

CreateThread(function()
    while true do
        Wait(StatsCfg.flushSeconds * 1000)
        flushAll()
    end
end)

CreateThread(function()
    local ok = pcall(function() MySQL.scalar.await('SELECT 1 FROM combat_stats LIMIT 1') end)
    if not ok then
        print('^1[combat_stats]^7 Tabel combat_stats ontbreekt. Importeer sql/01_core.sql en herstart de resource.')
        return
    end
    dbOk = true
    -- Bij een resource-restart: bestaande spelers opnieuw koppelen
    for _, src in ipairs(ESX.GetPlayers()) do load(tonumber(src)) end
end)
