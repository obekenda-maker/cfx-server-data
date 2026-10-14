--[[
    server_logs – gebruik vanuit andere resources:

        exports.server_logs:Log('money', 'Titel', 'Beschrijving', { {name='Veld', value='Waarde', inline=true} })
        exports.server_logs:Describe(source)   --> "Naam [12] (license:abcd...)"

    Kanalen: general, admin, money, combat, gang, suspicious (zie ServerCfg.Webhooks)
]]

local queues = {}      -- [url] = { embeds... }
local blockedUntil = {} -- [url] = os.time() waarna weer verzonden mag worden
local dbReady = false

local function clip(s, max)
    s = tostring(s or '')
    if #s > max then return s:sub(1, max - 1) .. '…' end
    return s
end

local function getWebhook(channel)
    local convarName = ServerCfg.Webhooks[channel] or ServerCfg.Webhooks.general
    local url = GetConvar(convarName, '')
    if url == '' then
        url = GetConvar(ServerCfg.Webhooks.general, '')
    end
    return url
end

local function getLicense(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return 'onbekend'
end

--- Leesbare omschrijving van een speler voor logs.
local function Describe(src)
    src = tonumber(src)
    if not src or src <= 0 or GetPlayerName(src) == nil then
        return 'Console/onbekend'
    end
    return ('%s [%d] (%s)'):format(GetPlayerName(src), src, getLicense(src))
end

local function Log(channel, title, description, fields, color)
    channel = channel or 'general'
    local colorHex = color or ServerCfg.Logs.colors[channel] or ServerCfg.Colors.info

    -- Database-audit
    if dbReady and ServerCfg.Logs.dbChannels[channel] then
        MySQL.insert('INSERT INTO server_log_entries (channel, title, message) VALUES (?, ?, ?)', {
            channel, clip(title, 120), clip(description, 2000),
        })
    end

    local url = getWebhook(channel)
    if url == '' then return end

    local embedFields
    if fields and #fields > 0 then
        embedFields = {}
        for i = 1, math.min(#fields, 20) do
            local f = fields[i]
            embedFields[#embedFields + 1] = {
                name   = clip(f.name, 256),
                value  = clip(f.value ~= nil and f.value or '-', 1024),
                inline = f.inline == true,
            }
        end
    end

    queues[url] = queues[url] or {}
    local q = queues[url]
    q[#q + 1] = {
        title       = clip(title, 256),
        description = clip(description, 4000),
        color       = type(colorHex) == 'number' and colorHex or ServerCfg.HexToInt(colorHex),
        fields      = embedFields,
        footer      = { text = ServerCfg.Server.name .. ' • ' .. channel },
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
    -- voorkom onbeperkt geheugen bij een kapotte webhook
    while #q > 200 do table.remove(q, 1) end
end

exports('Log', Log)
exports('Describe', Describe)

-- Server-side event voor resources die liever een event gebruiken
AddEventHandler('server_logs:log', function(channel, title, description, fields, color)
    Log(channel, title, description, fields, color)
end)

---------------------------------------------------------------------------
-- Verzenden (batch + rate-limit)
---------------------------------------------------------------------------
local function flush()
    local now = os.time()
    for url, q in pairs(queues) do
        if #q > 0 and (blockedUntil[url] or 0) <= now then
            local batch = {}
            local n = math.min(#q, ServerCfg.Logs.maxEmbedsPerRequest)
            for _ = 1, n do
                batch[#batch + 1] = table.remove(q, 1)
            end
            local body = {
                username = ServerCfg.Logs.username,
                embeds   = batch,
            }
            if ServerCfg.Logs.avatar ~= '' then body.avatar_url = ServerCfg.Logs.avatar end

            PerformHttpRequest(url, function(status, _, headers)
                if status == 429 then
                    -- te snel: zet batch terug vooraan en wacht
                    local retry = tonumber(headers and (headers['retry-after'] or headers['Retry-After'])) or 5
                    blockedUntil[url] = os.time() + math.ceil(retry)
                    for i = #batch, 1, -1 do table.insert(q, 1, batch[i]) end
                elseif status >= 400 then
                    print(('^1[server_logs]^7 Webhook gaf HTTP %s – controleer de convar-URL.'):format(status))
                end
            end, 'POST', json.encode(body), { ['Content-Type'] = 'application/json' })
        end
    end
end

CreateThread(function()
    while true do
        Wait(ServerCfg.Logs.flushMs)
        flush()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then flush() end
end)

---------------------------------------------------------------------------
-- Database controle + opschonen
---------------------------------------------------------------------------
CreateThread(function()
    local ok = pcall(function() MySQL.scalar.await('SELECT 1 FROM server_log_entries LIMIT 1') end)
    if not ok then
        print('^1[server_logs]^7 Tabel server_log_entries ontbreekt. Importeer sql/01_core.sql – DB-logging staat uit.')
        return
    end
    dbReady = true
    MySQL.update('DELETE FROM server_log_entries WHERE created_at < (NOW() - INTERVAL ? DAY)', { ServerCfg.Logs.keepDays })
end)
