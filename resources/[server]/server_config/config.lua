--[[
    SERVER_CONFIG – centrale instellingen voor de hele server.
    Dit bestand wordt door alle eigen resources geladen als shared script.

    GEHEIMEN (webhooks, database-wachtwoord) staan HIER NIET. Die zet je in
    secrets.cfg (zie secrets.cfg.example) als convar met `set ...` (NIET `setr`).
]]

ServerCfg = ServerCfg or {}

---------------------------------------------------------------------------
-- Branding
---------------------------------------------------------------------------
ServerCfg.Server = {
    name      = 'Nederland Combat RP',
    shortName = 'NLCRP',
    discord   = 'https://discord.gg/jouw-invite',   -- alleen tekst, geen geheim
    website   = '',
}

---------------------------------------------------------------------------
-- Kleuren (hex). Worden gebruikt door HUD/NUI en Discord-embeds.
---------------------------------------------------------------------------
ServerCfg.Colors = {
    primary   = '#ff6a00',
    secondary = '#2d9cff',
    success   = '#2ecc71',
    danger    = '#e74c3c',
    warning   = '#f1c40f',
    info      = '#3498db',
    panel     = 'rgba(12, 14, 20, 0.78)',
    text      = '#f4f6fa',
    muted     = '#9aa4b2',
}

---------------------------------------------------------------------------
-- HUD (server_hud)
---------------------------------------------------------------------------
ServerCfg.Hud = {
    enabled        = true,
    position       = 'bottom-right', -- statusbalken: 'bottom-left' | 'bottom-right' | 'top-left' | 'top-right'
                                     -- (de GTA-minimap staat linksonder, vandaar standaard rechtsonder)
    moneyPosition  = 'top-right',    -- geld/job-paneel: 'top-left' | 'top-right'
    killfeedPosition = 'top-right',  -- killfeed (onder het geldpaneel): 'top-left' | 'top-right'
    scale          = 1.0,            -- 0.7 – 1.3
    speedUnit      = 'kmh',          -- 'kmh' | 'mph'
    hideGameHud    = true,           -- verberg standaard GTA-HUD-onderdelen (geld, gebiedsnaam, ...)
    showHunger     = true,           -- alleen zichtbaar als esx_status draait
    showThirst     = true,
    showMoney      = true,
    showBank       = true,
    showJob        = true,
    showVehicle    = true,
    showAmmo       = true,
    showKillfeed   = true,
    killfeedMax    = 6,
    killfeedSeconds = 7,
    leaderboardKey = 'F7',           -- ingedrukt houden
    leaderboardRows = 10,
    updateMs       = 200,
}

---------------------------------------------------------------------------
-- Notificaties
---------------------------------------------------------------------------
ServerCfg.NotifyCfg = {
    position = 'top-right',
    duration = 5000,
}

---------------------------------------------------------------------------
-- Beheer (admin_tools)
-- Rechten zijn gebaseerd op de ESX-groep van de speler (xPlayer.getGroup()).
-- Een hogere waarde = meer rechten. Groepen die hier niet staan hebben geen rechten.
---------------------------------------------------------------------------
ServerCfg.Admin = {
    groups = {
        mod        = 1,
        admin      = 2,
        superadmin = 3,
    },
    -- minimaal benodigd niveau per actie
    levels = {
        menu     = 1,
        kick     = 1,
        warn     = 1,
        warnings = 1,
        teleport = 1,
        bring    = 2,
        revive   = 1,
        check    = 1,
        ban      = 2,
        unban    = 2,
        coords   = 1,
        announce = 2,
    },
    warnBanThreshold = 3,        -- na zoveel waarschuwingen automatisch tijdelijk ban (0 = uit)
    warnBanHours     = 24,
    maxBanHours      = 24 * 365, -- tijdelijke ban maximaal; 'perm' alleen voor niveau >= permBanLevel
    permBanLevel     = 3,
    reasonMaxLength  = 200,
}

---------------------------------------------------------------------------
-- Logging (server_logs). Webhook-URL's komen uit convars (secrets.cfg).
-- Hier staat alleen de NAAM van de convar per kanaal.
---------------------------------------------------------------------------
ServerCfg.Webhooks = {
    general    = 'dc_webhook_general',
    admin      = 'dc_webhook_admin',
    money      = 'dc_webhook_money',
    combat     = 'dc_webhook_combat',
    gang       = 'dc_webhook_gang',
    suspicious = 'dc_webhook_suspicious',
}

ServerCfg.Logs = {
    username     = 'Server Logs',
    avatar       = '',
    flushMs      = 2000,
    maxEmbedsPerRequest = 10,
    -- kanalen die óók in de database worden bewaard (tabel server_log_entries)
    dbChannels   = { money = true, admin = true, suspicious = true, gang = true },
    keepDays     = 30,
    colors = {
        general = '#3498db', admin = '#e67e22', money = '#2ecc71',
        combat = '#e74c3c', gang = '#9b59b6', suspicious = '#ff0033',
    },
}

