# Multiplayer- en integratietest (besloten test)

> **Status: NOG NIET UITGEVOERD.** Alle geautomatiseerde tests slagen (zie `docs/TESTRESULTATEN.md`), maar die draaien de servercode met
> nagebootste FiveM/ESX-API's. **Alleen deze checklist, met echte spelers op een echte server, bewijst dat de server werkt.**
> Zolang niet alle ⭐-punten zijn afgevinkt is de server **niet** vrijgegeven (zie `docs/RELEASE_CHECKLIST.md`, GO/NO-GO).

## 0. Voorbereiding

**Team (minimaal 5 mensen, 6 voor de gangoorlog):**

| Rol | Wie | Doet |
|---|---|---|
| **ADM** | beheerder | `superadmin`; volgt serverconsole + Discord-logkanalen; kan herstarten |
| **A** | nieuwe speler | speelt als nieuweling (verse license, nog nooit ingelogd) |
| **B** | burger/PvP | taxi/trucker/bezorger, PvP |
| **C** | politie | via bossmenu/`/setjob` aangenomen |
| **D** | ambulance + monteur | |
| **E, F** | gangleiders (2 gangs, elk met een extra lid = 6 spelers) | gangs, oorlog |

**Vooraf (ADM):**
- [ ] `python3 tests/run_all.py` is groen op dezelfde versie als de server; `./scripts/print-versions.sh` genoteerd (versies in het testrapport).
- [ ] Serverconsole bij start: geen rode regels (zie `docs/INSTALLATIE.md` §F).
- [ ] Backup gemaakt (`scripts/backup.sh`) en `docs/BACKUP_HERSTEL.md` §5 (herstel-oefening) is op een testdatabase gedaan.
- [ ] Discord-webhooks ingesteld; je ziet de kanalen `general`, `admin`, `money`, `combat`, `gang`, `suspicious`.
- [ ] Testers kennen `docs/TESTERS_BRIEFING.md`. Iedereen heeft FiveM-console (F8) toegang en kan clips/screenshots maken.
- [ ] Coördinaten gecontroleerd met `/coords` (zones, garages, winkels, depots, jobcentrum, territoria).

**Per test noteren:** ✅ geslaagd / ❌ mislukt / ⚠ afwijking, + bewijs (clip, F8-/serverlog-regel, Discord-log).

---

## Sessie 1 – Aanmelden, regels, onboarding (A + ADM)

| ID | Test | Stappen | Verwacht | |
|---|---|---|---|---|
| 1.1 ⭐ | Loadscreen | Verbind als A | Nederlandse loadscreen met servernaam en voortgangsbalk | [ ] |
| 1.2 ⭐ | Personage aanmaken | `esx_identity` voltooien | Personage bestaat; **geen** twee NUI's door elkaar | [ ] |
| 1.3 ⭐ | Akkoord-pagina | Wacht na het aanmaken | Regels verschijnen; "Akkoord" pas actief na vinkje; geen tabs, geen sluitknop; Escape doet niets | [ ] |
| 1.4 ⭐ | Niet akkoord | Kies "Niet akkoord" (tweede account/license) | Speler wordt van de server gezet met Nederlandse melding; Discord `general` toont het | [ ] |
| 1.5 ⭐ | Timeout | Laat de akkoord-pagina open staan tot de timeout (`acceptTimeoutSeconds`) | Server zet de speler eruit (ook als je de NUI sluit) | [ ] |
| 1.6 | Noodoplossing | Ander account: typ `/akkoord` i.p.v. knop | Akkoord geregistreerd, pagina sluit | [ ] |
| 1.7 ⭐ | Onboarding | Na akkoord | 8 stappen; Volgende/Vorige; waypoint-knoppen zetten route (Jobcentrum, dealer); "Aan de slag" sluit; komt **niet** terug na herverbinden | [ ] |
| 1.8 | `/regels`, `/welkom`, `/help`, `/baan` | Typ ze | Elk opent met Nederlandse tekst; `/regels` heeft Sluiten (geen akkoord) | [ ] |
| 1.9 | Regelversie | ADM: `WelcomeCfg.Rules.version` +1, `restart server_welcome`, A herverbindt | A moet opnieuw akkoord geven | [ ] |
| 1.10 | HUD | Bekijk beeld | HUD zichtbaar, geen dubbele GTA-HUD; geld/job/honger/dorst kloppen; pauzemenu verbergt HUD | [ ] |
| 1.11 | Persistentie | A verlaat en herverbindt | Personage, geld, positie, akkoord, onboarding bewaard | [ ] |

