-- Tests rp_garages, rp_shops, rp_interactions (server)
Mock.loadCore()
Mock.load('rp_garages', 'resources/[roleplay]/rp_garages/config.lua')
Mock.load('rp_garages', 'resources/[roleplay]/rp_garages/server/main.lua')
Mock.load('rp_shops', 'resources/[roleplay]/rp_shops/config.lua')
Mock.load('rp_shops', 'resources/[roleplay]/rp_shops/server/main.lua')
Mock.load('rp_interactions', 'resources/[roleplay]/rp_interactions/config.lua')
Mock.load('rp_interactions', 'resources/[roleplay]/rp_interactions/server/main.lua')

local function at(x, y, z) return { x = x + 0.0, y = y + 0.0, z = (z or 30.0) + 0.0 } end
local function c3(v) return at(v.x, v.y, v.z) end

local function reset()
    local srcs = {}
    for src in pairs(Mock.xPlayers) do srcs[#srcs + 1] = src end
    for _, src in ipairs(srcs) do Mock.removePlayer(src) end
    for e in pairs(Mock.vehicles) do Mock.vehicles[e] = nil end
    DB.exec('DELETE FROM owned_vehicles')
    Mock.events, Mock.logs = {}, {}
    Mock.registry.combat_core = nil
    Mock.advance(300000)
end

---------------------------------------------------------------------------
Test.case('voertuigwinkel: prijs, afstand, saldo, uniek kenteken', function()
    reset()
    local shop = GarageCfg.Shop
    local xp = Mock.addPlayer(1, { coords = c3(shop.coords), bank = 20000 })
    local r = Mock.callback('rp_garages:buy', 1, 'blista')
    Test.ok(r.ok, 'gekocht')
    Test.eq(xp.accounts.bank, 20000 - 9500, 'prijs afgeschreven')
    local row = DB.one('SELECT * FROM owned_vehicles WHERE owner = ?', { xp.identifier })
    Test.ok(row ~= nil, 'rij in owned_vehicles')
    Test.eq(row.stored, 1, 'staat in garage')
    Test.ok(row.plate:match('^%u%u %d%d%d %u$') ~= nil, 'kentekenformaat')
    Test.eq(json.decode(row.vehicle).model, joaat('blista'), 'model-hash in vehicle-json')

    Mock.advance(4000)
    Test.eq(Mock.callback('rp_garages:buy', 1, 'adder').msg, 'garage.invalid', 'model niet in catalogus')
    Mock.advance(4000)
    Test.eq(Mock.callback('rp_garages:buy', 1, "x'; DROP TABLE owned_vehicles;--").msg, 'garage.invalid', 'injectiepoging geweigerd')
    Mock.advance(4000)
    xp.accounts.bank = 100
    Test.eq(Mock.callback('rp_garages:buy', 1, 'dominator').msg, 'garage.no_money', 'te weinig geld')
    Test.eq(xp.accounts.bank, 100, 'niets afgeschreven')
    Mock.advance(4000)
    xp.accounts.bank = 99999; Mock.players[1].coords = at(0, 0)
    Test.eq(Mock.callback('rp_garages:buy', 1, 'blista').msg, 'garage.too_far', 'te ver van dealer')
    Test.eq(DB.scalar('SELECT COUNT(*) FROM owned_vehicles'), 1, 'geen extra voertuigen')
end)

Test.case('garage: uitparkeren is atomisch, opslaan controleert eigenaar/model/afstand', function()
    reset()
    local g = GarageCfg.Garages[1]
    local xp = Mock.addPlayer(1, { coords = c3(g.coords) })
    local other = Mock.addPlayer(2, { coords = c3(g.coords) })
    DB.exec('INSERT INTO owned_vehicles (owner, plate, vehicle, `type`, `stored`) VALUES (?, ?, ?, ?, 1)',
        { xp.identifier, 'AB 123 C', json.encode({ model = joaat('blista'), plate = 'AB 123 C', fuelLevel = 80 }), 'car' })

    local list = Mock.callback('rp_garages:list', 1, g.id)
    Test.eq(#list, 1, 'voertuig in lijst')
    Test.eq(list[1].plate, 'AB 123 C', 'kenteken in lijst')
    Test.eq(#Mock.callback('rp_garages:list', 2, g.id), 0, 'anderen zien het niet')

    Test.eq(Mock.callback('rp_garages:retrieve', 2, g.id, 'AB 123 C').msg, 'garage.not_owner', 'niet van jou')
    Mock.advance(2000)
    local r = Mock.callback('rp_garages:retrieve', 1, g.id, ' AB 123 C ')
    Test.ok(r.ok, 'uitparkeren')
    Test.eq(r.props.fuelLevel, 80, 'props meegegeven')
    Test.eq(DB.scalar('SELECT `stored` FROM owned_vehicles WHERE plate = ?', { 'AB 123 C' }), 0, 'stored = 0')
    Mock.advance(2000)
    local r2 = Mock.callback('rp_garages:retrieve', 1, g.id, 'AB 123 C')
    Test.no(r2.ok, 'tweede keer uitparkeren mislukt (geen dupliceren)')

    -- spawn mislukt → restore
    Test.ok(Mock.callback('rp_garages:restore', 1, 'AB 123 C'), 'restore')
    Test.eq(DB.scalar('SELECT `stored` FROM owned_vehicles WHERE plate = ?', { 'AB 123 C' }), 1, 'weer opgeslagen')
    Mock.advance(20000)
    Mock.callback('rp_garages:retrieve', 1, g.id, 'AB 123 C')

    -- opslaan: voertuig in de wereld
    Mock.advance(2000)
    local net = Mock.addVehicle(41, 'blista', 'AB 123 C', c3(g.coords))
    local props = { model = joaat('adder'), plate = 'HACK', fuelLevel = 55, bodyHealth = 900 }
    Test.eq(Mock.callback('rp_garages:store', 2, g.id, net, props).msg, 'garage.not_owner', 'niet-eigenaar kan niet opslaan')
    Mock.advance(2000)
    local s = Mock.callback('rp_garages:store', 1, g.id, net, props)
    Test.ok(s.ok, 'opslaan')
    local row = DB.one('SELECT * FROM owned_vehicles WHERE plate = ?', { 'AB 123 C' })
    local saved = json.decode(row.vehicle)
    Test.eq(row.stored, 1, 'stored = 1')
    Test.eq(saved.model, joaat('blista'), 'model kan niet worden omgewisseld')
    Test.eq(saved.plate, 'AB 123 C', 'kenteken kan niet worden gewijzigd')
    Test.eq(saved.fuelLevel, 55, 'nieuwe props opgeslagen')
    Test.eq(Mock.deleted, 41, 'voertuig verwijderd uit de wereld')

    -- model komt niet overeen met registratie
    DB.exec('UPDATE owned_vehicles SET `stored` = 0')
    local net2 = Mock.addVehicle(42, 'adder', 'AB 123 C', c3(g.coords))
    Mock.advance(2000)
    Test.eq(Mock.callback('rp_garages:store', 1, g.id, net2, props).msg, 'garage.model_mismatch', 'ander model dan geregistreerd')
    -- te ver
    Mock.vehicles[42].model = joaat('blista'); Mock.vehicles[42].coords = at(900, 900)
    Mock.advance(2000)
    Test.eq(Mock.callback('rp_garages:store', 1, g.id, net2, props).msg, 'garage.too_far', 'voertuig te ver van garage')
end)

Test.case('depot: kosten, niet voor voertuigen in garage of op de weg', function()
    reset()
    local imp = GarageCfg.Impound
    local xp = Mock.addPlayer(1, { coords = c3(imp.coords), bank = 2000, money = 0 })
    DB.exec('INSERT INTO owned_vehicles (owner, plate, vehicle, `type`, `stored`) VALUES (?, ?, ?, ?, 0)', { xp.identifier, 'DE 456 F', json.encode({ model = joaat('asea') }), 'car' })
    DB.exec('INSERT INTO owned_vehicles (owner, plate, vehicle, `type`, `stored`) VALUES (?, ?, ?, ?, 1)', { xp.identifier, 'GA 789 R', json.encode({ model = joaat('asea') }), 'car' })
    local list = Mock.callback('rp_garages:impoundList', 1)
    Test.eq(#list, 1, 'alleen niet-opgeslagen voertuigen')
    Mock.addVehicle(51, 'asea', 'DE 456 F', at(5, 5))
    Test.eq(#Mock.callback('rp_garages:impoundList', 1), 0, 'voertuig dat nog op de weg staat niet in depot')
    Test.eq(Mock.callback('rp_garages:impoundRetrieve', 1, 'DE 456 F').msg, 'garage.in_world', 'op de weg')
    Mock.vehicles[51] = nil
    Mock.advance(3000)
    Test.eq(Mock.callback('rp_garages:impoundRetrieve', 1, 'GA 789 R').msg, 'garage.in_garage', 'staat in garage')
    Mock.advance(3000)
    local r = Mock.callback('rp_garages:impoundRetrieve', 1, 'DE 456 F')
    Test.ok(r.ok, 'ophalen')
    Test.eq(xp.accounts.bank, 2000 - imp.fee, 'depotkosten betaald')
    Mock.advance(3000)
    Test.eq(Mock.callback('rp_garages:impoundRetrieve', 1, 'DE 456 F').msg, 'garage.locked', 'kenteken tijdelijk vergrendeld')
end)

---------------------------------------------------------------------------
Test.case('winkel: prijs, afstand, account, PvP-blokkade, limieten', function()
    reset()
    local shop = ShopCfg.Shops[1]
    local xp = Mock.addPlayer(1, { coords = c3(shop.coords), money = 100, bank = 0 })
    local r = Mock.callback('rp_shops:buy', 1, shop.id, 'bread', 3, 'money')
    Test.ok(r.ok, 'gekocht')
    Test.eq(xp.money, 100 - 15, 'bedrag afgeschreven')
    Test.eq(xp.inventory.bread, 3, 'items ontvangen')
    Mock.advance(1000)
    Test.eq(Mock.callback('rp_shops:buy', 1, shop.id, 'bread', 1, 'hackmoney').msg, 'shop.no_money', 'ongeldig account')
    Mock.advance(1000)
    Test.eq(Mock.callback('rp_shops:buy', 1, shop.id, 'bread', -5, 'money').msg, 'shop.invalid', 'negatief aantal')
    Mock.advance(1000)
    Test.eq(Mock.callback('rp_shops:buy', 1, shop.id, 'bread', 9999, 'money').msg, 'shop.invalid', 'te groot aantal')
    Mock.advance(1000)
    Test.eq(Mock.callback('rp_shops:buy', 1, shop.id, 'lockpick', 1, 'money').msg, 'shop.invalid', 'item niet in catalogus')
    Mock.advance(1000)
    Test.eq(Mock.callback('rp_shops:buy', 1, shop.id, 'medkit', 5, 'money').msg, 'shop.no_money', 'te weinig geld')
    Mock.advance(1000)
    xp.noCarry = true
    Test.eq(Mock.callback('rp_shops:buy', 1, shop.id, 'bread', 1, 'money').msg, 'shop.cannot_carry', 'inventaris vol')
    xp.noCarry = false
    Mock.advance(1000)
    Mock.registry.combat_core = { IsInCombat = function() return true end }
    Test.eq(Mock.callback('rp_shops:buy', 1, shop.id, 'bread', 1, 'money').msg, 'shop.in_combat', 'geen aankoop in PvP')
    Mock.registry.combat_core = nil
    Mock.players[1].coords = at(0, 0)
    Mock.advance(1000)
    Test.eq(Mock.callback('rp_shops:buy', 1, shop.id, 'bread', 1, 'money').msg, 'shop.too_far', 'te ver')
end)

Test.case('bruikbare items: effect, verbruik, geblokkeerd in PvP', function()
    reset()
    local xp = Mock.addPlayer(1, { coords = at(0, 0) })
    Test.ok(Mock.usable.burger and Mock.usable.medkit, 'items geregistreerd')
    Test.no(Mock.usable.bread, 'bread/water niet overschreven (esx_basicneeds)')
    xp.addInventoryItem('burger', 2)
    Mock.usable.burger(1)
    Test.eq(xp.inventory.burger, 1, 'item verbruikt')
    Test.eq(#Mock.eventsNamed('esx_status:add', 1), 1, 'honger aangevuld')
    Test.eq(#Mock.eventsNamed('esx_basicneeds:onEat', 1), 1, 'eet-animatie')
    Mock.advance(3000)
    Mock.registry.combat_core = { IsInCombat = function() return true end }
    Mock.usable.burger(1)
    Test.eq(xp.inventory.burger, 1, 'niet verbruikt tijdens PvP')
    Mock.registry.combat_core = nil
    xp.addInventoryItem('medkit', 1)
    Mock.advance(3000)
    Mock.usable.medkit(1)
    Test.eq(#Mock.eventsNamed('rp_shops:heal', 1), 1, 'genezing')
end)

Test.case('Ammu-Nation: licentie vereist, geen dubbele wapens', function()
    reset()
    local licenses = {}
    AddEventHandler('esx_license:checkLicense', function(src, kind, cb) cb(licenses[src] == kind) end)
    AddEventHandler('esx_license:addLicense', function(src, kind, cb) licenses[src] = kind cb() end)
    local ammu
    for _, s in ipairs(ShopCfg.Shops) do if s.type == 'weapons' then ammu = s end end
    local xp = Mock.addPlayer(1, { coords = c3(ammu.coords), money = 20000 })
    Test.eq(Mock.callback('rp_shops:buyWeapon', 1, ammu.id, 'WEAPON_PISTOL', 'money').msg, 'shop.need_license', 'zonder licentie')
    Mock.advance(3000)
    Test.ok(Mock.callback('rp_shops:buyLicense', 1, ammu.id, 'money').ok, 'licentie gekocht')
    Test.eq(xp.money, 20000 - ShopCfg.WeaponShop.licensePrice, 'licentiekosten')
    Mock.advance(3000)
    Test.ok(Mock.callback('rp_shops:buyWeapon', 1, ammu.id, 'WEAPON_PISTOL', 'money').ok, 'wapen gekocht')
    Test.ok(xp.hasWeapon('WEAPON_PISTOL'), 'in loadout')
    Mock.advance(3000)
    Test.eq(Mock.callback('rp_shops:buyWeapon', 1, ammu.id, 'WEAPON_PISTOL', 'money').msg, 'shop.have_weapon', 'niet dubbel')
    Mock.advance(3000)
    Test.eq(Mock.callback('rp_shops:buyWeapon', 1, ammu.id, 'WEAPON_RPG', 'money').msg, 'shop.invalid', 'wapen niet in assortiment')
end)

---------------------------------------------------------------------------
Test.case('geld/items geven: server-validatie', function()
    reset()
    local a = Mock.addPlayer(1, { coords = at(0, 0), money = 500 })
    local b = Mock.addPlayer(2, { coords = at(2, 0), money = 0 })
    local c = Mock.addPlayer(3, { coords = at(100, 0) })
    local give = Mock.commands.geefgeld
    give(1, { '2', '200' })
    Test.eq(a.money, 300, 'afgeschreven'); Test.eq(b.money, 200, 'ontvangen')
    Mock.advance(4000); give(1, { '2', '-50' })
    Test.eq(a.money, 300, 'negatief bedrag geweigerd'); Test.eq(b.money, 200, 'ontvanger onveranderd')
    Mock.advance(4000); give(1, { '3', '10' })
    Test.eq(a.money, 300, 'te ver weg'); Test.eq(c.money, 1000, 'ver weg onveranderd')
    Mock.advance(4000); give(1, { '2', '999999' })
    Test.eq(a.money, 300, 'boven maximum')
    Mock.advance(4000); give(1, { '2', '5000' })
    Test.eq(a.money, 300, 'meer dan bezit')
    Mock.advance(4000); give(1, { '1', '10' })
    Test.eq(a.money, 300, 'jezelf geven kan niet')
    Mock.advance(4000); give(1, { '2', '1e9' })
    Test.eq(a.money, 300, 'onzinbedrag')
    Mock.registry.combat_core = { IsInCombat = function() return true end }
    Mock.advance(4000); give(1, { '2', '10' })
    Test.eq(a.money, 300, 'niet tijdens PvP')
    Mock.registry.combat_core = nil
    -- items
    a.addInventoryItem('bread', 3)
    Mock.advance(4000); Mock.commands.geefitem(1, { '2', 'bread', '2' })
    Test.eq(a.inventory.bread, 1, 'item afgenomen'); Test.eq(b.inventory.bread, 2, 'item ontvangen')
    Mock.advance(4000); Mock.commands.geefitem(1, { '2', 'bread', '5' })
    Test.eq(a.inventory.bread, 1, 'meer dan bezit geweigerd')
end)

Test.case('/me, /do: alleen dichtbij, schoongemaakt en begrensd', function()
    reset()
    Mock.addPlayer(1, { coords = at(0, 0) }); Mock.addPlayer(2, { coords = at(10, 0) }); Mock.addPlayer(3, { coords = at(80, 0) })
    Mock.commands.me(1, { 'pakt', 'een', 'sleutel\nuit', 'zak' })
    local ev = Mock.eventsNamed('rp_interactions:show')
    Test.eq(#ev, 2, 'alleen spelers binnen bereik (1 en 2)')
    Test.eq(ev[1].args[3], 'pakt een sleutel uit zak', 'besturingstekens verwijderd')
    Mock.clearEvents()
    Mock.advance(100)
    Mock.commands['do'](1, { 'x' })
    Test.eq(#Mock.eventsNamed('rp_interactions:show'), 0, 'rate-limit')
    Mock.advance(5000)
    Mock.commands['do'](1, { string.rep('a', 500) })
    Test.eq(#Mock.eventsNamed('rp_interactions:show')[1].args[3], InterCfg.ChatMaxLength, 'lengte begrensd')
end)
