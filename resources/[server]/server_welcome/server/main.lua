--[[
    server_welcome/server/main.lua – regels-akkoord (server-afgedwongen) en onboarding-status.

    * Een speler die na het laden niet binnen `acceptTimeoutSeconds` akkoord geeft, wordt door de SERVER verwijderd
      (de client kan dit niet omzeilen door de NUI te sluiten).
    * Akkoord wordt per Rockstar-license bewaard, met de regelversie. Nieuwe versie = opnieuw akkoord.
    * Noodoplossing als de knop niet werkt: /akkoord in de chat.
]]

local R = WelcomeCfg.Rules
local pending = {}   -- [source] = GetGameTimer() sinds laden, voor wie nog niet akkoord is
local cache = {}     -- [source] = { version, onboarded }

local function licenseOf(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

local function load(src)
    local license = licenseOf(src)
    if not license then return nil end
    local row = MySQL.single.await('SELECT version, onboarded FROM server_rules_accepted WHERE license = ?', { license })
    cache[src] = { version = row and row.version or 0, onboarded = row and row.onboarded == 1 or false }
    return cache[src]
end

local function status(src)
    local c = cache[src] or load(src)
    if not c then return { accepted = false, onboarded = false } end
    return { accepted = c.version >= R.version, onboarded = c.onboarded, version = R.version }
end

local function accept(src)
    local license = licenseOf(src)
    if not license then return false end
    local name = GetPlayerName(src) or ''
    MySQL.insert.await(
        'INSERT INTO server_rules_accepted (license, version, name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE version = VALUES(version), name = VALUES(name), accepted_at = CURRENT_TIMESTAMP',
        { license, R.version, name })
    cache[src] = cache[src] or { onboarded = false }
    cache[src].version = R.version
    pending[src] = nil
    exports.server_logs:Log('general', 'Regels geaccepteerd', ('%s accepteerde de serverregels (versie %d)'):format(exports.server_logs:Describe(src), R.version))
    return true
end

---------------------------------------------------------------------------
-- Callbacks / events
---------------------------------------------------------------------------
lib.callback.register('welcome:status', function(source)
    local ok, s = pcall(status, source)
    if not ok then
        -- database stuk: spelers NIET buitensluiten (fail open), wel melden
        print('^1[server_welcome]^7 Status ophalen mislukt: ' .. tostring(s))
        return { accepted = true, onboarded = true }
    end
    s.timeout = R.requireAcceptance and R.acceptTimeoutSeconds or nil
    return s
end)

lib.callback.register('welcome:accept', function(source)
    if not ServerCfg.Throttle(source, 'accept', 1000) then return false end
    return accept(source)
end)

lib.callback.register('welcome:onboarded', function(source)
    if not ServerCfg.Throttle(source, 'onb', 1000) then return false end
    local license = licenseOf(source)
    if not license then return false end
    -- alleen na akkoord
    if not status(source).accepted then return false end
    MySQL.update.await('UPDATE server_rules_accepted SET onboarded = 1 WHERE license = ?', { license })
    if cache[source] then cache[source].onboarded = true end
    return true
end)

RegisterNetEvent('welcome:decline', function()
    local src = source
    if not R.requireAcceptance or not R.kickOnDecline then return end
    if not ServerCfg.Throttle(src, 'decline', 1000) then return end
    if status(src).accepted then return end     -- al akkoord (dubbel klikken): geen kick
    exports.server_logs:Log('general', 'Regels geweigerd', exports.server_logs:Describe(src) .. ' ging niet akkoord met de regels.')
    DropPlayer(src, ServerCfg.T('welcome.declined_msg'))
end)

-- Noodoplossing: /akkoord in de chat
RegisterCommand(R.chatFallbackCommand, function(source)
    if source == 0 then return end
    if not ServerCfg.Throttle(source, 'accept', 1000) then return end
    if status(source).accepted then
        ServerCfg.Notify(source, 'inform', 'welcome.already_accepted')
        return
    end
    if accept(source) then
        ServerCfg.Notify(source, 'success', 'welcome.accepted')
        TriggerClientEvent('welcome:accepted', source)
    end
end, false)

-- Beheer: opnieuw akkoord laten geven (console of ESX-groep superadmin)
RegisterCommand('regelsreset', function(source, args)
    if source ~= 0 then
        local x = ESX.GetPlayerFromId(source)
        if not x or x.getGroup() ~= 'superadmin' then return end
    end
    local target = tonumber(args[1])
    local license = target and licenseOf(target)
    if not license then print('Gebruik: regelsreset <speler-id>') return end
    MySQL.update.await('UPDATE server_rules_accepted SET version = 0, onboarded = 0 WHERE license = ?', { license })
    cache[target] = nil
    exports.server_logs:Log('admin', 'Regels-akkoord gereset', ('%s reset het akkoord van %s'):format(source == 0 and 'Console' or exports.server_logs:Describe(source), exports.server_logs:Describe(target)))
end, false)

---------------------------------------------------------------------------
-- Afdwingen
---------------------------------------------------------------------------
AddEventHandler('esx:playerLoaded', function(playerId)
    cache[playerId] = nil
    local ok, s = pcall(status, playerId)
    if not ok then
        print('^1[server_welcome]^7 Akkoord-controle mislukt (database?): ' .. tostring(s) .. ' – speler wordt NIET gekickt.')
    elseif R.requireAcceptance and not s.accepted then
        pending[playerId] = GetGameTimer()
    end
end)

CreateThread(function()
    while true do
        Wait(10000)
        if R.requireAcceptance then
            local now = GetGameTimer()
            for src, since in pairs(pending) do
                if (now - since) / 1000 > R.acceptTimeoutSeconds then
                    pending[src] = nil
                    exports.server_logs:Log('general', 'Regels-timeout', exports.server_logs:Describe(src) .. ' gaf niet op tijd akkoord.')
                    DropPlayer(src, ServerCfg.T('welcome.timeout_msg'))
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    pending[source], cache[source] = nil, nil
end)

CreateThread(function()
    Wait(0)
    local ok = pcall(function() MySQL.scalar.await('SELECT 1 FROM server_rules_accepted LIMIT 1') end)
    if not ok then print('^1[server_welcome]^7 Tabel server_rules_accepted ontbreekt. Importeer sql/01_core.sql (spelers kunnen anders niet akkoord geven en worden gekickt!).') end
end)