## Sessie 2 – Banen (A, B, C, D, ADM)

| ID | Test | Verwacht | |
|---|---|---|---|
| 2.1 ⭐ | Jobcentrum: A meldt zich aan als taxi, dan bezorger | Job wijzigt, `/baan` toont uitleg; tweede wissel binnen de wachttijd wordt geweigerd | [ ] |
| 2.2 | Politie/ambulance niet kiesbaar in Jobcentrum; C kan niet via Jobcentrum stoppen | Geweigerd met melding | [ ] |
| 2.3 ⭐ | ADM neemt C aan: bossmenu of `/setjob <id> police 0` | C heeft job; Discord/ESX bevestigt | [ ] |
| 2.4 ⭐ | Dienst in/uit politie | **E** bij dienstpunt: job wisselt `police`↔`offpolice`; te ver weg = geweigerd | [ ] |
| 2.5 ⭐ | Politie-acties op B | `/politie`: boeien (B kan niet lopen/schieten), fouilleren (alleen bij geboeid), begeleiden, boete (geld → B af, politiekas erbij), ontboeien | [ ] |
| 2.6 ⭐ | Dood buiten PvP | B laat zich neerschieten door een NPC/val: tekst met timers, hulp melden (E) | D (ambulance, op dienst) krijgt melding + blip | [ ] |
| 2.7 ⭐ | Reanimeren | D loopt naar B, **E** (voortgangsbalk) | B staat op met ongeveer 40% health (`reviveHealth`), betaalt behandelkosten; zonder medic: ziekenhuis-respawn (G) na wachttijd, kosten ≤ bezit | [ ] |
| 2.8 | Monteur | D: dienst, `/repareer` bij kapot voertuig | Reparatiekit verbruikt; zonder kit foutmelding | [ ] |
| 2.9 ⭐ | Taxi | B taxi-chauffeur, A passagier: `/taxi` start, rijden, stoppen | A krijgt bevestigingsvraag; bij Betalen: geld A↓, B↑ (80%), taxikas (20%); bij Weigeren niets | [ ] |
| 2.10 ⭐ | Trucker/bezorger | Opdracht, voertuig verschijnt, rijden, **E** lossen | Betaling = routebedrag; daglimiet wordt gehaald en daarna geweigerd | [ ] |
| 2.11 | Salaris | Wacht één `PaycheckInterval` | Op dienst: salaris; af dienst: €0; bedrag klopt met `docs/ECONOMIE.md` | [ ] |
| 2.12 | Boss-grade | Hoogste rang opent bossmenu bij de locatie | Menu opent; lagere rang kan dat niet | [ ] |

## Sessie 3 – Economie, voertuigen, winkels (A, B, ADM)

| ID | Test | Verwacht | |
|---|---|---|---|
| 3.1 ⭐ | Voertuig kopen (PDM) | Prijs afgeschreven; voertuig staat in Garage Legion; kenteken `AB 123 C`-vorm | [ ] |
| 3.2 ⭐ | Uitparkeren/opslaan | Voertuig verschijnt met juiste kleur/schade; opslaan verwijdert het; tweede keer uitparkeren zonder opslaan **kan niet** | [ ] |
| 3.3 | Depot | Voertuig buiten laten staan, server herstart (of verwijderen); depot toont het, kosten €500 | [ ] |
| 3.4 | Winkel | Eten/EHBO kopen; gebruiken; honger/dorst/health reageren; inventaris vol = melding | [ ] |
| 3.5 ⭐ | Wapens | Ammu-Nation: zonder licentie geweigerd; licentie kopen; wapen kopen; tweede keer = "al bezit" | [ ] |
| 3.6 | `/geefgeld`, `/geefitem` | Werkt dichtbij; te ver/negatief/te veel geweigerd; niet tijdens PvP | [ ] |
| 3.7 ⭐ | Geld klopt | Houd een logboek van geldwijzigingen; vergelijk met Discord `money` | Elke wijziging heeft een logregel | [ ] |

## Sessie 4 – PvP en combat zones (A, B, C, D + ADM; zones: FFA en team)

