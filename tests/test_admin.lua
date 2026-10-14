-- Tests admin_tools (server): rechten, bans (database + login-controle), waarschuwingen
Mock.loadCore()
Mock.load('admin_tools', 'resources/[admin]/admin_tools/server/main.lua')

local function reset()
    local srcs = {}
    for src in pairs(Mock.xPlayers) do srcs[#srcs + 1] = src end
    for _, src in ipairs(srcs) do Mock.removePlayer(src) end
    DB.exec('DELETE FROM admin_bans'); DB.exec('DELETE FROM admin_warnings')
    Mock.events, Mock.logs, Mock.dropped = {}, {}, nil
    Mock.registry.combat_core, Mock.registry.rp_gangs, Mock.registry.combat_stats = nil, nil, nil
    Mock.advance(600000)
end
local function at(x, y) return { x = x + 0.0, y = y + 0.0, z = 30.0 } end
local function bump() Mock.advance(1000) end

local function connect(src, name, ids)
    Mock.players[src] = Mock.players[src] or { coords = at(0, 0), name = name, identifiers = ids }
    Mock.players[src].identifiers = ids
    local result = { msg = nil, done = false }
    local deferrals = {
        defer = function() end, update = function() end,
        done = function(msg) result.done = true; result.msg = msg end,
    }
    Mock.fire('playerConnecting', src, name, function() end, deferrals)
    return result
end

Test.case('rechten per groep en actie', function()
    reset()
    Mock.addPlayer(1, { group = 'user' }); Mock.addPlayer(2, { group = 'mod' }); Mock.addPlayer(3, { group = 'admin' }); Mock.addPlayer(4, { group = 'superadmin' })
    Mock.addPlayer(10, {}); Mock.addPlayer(11, {})
    Test.no(exports.admin_tools:IsAdmin(1, 'kick'), 'gewone speler geen rechten')
    Test.ok(exports.admin_tools:IsAdmin(2, 'kick'), 'mod mag kicken')
    Test.no(exports.admin_tools:IsAdmin(2, 'ban'), 'mod mag niet bannen')
    Test.ok(exports.admin_tools:IsAdmin(3, 'ban'), 'admin mag bannen')
    Test.ok(exports.admin_tools:IsAdmin(0, 'ban'), 'console mag alles')

    Mock.commands.kick(1, { '10', 'test' })
    Test.eq(Mock.dropped, nil, 'user kan niet kicken')
    Mock.commands.kick(2, { '10', 'Spam', 'in', 'chat' })
    Test.eq(Mock.dropped.src, 10, 'mod kickt')
    Test.ok(Mock.dropped.reason:find('Spam in chat', 1, true), 'reden in bericht')
    Test.ok(#Mock.logsOf('admin') >= 1, 'kick gelogd')
    Mock.dropped = nil; bump()
    Mock.commands.kick(2, { '999', 'x' })
    Test.eq(Mock.dropped, nil, 'onbekende speler')
    Mock.commands.kick(2, { 'abc', 'x' })
    Test.eq(Mock.dropped, nil, 'ongeldig id')
    -- menu-callbacks controleren opnieuw
    Test.eq(Mock.callback('admin_tools:getPlayers', 1), nil, 'speler-lijst alleen voor staff')
    Test.ok(#Mock.callback('admin_tools:getPlayers', 2) >= 4, 'staff ziet lijst')
    Test.no(Mock.callback('admin_tools:action', 1, 'kick', 10, {}), 'menu-actie zonder rechten')
    Test.no(Mock.callback('admin_tools:action', 2, 'ban', 10, { duration = '1h' }), 'mod-menu kan niet bannen')
    bump(); bump()
    Test.no(Mock.callback('admin_tools:action', 3, 'format-c', 10, {}), 'onbekende actie')
end)

Test.case('ban: database, login geweigerd, ook via ander identifier, verlopen en unban', function()
    reset()
    Mock.addPlayer(3, { group = 'admin', name = 'Admin' }); Mock.addPlayer(10, { name = 'Boef' })
    Mock.commands.ban(3, { '10', '2h', 'Cheaten' })
    Test.eq(Mock.dropped.src, 10, 'speler verwijderd')
    local row = DB.one('SELECT * FROM admin_bans')
    Test.ok(row ~= nil and row.license == 'license:lic10' and row.discord == 'discord:dis10' and row.active == 1, 'ban in DB')
    Test.ok(row.expires_at ~= nil, 'einddatum gezet')
    Test.ok(Mock.dropped.reason:find('Cheaten', 1, true) and Mock.dropped.reason:find(tostring(row.id), 1, true), 'ban-id en reden in kick')

    local r = connect(50, 'Boef', { 'license:lic10', 'discord:dis10' })
    Test.ok(r.done and r.msg and r.msg:find('Cheaten', 1, true), 'verbinding geweigerd (licentie)')
    r = connect(51, 'Boef-alt', { 'license:nieuw', 'discord:dis10' })
    Test.ok(r.done and r.msg, 'verbinding geweigerd via gekoppeld discord-account')
    r = connect(52, 'Onschuldig', { 'license:ander', 'discord:ander' })
    Test.ok(r.done and r.msg == nil, 'andere speler mag verbinden')
    r = connect(53, 'Zonder', { 'fivem:1' })
    Test.ok(r.done and r.msg ~= nil, 'zonder license-identifier geweigerd')

    -- verlopen ban blokkeert niet meer
    DB.exec('UPDATE admin_bans SET expires_at = NOW() - INTERVAL 1 HOUR')
    r = connect(50, 'Boef', { 'license:lic10', 'discord:dis10' })
    Test.ok(r.msg == nil, 'verlopen ban')
    DB.exec('UPDATE admin_bans SET expires_at = NULL')
    r = connect(50, 'Boef', { 'license:lic10' })
    Test.ok(r.msg ~= nil, 'permanente ban')

    -- unban
    bump()
    Mock.commands.unban(3, { tostring(row.id) })
    r = connect(50, 'Boef', { 'license:lic10', 'discord:dis10' })
    Test.ok(r.msg == nil, 'na unban weer welkom')
    Test.eq(DB.scalar('SELECT active FROM admin_bans WHERE id = ?', { row.id }), 0, 'inactief in DB')
end)

Test.case('ban: duur-validatie, permanent alleen voor hoogste niveau, speler zonder discord', function()
    reset()
    Mock.addPlayer(3, { group = 'admin' }); Mock.addPlayer(4, { group = 'superadmin' }); Mock.addPlayer(10, {}); Mock.addPlayer(11, {})
    Mock.players[11].identifiers = { 'license:alleen' }
    Mock.commands.ban(3, { '10', 'abc', 'x' })
    Test.eq(DB.scalar('SELECT COUNT(*) FROM admin_bans'), 0, 'ongeldige duur')
    bump(); Mock.commands.ban(3, { '10', 'perm', 'x' })
    Test.eq(DB.scalar('SELECT COUNT(*) FROM admin_bans'), 0, 'admin mag niet permanent')
    Test.eq(Mock.dropped, nil, 'speler niet verwijderd')
    Mock.commands.ban(4, { '10', 'perm', 'Zwaar misbruik' })
    Test.eq(DB.scalar('SELECT COUNT(*) FROM admin_bans WHERE expires_at IS NULL'), 1, 'superadmin: permanent')
    bump(); Mock.commands.ban(4, { '11', '30m', 'kort' })
    Test.eq(DB.scalar('SELECT COUNT(*) FROM admin_bans WHERE license = ?', { 'license:alleen' }), 1, 'speler zonder discord kan worden verbannen')
    Test.eq(DB.scalar('SELECT discord FROM admin_bans WHERE license = ?', { 'license:alleen' }), '', 'ontbrekende id als lege string (geen nil-gat)')
    bump(); Mock.commands.ban(4, { '10', '999999d', 'lang' })
    local hours = DB.scalar("SELECT TIMESTAMPDIFF(HOUR, NOW(), MAX(expires_at)) FROM admin_bans WHERE reason = 'lang'")
    Test.ok(hours <= ServerCfg.Admin.maxBanHours + 1, 'maximale bandtijd begrensd')
end)

Test.case('waarschuwingen: tellen, automatische ban bij drempel, lijst', function()
    reset()
    Mock.addPlayer(2, { group = 'mod' }); Mock.addPlayer(10, { name = 'Speler' })
    for i = 1, 2 do Mock.commands.warn(2, { '10', 'Overtreding', tostring(i) }); bump() end
    Test.eq(DB.scalar('SELECT COUNT(*) FROM admin_warnings WHERE license = ?', { 'license:lic10' }), 2, 'twee waarschuwingen')
    Test.eq(#Mock.eventsNamed('ox_lib:notify', 10), 2, 'speler wordt ingelicht')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM admin_bans'), 0, 'nog geen ban')
    Mock.commands.warn(2, { '10', 'Derde' })
    Test.eq(DB.scalar('SELECT COUNT(*) FROM admin_bans'), 1, 'automatische ban bij drempel')
    Test.eq(Mock.dropped.src, 10, 'speler verwijderd')
    bump(); Mock.addPlayer(10, { name = 'Speler' }); Mock.clearEvents()
    Mock.commands.warnings(2, { '10' })
    Test.eq(#Mock.eventsNamed('admin_tools:showInfo', 2), 1, 'lijst naar admin')
    Mock.clearEvents(); bump()
    Mock.commands.checkplayer(2, { '10' })
    local info = Mock.eventsNamed('admin_tools:showInfo', 2)[1]
    Test.ok(info and info.args[1]:find('Speler', 1, true) and info.args[1]:find('Waarschuwingen: 3', 1, true), 'spelercontrole toont gegevens')
end)

Test.case('teleport & overige: rechten gelden ook hier', function()
    reset()
    Mock.addPlayer(2, { group = 'mod', coords = at(0, 0) }); Mock.addPlayer(3, { group = 'admin', coords = at(0, 0) }); Mock.addPlayer(10, { coords = at(100, 100) })
    Mock.commands.bring(2, { '10' })   -- mod: niveau 1 < bring (2)
    Test.eq(Mock.players[10].coords.x, 100.0, 'mod kan niet halen')
    bump(); Mock.commands.bring(3, { '10' })
    Test.eq(Mock.players[10].coords.x, 0.0, 'admin haalt speler')
    bump(); Mock.commands['goto'](2, { '10' })
    bump(); Mock.commands.announce(2, { 'test' })
    Test.eq(#Mock.eventsNamed('chat:addMessage'), 0, 'mod kan niet aankondigen')
    Mock.commands.announce(3, { 'Serveronderhoud' })
    Test.eq(#Mock.eventsNamed('chat:addMessage', -1), 1, 'admin kondigt aan')
end)
