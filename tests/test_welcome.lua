-- Tests server_welcome: akkoord (server-afgedwongen), timeout, decline, versies, onboarding, noodcommando, fail-open
Mock.loadAll()
local R = WelcomeCfg.Rules

local function reset()
    local srcs = {}
    for src in pairs(Mock.xPlayers) do srcs[#srcs + 1] = src end
    for _, src in ipairs(srcs) do Mock.removePlayer(src) end
    DB.exec('DELETE FROM server_rules_accepted')
    Mock.dropped, Mock.events, Mock.logs = nil, {}, {}
    R.version, R.requireAcceptance, R.kickOnDecline = 1, true, true
    Mock.advance(900000)
end
local function join(src, opts)
    local xp = Mock.addPlayer(src, opts)
    TriggerEvent('esx:playerLoaded', src, xp, true)
    return xp
end
local function tick() Mock.stepThreads() end

Test.case('nieuwe speler: niet akkoord → akkoord opslaan per license; geen kick daarna', function()
    reset(); join(1)
    local s = Mock.callback('welcome:status', 1)
    Test.eq(s.accepted, false, 'nog niet akkoord'); Test.eq(s.onboarded, false, 'onboarding niet gedaan')
    Test.eq(s.timeout, R.acceptTimeoutSeconds, 'timeout meegegeven aan de client')
    Test.eq(Mock.callback('welcome:onboarded', 1), false, 'onboarding vóór akkoord geweigerd')
    Test.ok(Mock.callback('welcome:accept', 1), 'akkoord')
    local row = DB.one('SELECT * FROM server_rules_accepted WHERE license = ?', { 'license:lic1' })
    Test.ok(row ~= nil and row.version == 1 and row.onboarded == 0, 'opgeslagen op Rockstar-license')
    Test.eq(Mock.callback('welcome:status', 1).accepted, true, 'status akkoord')
    Mock.advance((R.acceptTimeoutSeconds + 60) * 1000); tick()
    Test.eq(Mock.dropped, nil, 'akkoord-speler wordt niet gekickt na de timeout')
    Test.ok(#Mock.logsOf('general') >= 1, 'akkoord gelogd')
    Mock.advance(2000)
    Test.ok(Mock.callback('welcome:onboarded', 1), 'onboarding na akkoord')
    Test.eq(DB.scalar('SELECT onboarded FROM server_rules_accepted WHERE license = ?', { 'license:lic1' }), 1, 'onboarding bewaard')
end)

Test.case('server dwingt af: geen akkoord binnen de timeout = kick (client kan dit niet omzeilen)', function()
    reset(); join(1); join(2)
    Mock.callback('welcome:accept', 2)
    Mock.advance((R.acceptTimeoutSeconds - 30) * 1000); tick()
    Test.eq(Mock.dropped, nil, 'nog binnen de tijd')
    Mock.advance(60 * 1000); tick()
    Test.eq(Mock.dropped and Mock.dropped.src, 1, 'speler zonder akkoord gekickt')
    Test.ok(Mock.dropped.reason:find('regels', 1, true), 'duidelijke Nederlandse reden')
    Mock.dropped = nil; tick()
    Test.eq(Mock.dropped, nil, 'akkoord-speler (2) niet gekickt')
end)

Test.case('niet akkoord = kick; na akkoord geen kick door dubbele klik; spam begrensd', function()
    reset(); join(1); join(2)
    Mock.fire('welcome:decline', 1)
    Test.eq(Mock.dropped and Mock.dropped.src, 1, 'decline kickt')
    Mock.dropped = nil
    Mock.callback('welcome:accept', 2); Mock.advance(2000)
    Mock.fire('welcome:decline', 2)
    Test.eq(Mock.dropped, nil, 'wie al akkoord is wordt door een late decline niet gekickt')
    R.kickOnDecline = false
    join(3); Mock.fire('welcome:decline', 3)
    Test.eq(Mock.dropped, nil, 'kickOnDecline=false: geen kick')
    R.kickOnDecline = true
    Test.eq(Mock.callback('welcome:accept', 3), true, 'accept 1×')
    Test.eq(Mock.callback('welcome:accept', 3), false, 'accept-spam geweigerd (throttle)')
end)

Test.case('nieuwe regelversie vraagt opnieuw akkoord; alt-account/andere license is los', function()
    reset(); join(1)
    Mock.callback('welcome:accept', 1)
    Mock.removePlayer(1)
    R.version = 2
    join(1)
    Test.eq(Mock.callback('welcome:status', 1).accepted, false, 'v1 akkoord telt niet voor v2')
    Mock.callback('welcome:accept', 1)
    Test.eq(DB.scalar('SELECT version FROM server_rules_accepted WHERE license = ?', { 'license:lic1' }), 2, 'versie bijgewerkt')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM server_rules_accepted'), 1, 'geen dubbele rij (upsert)')
    join(2)
    Test.eq(Mock.callback('welcome:status', 2).accepted, false, 'andere license moet zelf akkoord geven')
    -- onboarding blijft bewaard bij nieuwe versie
    Mock.advance(2000); Mock.callback('welcome:onboarded', 1)
    R.version = 3
    Test.eq(Mock.callback('welcome:status', 1).onboarded, true, 'onboarding hoeft niet opnieuw bij nieuwe regelversie')
end)

Test.case('/akkoord als noodoplossing + beheer-reset (alleen console/superadmin)', function()
    reset(); join(1); Mock.addPlayer(2, { group = 'admin' }); Mock.addPlayer(3, { group = 'superadmin' })
    Test.eq(Mock.commands.akkoord(0), nil, 'console telt niet')
    Mock.commands.akkoord(1)
    Test.eq(Mock.callback('welcome:status', 1).accepted, true, '/akkoord werkt')
    Test.eq(#Mock.eventsNamed('welcome:accepted', 1), 1, 'client krijgt bevestiging (sluit de NUI)')
    Mock.advance(2000); Mock.clearEvents()
    Mock.commands.akkoord(1)
    Test.eq(#Mock.eventsNamed('welcome:accepted', 1), 0, 'tweede keer: niets (al akkoord)')
    Mock.commands.regelsreset(2, { '1' })
    Test.eq(Mock.callback('welcome:status', 1).accepted, true, 'admin (geen superadmin) kan niet resetten')
    Mock.commands.regelsreset(3, { '1' })
    Test.eq(Mock.callback('welcome:status', 1).accepted, false, 'superadmin reset')
    Test.eq(DB.scalar('SELECT onboarded FROM server_rules_accepted WHERE license = ?', { 'license:lic1' }), 0, 'ook onboarding gereset')
    Mock.commands.regelsreset(0, { '1' }); Mock.commands.regelsreset(0, { '999' })
end)

Test.case('database stuk = fail open: niemand wordt buitengesloten of gekickt', function()
    reset()
    DB.exec('RENAME TABLE server_rules_accepted TO server_rules_accepted_tmp')
    local ok = pcall(function()
        join(1)
        local s = Mock.callback('welcome:status', 1)
        Test.eq(s.accepted, true, 'status valt terug op toegestaan')
        Mock.advance((R.acceptTimeoutSeconds + 60) * 1000); tick()
        Test.eq(Mock.dropped, nil, 'geen kick zolang de database stuk is')
    end)
    DB.exec('RENAME TABLE server_rules_accepted_tmp TO server_rules_accepted')
    Test.ok(ok, 'test zonder fouten')
end)

Test.case('requireAcceptance = false: nooit een kick', function()
    reset(); R.requireAcceptance = false
    join(1)
    Mock.advance((R.acceptTimeoutSeconds + 600) * 1000); tick()
    Test.eq(Mock.dropped, nil, 'geen verplichting, geen kick')
    Test.eq(Mock.callback('welcome:status', 1).timeout, nil, 'client krijgt geen timeout')
    Mock.fire('welcome:decline', 1)
    Test.eq(Mock.dropped, nil, 'decline doet niets zonder verplichting')
    R.requireAcceptance = true
end)