| ID | Test | Verwacht | |
|---|---|---|---|
| 4.1 ⭐ | Zone herkennen | Naar een zone lopen/rijden | Blip + grensmarkering; banner "PvP-zone" bij binnenkomst, "Je verlaat…" bij vertrek | [ ] |
| 4.2 ⭐ | Weigeren | A weigert de prompt | A onkwetsbaar, kan niet schieten, na `bystanderEjectSeconds` buiten de zone; B (deelnemer) kan A **niet** raken (test met geweer en voertuig) | [ ] |
| 4.3 ⭐ | Deelnemen | B kiest loadout | Tijdelijke wapens; RP-wapens weg uit hand; HUD toont combatpaneel + munitie; spawn binnen de zone | [ ] |
| 4.4 ⭐ | Spawnbeveiliging | Direct na join/respawn | ~4 s beschermd (doorzichtig); vervalt automatisch; vervalt bij schieten | [ ] |
| 4.5 ⭐ | Kill | B doodt D (beide deelnemers) | Killfeed Nederlands, **één** melding; +geld/XP-melding; stats +1; D respawnt na ≥5 s op ander punt | [ ] |
| 4.6 ⭐ | Geen dubbele kills | Snel achter elkaar doden/respawnen | Geen dubbele killfeed-regels; K/D klopt | [ ] |
| 4.7 ⭐ | Anti-farm | B doodt steeds dezelfde D binnen 2 min | Melding "zonder beloning"; stats/geld niet verhoogd | [ ] |
| 4.8 ⭐ | Dagcap | Blijf kills scoren tot de dagcap | Geld stopt (melding), XP gaat door | [ ] |
| 4.9 ⭐ | Teamzone | 4 spelers: teams verdeeld, teamgenoten kunnen elkaar niet raken, score, ronde-einde met bonus | [ ] |
| 4.10 ⭐ | Verlaten | `/pvpverlaat` (niet vlak na schade); ook lopend de zone uit | Combatwapens weg, **RP-wapens + munitie terug**, honger/dorst/health terug op oude waarde | [ ] |
| 4.11 ⭐ | Dood/disconnect in zone | Sterf in zone; disconnect in zone; herverbind | Geen combatwapens in RP-loadout; inventaris/geld ongewijzigd; stats intact; geen vastzittend doodscherm | [ ] |
| 4.12 ⭐ | Politie op dienst | C probeert mee te doen | Geweigerd met melding; af dienst wel; job wisselen tijdens PvP = direct eruit | [ ] |
| 4.13 ⭐ | Items in zone | Eten/EHBO gebruiken in zone | Geblokkeerd | [ ] |
| 4.14 ⭐ | Beschermde RP-gebieden | Probeer deel te nemen/vechten bij PD, ziekenhuis, garage, winkel | Niet mogelijk (melding "beschermd roleplaygebied") | [ ] |
| 4.15 | Voertuigen in zone | Instappen | Geblokkeerd; uitstappen verplicht | [ ] |
| 4.16 | Leaderboard | `F7` vasthouden, `/top kd`, `/top xp` | Juiste volgorde en eigen stats | [ ] |
| 4.17 | Buiten zones | A schiet B buiten zones | Normaal GTA (mode `rp`) en **geen** combatbeloning; dood → logregel "Mogelijke RDM" in Discord | [ ] |
| 4.18 | Respawn-spam | Snel herhaald sterven | Limiet (max/min) bereikt, geen vastlopen | [ ] |

## Sessie 5 – Gangs en gangoorlog (E, F + 2 leden, C als toeschouwer/agent, ADM)

| ID | Test | Verwacht | |
|---|---|---|---|
| 5.1 ⭐ | Gang oprichten | E: `/gang`, naam/kleur; kosten uit bank | Gang bestaat; E is leider; dubbele naam geweigerd | [ ] |
| 5.2 | Leden | Uitnodigen (nabij), accepteren, rang wijzigen, kicken | Rechten per rang kloppen; niet hoger dan jezelf | [ ] |
| 5.3 | Kas | Storten/opnemen met en zonder recht | Limieten + Discord `money` | [ ] |
| 5.4 ⭐ | Territorium claimen | Twee leden online, in het gebied | Eigenaar + kleur op kaart; kosten uit kas | [ ] |
| 5.5 ⭐ | Oorlog verklaren | F (2 online) daagt E (2 online) uit | Voorbereidingstijd; daarna **tijdelijke zone**; alleen leden van beide gangs krijgen een blip en kunnen meedoen; C/A kunnen er niet in (geweigerd) | [ ] |
| 5.6 ⭐ | Oorlog verloopt | Doe mee, kills tellen, stand-meldingen | Geen geld/XP/stats; spawn-kills tellen niet; einde → eigenaar wisselt (of blijft); zone verdwijnt; gebied vergrendeld | [ ] |
| 5.7 ⭐ | RP-gebied veilig | Winkel/garage in de buurt van het gebied | Spelers daar ongehinderd; combat start nergens in een beschermd gebied | [ ] |
| 5.8 | Zwarte markt | Lid met recht; zonder gebied geen wapens; daglimiet; niet-lid geweigerd | [ ] |
| 5.9 | Schroot + hehler | Activiteit (te snel klaar = geweigerd), cooldown, hehler daglimiet | [ ] |
| 5.10 | Server herstart tijdens oorlog | Zone weg, kosten verloren, eigendom ongewijzigd (bekend; zie `RESTERENDE_PUNTEN`) | [ ] |

