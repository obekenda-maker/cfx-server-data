-- Tests server_logs: batching, kanalen, 429-herpoging, database-audit
Mock.loadCore()
Mock.currentResource = 'server_logs'
local f = loadfile(ROOT .. '/resources/[admin]/server_logs/server.lua'); f()
Mock.stepThreads()
local Log = Mock.registry.server_logs.Log
Mock.registry.server_logs_real = Mock.registry.server_logs

Test.case('zonder webhook-convar niets verzenden, wel DB-audit voor money', function()
    DB.exec('DELETE FROM server_log_entries')
    Log('money', 'Test', 'omschrijving')
    Test.eq(#Mock.http, 0, 'geen HTTP zonder convar')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM server_log_entries'), 1, 'money-kanaal in database')
    Log('combat', 'Combat', 'niet in DB')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM server_log_entries'), 1, 'combat-kanaal niet in DB')
end)

Test.case('batching per webhook, fallback naar general, lengtebegrenzing', function()
    Mock.convars.dc_webhook_general = 'https://discord.test/general'
    Mock.convars.dc_webhook_admin = 'https://discord.test/admin'
    for i = 1, 12 do Log('admin', 'Titel ' .. i, string.rep('x', 9000)) end
    Log('combat', 'Valt terug', 'op general')
    Mock.stepThreads()
    local urls = {}
    for _, h in ipairs(Mock.http) do urls[h.url] = (urls[h.url] or 0) + 1 end
    Test.eq(urls['https://discord.test/admin'], 1, 'één request met max 10 embeds voor admin (rest volgt)')
    Test.eq(urls['https://discord.test/general'], 1, 'combat valt terug op general')
    Mock.stepThreads()
    local admin = 0
    for _, h in ipairs(Mock.http) do if h.url == 'https://discord.test/admin' then admin = admin + 1 end end
    Test.eq(admin, 2, 'tweede batch voor de overige embeds')
end)

Test.case('429: batch wordt teruggezet en pas later opnieuw verzonden', function()
    Mock.http = {}
    Log('admin', 'Rate limited', 'x')
    Mock.stepThreads()
    Test.eq(#Mock.http, 1, 'verzonden')
    Mock.http[1].cb(429, nil, { ['retry-after'] = '30' })
    local before = #Mock.http
    Mock.stepThreads()
    Test.eq(#Mock.http, before, 'tijdens wachttijd niet opnieuw verzonden')
end)