---------------------------------------------------------------------------
-- Gedeelde helpers (client + server)
---------------------------------------------------------------------------
function ServerCfg.T(key, ...)
    local text = ServerCfg.Locale and ServerCfg.Locale[key]
    if not text then
        return key
    end
    if select('#', ...) > 0 then
        local ok, res = pcall(string.format, text, ...)
        if ok then return res end
        return text
    end
    return text
end

--- Stuur een notificatie. Server: Notify(src, type, key, ...) – Client: Notify(nil, type, key, ...)
--- type: 'inform' | 'success' | 'error' | 'warning'
function ServerCfg.Notify(src, ntype, key, ...)
    local payload = {
        title       = ServerCfg.Server.shortName,
        description = ServerCfg.T(key, ...),
        type        = ntype or 'inform',
        position    = ServerCfg.NotifyCfg.position,
        duration    = ServerCfg.NotifyCfg.duration,
    }
    if IsDuplicityVersion() then
        if src then TriggerClientEvent('ox_lib:notify', src, payload) end
    else
        TriggerEvent('ox_lib:notify', payload)
    end
end

function ServerCfg.Round(n, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor((n or 0) * m + 0.5) / m
end

--- Geeft true als tabel `list` de waarde bevat.
function ServerCfg.Contains(list, value)
    for _, v in ipairs(list or {}) do
        if v == value then return true end
    end
    return false
end

--- Verwijder spaties aan begin en einde.
function ServerCfg.Trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

--- Hex (#rrggbb) naar integer (Discord).
function ServerCfg.HexToInt(hex)
    return tonumber((tostring(hex or '#ffffff'):gsub('#', '')), 16) or 16777215
end

---------------------------------------------------------------------------
-- Gedeelde SERVER-helpers (één implementatie voor alle resources)
---------------------------------------------------------------------------
if IsDuplicityVersion() then
    local last = {}   -- per resource-instantie

    --- Rate-limit per speler+sleutel. true = toegestaan.
    function ServerCfg.Throttle(src, key, ms)
        local id = src .. ':' .. key
        local now = GetGameTimer()
        if (last[id] or -1e9) + ms > now then return false end
        last[id] = now
        return true
    end

    AddEventHandler('playerDropped', function()
        local prefix = source .. ':'
        for k in pairs(last) do
            if k:sub(1, #prefix) == prefix then last[k] = nil end
        end
    end)

    --- Server-side coördinaten van een speler (OneSync) als {x,y,z} of nil
    function ServerCfg.CoordsOf(src)
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return nil end
        local c = GetEntityCoords(ped)
        return { x = c.x, y = c.y, z = c.z }
    end

    function ServerCfg.Distance(a, b)
        local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
        return math.sqrt(dx * dx + dy * dy + dz * dz)
    end

    --- Staat de speler binnen maxDist van punt (tabel/vector met x,y,z)?
    function ServerCfg.PlayerNear(src, point, maxDist)
        local c = ServerCfg.CoordsOf(src)
        return c ~= nil and ServerCfg.Distance(c, point) <= maxDist
    end

    --- Afstand tussen twee spelers of nil
    function ServerCfg.PlayerDistance(a, b)
        local ca, cb = ServerCfg.CoordsOf(a), ServerCfg.CoordsOf(b)
        if not ca or not cb then return nil end
        return ServerCfg.Distance(ca, cb)
    end

    --- Doet de speler mee aan PvP (combat_core)? Bij twijfel/afwezige resource: false.
    function ServerCfg.InCombat(src)
        local ok, res = pcall(function() return exports.combat_core:IsInCombat(src) end)
        return ok and res == true
    end

    --- Betaal `amount` van één account ('money' = contant). false bij te weinig saldo.
    function ServerCfg.Pay(xPlayer, account, amount, reason)
        if account == 'money' then
            if xPlayer.getMoney() < amount then return false end
            xPlayer.removeMoney(amount, reason)
        else
            local acc = xPlayer.getAccount(account)
            if not acc or acc.money < amount then return false end
            xPlayer.removeAccountMoney(account, amount, reason)
        end
        return true
    end

    --- Haal tot `amount` bij een speler: eerst contant, dan bank. Geeft het werkelijk afgeschreven bedrag.
    function ServerCfg.Charge(xPlayer, amount, reason)
        amount = math.floor(amount)
        if amount <= 0 then return 0 end
        local fromCash = math.min(xPlayer.getMoney(), amount)
        if fromCash > 0 then xPlayer.removeMoney(fromCash, reason) end
        local fromBank = 0
        local rest = amount - fromCash
        if rest > 0 then
            fromBank = math.min(xPlayer.getAccount('bank').money, rest)
            if fromBank > 0 then xPlayer.removeAccountMoney('bank', fromBank, reason) end
        end
        return fromCash + fromBank
    end
end