## Sessie 6 – Beheer en beveiliging (ADM + A als "slechterik")

| ID | Test | Verwacht | |
|---|---|---|---|
| 6.1 ⭐ | Rechten | Als `user`/`mod`/`admin`: probeer `/ban`, `/announce`, `/admin` | Overeenkomstig `docs/ADMIN_RECHTEN.md` | [ ] |
| 6.2 ⭐ | Kick/warn/ban | `/warn` ×3 → auto-ban; `/ban 1h`; geband account verbindt | Verbinding geweigerd (ook met ander Discord-id van dezelfde license/identifier); `/unban` herstelt | [ ] |
| 6.3 | Spelercontrole | `/checkplayer`, `/warnings` | Correcte info, gelogd in `admin` | [ ] |
| 6.4 | Admin-menu | `/admin` → acties | Alleen toegestane acties werken | [ ] |
| 6.5 ⭐ | Exploit-pogingen (A) | Zie §Exploits hieronder | Geen misbruik mogelijk | [ ] |
| 6.6 | Discord-logging | Voer acties uit | Juiste kanalen; geen geheimen/wachtwoorden in logs | [ ] |

**Exploits (A probeert, ADM kijkt):** negatieve/enorme bedragen bij `/geefgeld` en winkels • zelfde voertuig tegelijk uit twee garages halen • wapen uit PvP mee naar RP nemen (zone verlaten, crashen, disconnecten) • PvP-beloning boosten met een vriend • kills claimen zonder schade • bezorgopdracht afronden zonder te rijden • job-hoppen voor salaris • de akkoord-pagina omzeilen • in een beschermd gebied PvP starten • spamklikken op menu's.

## Sessie 7 – Herstart, persistentie en back-up (ADM)

| ID | Test | Verwacht | |
|---|---|---|---|
| 7.1 ⭐ | Nette herstart | Spelers online met geld/voertuig/gang; ADM `quit`/herstart; iedereen verbindt opnieuw | Geld, job, positie, voertuigen, stats, gang/kas/territorium, bans, akkoord, daglimieten allemaal bewaard | [ ] |
| 7.2 | Crash-simulatie | Proces killen tijdens PvP | Na herstart niemand vast in PvP; RP-wapens/geld intact (stats ≤30 s verlies) | [ ] |
| 7.3 ⭐ | Back-up + herstel | `backup.sh`, wijzig data, `restore.sh` op testdatabase/ofﬂine server | Data identiek aan moment van back-up | [ ] |
| 7.4 | Resource-herstart | `restart combat_core`, `restart rp_gangs`, `restart server_hud` tijdens spel | Geen errors; spelers niet vast; HUD/zones komen terug | [ ] |

## Sessie 8 – Belasting en prestaties (iedereen, 30+ min)

| ID | Test | Verwacht | |
|---|---|---|---|
| 8.1 ⭐ | `resmon` (F8) | Idle < 0,05 ms per resource; HUD < 0,10 ms; geen resource blijft > 1 ms | [ ] |
| 8.2 | Gelijktijdig | Zoveel spelers als mogelijk in één zone + menu's openen | Geen server-hitches; geen scripterrors in serverconsole | [ ] |
| 8.3 | Serverconsole + F8 | Volg 30 min | Geen herhaalde rode regels | [ ] |

---

## Bugrapport (sjabloon)

```
ID: 4.5           Datum/tijd:          Rol/speler:
Wat deed je:
Wat verwachtte je:
Wat gebeurde er:
Server-/F8-console (kopieer de rode regels):
Bewijs (clip/screenshot/Discord-log):
Reproduceerbaar? altijd / soms / eenmalig
```

## Vrijgavecriteria voor de besloten test (GO/NO-GO)

**GO** alleen als: alle ⭐-tests ✅; geen ❌ in sessie 4.10–4.14, 6.5 en 7.1 (verlies van spullen/geld, misbruik, dataverlies); serverconsole zonder
herhaalde errors; back-up én herstel zijn bewezen (7.3). Andere ❌/⚠ worden opgelost of bewust geaccepteerd en genoteerd.
