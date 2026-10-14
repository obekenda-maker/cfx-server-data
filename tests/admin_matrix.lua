-- Voert elke beheeractie uit als verschillende rollen en legt vast of de actie ECHT is uitgevoerd.
Mock.loadAll()
local ROLES = { 'user', 'mod', 'admin', 'superadmin', 'console' }
local ACTOR, TARGET = 1, 10
local forced = false
PRINTED = 0
local realPrint = print
print = function(...) PRINTED = PRINTED + 1 end   -- console-uitvoer van beheercommando's tellen

local function fresh(role)
    local srcs = {}
    for src in pairs(Mock.xPlayers) do srcs[#srcs + 1] = src end
    for _, s in ipairs(srcs) do Mock.removePlayer(s) end
    DB.exec('DELETE FROM admin_bans'); DB.exec('DELETE FROM admin_warnings'); DB.exec('DELETE FROM server_rules_accepted')
    Mock.dropped, Mock.events, Mock.logs = nil, {}, {}
    forced = false
    PRINTED = 0
    Mock.registry.combat_core = { IsInCombat = function() return false end, ForceLeave = function() forced = true return true end, GetPlayerZone = function() return nil end }
    Mock.advance(700000)
    if role ~= 'console' then Mock.addPlayer(ACTOR, { group = role, coords = { x = 0.0, y = 0.0, z = 30.0 }, name = 'Actor' }) end
    Mock.addPlayer(TARGET, { coords = { x = 100.0, y = 100.0, z = 30.0 }, name = 'Doel' })
    Mock.players[TARGET].health = 0
end
local function actor(role) return role == 'console' and 0 or ACTOR end

local ACTIONS = {
    { id = 'kick',        need = 'kick',   run = function(s) Mock.commands.kick(s, { '10', 'test' }) end,            seen = function() return Mock.dropped ~= nil end },
    { id = 'ban',         need = 'ban',    run = function(s) Mock.commands.ban(s, { '10', '1h', 'test' }) end,       seen = function() return DB.scalar('SELECT COUNT(*) FROM admin_bans') == 1 end },
    { id = 'ban (permanent)', need = 'permban', run = function(s) Mock.commands.ban(s, { '10', 'perm', 'test' }) end, seen = function() return DB.scalar('SELECT COUNT(*) FROM admin_bans WHERE expires_at IS NULL') == 1 end },
    { id = 'unban',       need = 'unban',  pre = function() DB.exec("INSERT INTO admin_bans (license, name, reason, banned_by, active) VALUES ('license:x', 'x', 'r', 'a', 1)") end,
      run = function(s) Mock.commands.unban(s, { tostring(DB.scalar('SELECT MAX(id) FROM admin_bans')) }) end, seen = function() return DB.scalar('SELECT COUNT(*) FROM admin_bans WHERE active = 1') == 0 end },
    { id = 'warn',        need = 'warn',   run = function(s) Mock.commands.warn(s, { '10', 'test' }) end,            seen = function() return DB.scalar('SELECT COUNT(*) FROM admin_warnings') == 1 end },
    { id = 'warnings',    need = 'warnings', run = function(s) Mock.commands.warnings(s, { '10' }) end,              seen = function() return #Mock.eventsNamed('admin_tools:showInfo') == 1 or PRINTED > 0 end },
    { id = 'checkplayer', need = 'check',  run = function(s) Mock.commands.checkplayer(s, { '10' }) end,             seen = function() return #Mock.eventsNamed('admin_tools:showInfo') == 1 or PRINTED > 0 end },
    { id = 'arevive',     need = 'revive', run = function(s) Mock.commands.arevive(s, { '10' }) end,                 seen = function() return #Mock.eventsNamed('rp_jobs:revived', TARGET) == 1 end },
    { id = 'goto',        need = 'teleport', run = function(s) Mock.commands['goto'](s, { '10' }) end,               seen = function() return Mock.players[ACTOR] and Mock.players[ACTOR].coords.x == 100.0 end, noConsole = true },
    { id = 'bring',       need = 'bring',  run = function(s) Mock.commands.bring(s, { '10' }) end,                   seen = function() return Mock.players[TARGET].coords.x == 0.0 end, noConsole = true },
    { id = 'pvpkick',     need = 'kick',   run = function(s) Mock.commands.pvpkick(s, { '10' }) end,                 seen = function() return forced end },
    { id = 'announce',    need = 'announce', run = function(s) Mock.commands.announce(s, { 'test' }) end,            seen = function() return #Mock.eventsNamed('chat:addMessage', -1) == 1 end },
    { id = 'menu: spelerslijst', need = 'menu', menu = true, run = function(s) return Mock.callback('admin_tools:getPlayers', s) end, seen = function(r) return r ~= nil end },
    { id = 'menu: kick', need = 'kick', menu = true, run = function(s) Mock.callback('admin_tools:action', s, 'kick', TARGET, { reason = 'x' }) end, seen = function() return Mock.dropped ~= nil end },
    { id = 'menu: ban',  need = 'ban',  menu = true, run = function(s) Mock.callback('admin_tools:action', s, 'ban', TARGET, { duration = '1h', reason = 'x' }) end, seen = function() return DB.scalar('SELECT COUNT(*) FROM admin_bans') == 1 end },
    { id = 'menu: teleport', need = 'bring', menu = true, run = function(s) Mock.callback('admin_tools:action', s, 'bring', TARGET, {}) end, seen = function() return Mock.players[TARGET].coords.x == 0.0 end },
    { id = '/coords (rechtencheck)', need = 'coords', menu = true, run = function(s) return Mock.callback('admin_tools:can', s, 'coords') end, seen = function(r) return r == true end },
    -- alleen superadmin/console
    { id = 'jobsync (console)', need = 'super', pre = function() DB.exec("UPDATE job_grades SET salary = 1 WHERE job_name = 'police' AND grade = 1") end,
      run = function(s) Mock.commands.jobsync(s) end, seen = function() return DB.scalar("SELECT salary FROM job_grades WHERE job_name = 'police' AND grade = 1") == 500 end },
    { id = 'regelsreset', need = 'super', pre = function() DB.exec("INSERT INTO server_rules_accepted (license, version) VALUES ('license:lic10', 1) ON DUPLICATE KEY UPDATE version = 1") end,
      run = function(s) Mock.commands.regelsreset(s, { '10' }) end, seen = function() return DB.scalar("SELECT version FROM server_rules_accepted WHERE license = 'license:lic10'") == 0 end },
}

MATRIX = { roles = ROLES, rows = {} }
for _, a in ipairs(ACTIONS) do
    local row = { id = a.id, need = a.need, results = {} }
    for _, role in ipairs(ROLES) do
        if (a.menu or a.noConsole) and role == 'console' then
            row.results[role] = 'n.v.t.'
        else
            fresh(role)
            if a.pre then a.pre() end
            local before = #Mock.logs
            local ok, r = pcall(a.run, actor(role))
            row.results[role] = (ok and a.seen(r)) and 'ja' or 'nee'
            if not ok then row.results[role] = 'FOUT: ' .. tostring(r) end
            row.logged = row.logged or (#Mock.logsOf('admin') > 0 and row.results[role] == 'ja')
        end
    end
    MATRIX.rows[#MATRIX.rows + 1] = row
end
MATRIX_JSON = json.encode(MATRIX)

print = realPrint
