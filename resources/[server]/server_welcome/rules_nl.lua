--[[
    SERVERREGELS (Nederlands). Dit is de bron voor: de in-game regels (/regels), de akkoord-pagina,
    docs/SERVERREGELS.md en docs/welkom.html (gegenereerd door scripts/gen_welcome_docs.py).
    Wijzig je iets: verhoog WelcomeCfg.Rules.version en draai `python3 scripts/gen_welcome_docs.py`.
]]

WelcomeRules = {
    { title = 'Algemeen', items = {
        'Behandel iedereen met respect. Discriminatie, haatzaaien, bedreigingen en pesten zijn verboden.',
        'De voertaal op de server is Nederlands.',
        'Luister naar de aanwijzingen van het team (beheerders en moderators). Bezwaar? Maak dat achteraf via Discord kenbaar, niet in het spel.',
        'Eén account per persoon. Het delen of verkopen van accounts is niet toegestaan.',
        'Deel nooit persoonlijke gegevens van jezelf of anderen.',
    } },
    { title = 'Roleplay', items = {
        'Blijf in je rol en speel realistisch. Gedrag dat in het echt onmogelijk is (FailRP) is niet toegestaan.',
        'Geen RDM (Random Deathmatch): doden zonder geldige roleplayreden en zonder voorafgaand rollenspel is verboden.',
        'Geen VDM (Vehicle Deathmatch): gebruik voertuigen niet als wapen.',
        'Geen metagaming: gebruik informatie die je buiten het spel (Discord, stream, andere personages) hebt niet in het spel.',
        'Geen powergaming: forceer geen acties bij anderen zonder hen een kans te geven te reageren.',
        'Na een reanimatie of ziekenhuisopname herinner je je het voorval niet (New Life Rule) en ga je niet terug voor wraak.',
        'Combat logging (de server verlaten om een situatie of een boete te ontlopen) is verboden.',
    } },
    { title = 'PvP en combat zones', items = {
        'PvP is alleen toegestaan in de gemarkeerde combat zones en alleen voor spelers die vrijwillig meedoen.',
        'Buiten de zones geldt: geen geweld zonder roleplayreden en voorafgaand rollenspel.',
        'Beschermde roleplaygebieden (politiebureau, ziekenhuis, garages, winkels, Jobcentrum, depots) zijn nooit een PvP-gebied.',
        'Combatwapens en -beloningen horen bij de zone: wat je daar krijgt, neem je niet mee naar het roleplaygedeelte.',
        'Misbruik van beloningen is verboden: kills ruilen of boosten met vrienden, alternatieve accounts of afgesproken kills.',
        'Geen spawncamping: blijf niet bij het spawnpunt wachten op spelers die net respawnen.',
        'Ganggevechten verlopen via het gangsysteem (territoria). Geen eigen oorlogen buiten dat systeem.',
    } },
    { title = 'Economie en bugs', items = {
        'Het misbruiken van fouten (bugs), dupliceren van geld of items en andere exploits is verboden. Meld ze direct bij het team; je wordt hiervoor niet gestraft als je ze meldt.',
        'Handel in echt geld voor spelgeld, items of voertuigen is verboden.',
        'Geld en spullen geef je alleen binnen het rollenspel aan anderen (/geefgeld, /geefitem).',
    } },
    { title = 'Politie, ambulance en bedrijven', items = {
        'Hulpdiensten spelen hun rol professioneel. Op dienst doe je niet mee aan PvP; ga eerst uit dienst.',
        'Boetes, boeien en fouilleren gebeuren alleen met een roleplayreden en volgens de procedures van de baan (zie /baan).',
        'Misbruik van je baan (rechten, bedrijfskas, voertuigen) leidt tot ontslag en kan tot een sanctie leiden.',
    } },
    { title = 'Cheats en onrechtvaardig voordeel', items = {
        'Cheats, mod menus, macro\'s, scripts en het misbruiken van spelmechanieken voor voordeel zijn verboden en leiden tot een permanente ban.',
        'Het ontwijken van een ban (met een ander account of identifier) leidt tot een permanente ban.',
    } },
    { title = 'Sancties', items = {
        'Het team kan waarschuwen, kicken, tijdelijk bannen of permanent bannen, afhankelijk van de ernst en je geschiedenis.',
        'Meerdere waarschuwingen leiden automatisch tot een tijdelijke ban.',
        'Vragen of klachten? Gebruik de ticketfunctie op Discord, met bewijs (clip of screenshot).',
    } },
}
