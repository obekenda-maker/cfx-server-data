# Jobsysteem – instructies voor beheerders

Alle jobs, jobgrades en salarissen staan op **één plek**: `JobsCfg.Catalog` in
`resources/[roleplay]/rp_jobs/config.lua`. De SQL en de in-game uitleg (`/baan`) volgen daaruit.

## 1. Overzicht

| Job | Wie mag erin? | Dienst | Hoofdfuncties | PvP |
|---|---|---|---|---|
| **Burger** (`unemployed`, ESX-standaard) | iedereen | – | Jobcentrum, winkels, voertuigen, `/pvp` | vrijwillig |
| **Politie** (`police`/`offpolice`) | alleen op sollicitatie (bossmenu of beheerder) | ja, dienstpunt politiebureau | `/politie`: boeien, fouilleren, begeleiden, boete | op dienst **niet**; af dienst wel |
| **Ambulance** (`ambulance`/`offambulance`) | alleen op sollicitatie | ja, dienstpunt ziekenhuis | hulpmeldingen, reanimeren (E), behandelkosten | op dienst **niet**; af dienst wel |
| **Monteur** (`mechanic`/`offmechanic`) | iedereen via Jobcentrum (start als leerling) | ja, dienstpunt garage | `/repareer` (reparatiekit nodig) | af dienst/burger: vrijwillig |
| **Taxi** (`taxi`) | iedereen via Jobcentrum | nee | `/taxi` taximeter; passagier bevestigt tarief | vrijwillig |
| **Vrachtwagenchauffeur** (`trucker`) | iedereen via Jobcentrum | nee | opdrachten vanaf het haven-depot | vrijwillig |
| **Bezorger** (`courier`) | iedereen via Jobcentrum | nee | opdrachten vanaf het bezorgdepot | vrijwillig |

* **Dienst:** wie "op dienst" is heeft job `police`; "af dienst" is `offpolice` (salaris €0). De dienstpunten staan in `JobsCfg.Duty`.
  Het salaris loopt dus alleen op dienst. Op dienst kunnen politie en ambulance **niet** aan PvP deelnemen (`CombatCfg.JobRules`).
* **Jobcentrum:** `JobsCfg.JobCenter`. Alleen `public`-jobs (grade 0). Er zit een tijd tussen baanwissels
  (`minSecondsBetween`) en een daglimiet (`maxChangesPerDay`) tegen job-hoppen. Politie/ambulance kunnen niet via het Jobcentrum stoppen.
* **Uitleg:** spelers typen **/baan** voor uitleg bij hun huidige baan. De teksten staan in `server_config/locale_nl.lua` (`jobs.info_*`).

## 2. Een speler aannemen of bevorderen

| Situatie | Hoe |
|---|---|
| Burgerbaan (taxi/trucker/courier/monteur) | speler gaat zelf naar het **Jobcentrum** |
| Politie/ambulance aannemen | de baas (hoogste grade) via het **bossmenu** (`esx_society`), of een beheerder met het ESX-commando `/setjob <id> police 0` (ESX-groep `admin`/`superadmin`) |
| Bevorderen/ontslaan | bossmenu (leden beheren) of `/setjob <id> <job> <grade>` |
| Eigen bedrijfskas bekijken | bossmenu → bedrijfskas (bedrijfsrekeningen: `sql/03_societies.sql`) |

De **baas-grade** moet `boss` heten (vereist door `esx_society`); de catalogus-lint (`tests/check_jobs.py`) bewaakt dat.

## 3. Jobs of salarissen aanpassen

1. Pas `JobsCfg.Catalog` aan (labels, grades, salaris per uitbetaling, `public`, `whitelisted`, `offDuty`).
2. Werk de SQL bij en importeer: `python3 scripts/gen_jobs_sql.py` → `sql/02_jobs_items.sql` opnieuw importeren;
   **of** typ in de **serverconsole** `jobsync` (alleen console/ESX-groep `superadmin`; schrijft *alleen* de jobs uit de catalogus
   naar de database en laat andere jobs ongemoeid).
3. **Herstart de server** (ESX leest jobs alleen bij het opstarten).
4. Bij elke start waarschuwt `rp_jobs` in de console als de database afwijkt van de catalogus. Er wordt nooit automatisch iets overschreven.

> **Salaris-timing:** ESX betaalt elke `Config.PaycheckInterval`. Het economie-rapport (`docs/ECONOMIE.md`) gaat uit van **30 minuten**.
> Zet in `es_extended` `Config.PaycheckInterval = 30 * 60000`, anders zijn de uurbedragen hoger dan het rapport laat zien.

## 4. Een nieuwe job toevoegen

1. Voeg een blok toe aan `JobsCfg.Catalog` (en een `jobs.info_<naam>` + `jobs.info_<naam>_short` tekst in `locale_nl.lua`).
2. Wil je een dienstpunt: voeg het toe aan `JobsCfg.Duty` (en zet `offDuty = true`). Bossmenu: `JobsCfg.Boss`. Bedrijfskas: `JobsCfg.Societies` + `sql/03_societies.sql`.
3. Moet de job niet aan PvP meedoen als hij op dienst is? Voeg hem toe aan `CombatCfg.JobRules` (`canJoin = false`).
4. `python3 scripts/gen_jobs_sql.py`, SQL importeren / `jobsync`, herstart, daarna `python3 tests/check_jobs.py`.

## 5. Regels per functie (aanbevolen voor het rollenspel)

* **Politie:** geen RDM; boetes alleen met reden; fouilleren alleen bij boeien; niet op dienst deelnemen aan PvP.
* **Ambulance:** altijd eerst reanimeren voordat je iemand naar het ziekenhuis "dumpt"; niet reanimeren in PvP-zones.
* **Monteur:** reparaties kosten een kit; reken in rollenspel af met `/geefgeld`.
* **Taxi:** tarief wordt door de passagier bevestigd; geen "rondjes rijden" voor tarief.
* **Vracht/bezorging:** alleen het bedrijfsvoertuig; daglimiet geldt; teleporten/boosten wordt gelogd (`suspicious`).
