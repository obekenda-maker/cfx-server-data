# Adminrechten – matrix (gegenereerd en getest)

*Gegenereerd door `python3 tests/test_admin_matrix.py`: elke actie is **echt uitgevoerd** in de serverlogica als elke rol en de uitkomst is vergeleken met `ServerCfg.Admin`.*

✅ = actie uitgevoerd • ⛔ = geweigerd (geen effect) • – = niet van toepassing

| Actie | Vereist | user | mod | admin | superadmin | console |
|---|---|---|---|---|---|---|
| `kick` | niveau ≥ 1 | ⛔ | ✅ | ✅ | ✅ | ✅ |
| `ban` | niveau ≥ 2 | ⛔ | ⛔ | ✅ | ✅ | ✅ |
| `ban (permanent)` | niveau ≥ 3 | ⛔ | ⛔ | ⛔ | ✅ | ✅ |
| `unban` | niveau ≥ 2 | ⛔ | ⛔ | ✅ | ✅ | ✅ |
| `warn` | niveau ≥ 1 | ⛔ | ✅ | ✅ | ✅ | ✅ |
| `warnings` | niveau ≥ 1 | ⛔ | ✅ | ✅ | ✅ | ✅ |
| `checkplayer` | niveau ≥ 1 | ⛔ | ✅ | ✅ | ✅ | ✅ |
| `arevive` | niveau ≥ 1 | ⛔ | ✅ | ✅ | ✅ | ✅ |
| `goto` | niveau ≥ 1 | ⛔ | ✅ | ✅ | ✅ | – |
| `bring` | niveau ≥ 2 | ⛔ | ⛔ | ✅ | ✅ | – |
| `pvpkick` | niveau ≥ 1 | ⛔ | ✅ | ✅ | ✅ | ✅ |
| `announce` | niveau ≥ 2 | ⛔ | ⛔ | ✅ | ✅ | ✅ |
| `menu: spelerslijst` | niveau ≥ 1 | ⛔ | ✅ | ✅ | ✅ | – |
| `menu: kick` | niveau ≥ 1 | ⛔ | ✅ | ✅ | ✅ | – |
| `menu: ban` | niveau ≥ 2 | ⛔ | ⛔ | ✅ | ✅ | – |
| `menu: teleport` | niveau ≥ 2 | ⛔ | ⛔ | ✅ | ✅ | – |
| `/coords (rechtencheck)` | niveau ≥ 1 | ⛔ | ✅ | ✅ | ✅ | – |
| `jobsync (console)` | alleen superadmin/console | ⛔ | ⛔ | ⛔ | ✅ | ✅ |
| `regelsreset` | alleen superadmin/console | ⛔ | ⛔ | ⛔ | ✅ | ✅ |

## Hoe rechten worden bepaald

* Rechten volgen de **ESX-groep** van de speler (`users.group`): `user`=0, `mod`=1, `admin`=2, `superadmin`=3, serverconsole=99.
* Eerste beheerder maak je in de **serverconsole**: `setgroup <id> superadmin`. Rechten per actie staan in `ServerCfg.Admin.levels`.
* Permanente bans: niveau ≥ 3 (`permBanLevel`). Tijdelijke bans maximaal 8760 uur. Automatische ban na 3 waarschuwingen (24 uur).
* **Elke** actie controleert de rechten opnieuw op de server; het adminmenu in het spel is alleen een scherm. Menu-callbacks (`admin_tools:*`) controleren per actie het vereiste niveau.
* Elke uitgevoerde beheeractie wordt gelogd in het Discord-kanaal `admin` en in de tabel `server_log_entries`.

## Let op: ESX-eigen commando's

Naast deze tools heeft ESX zelf commando's (`/setjob`, `/setgroup`, `/giveaccountmoney`, `/car`, `/giveweapon`, …). Die zijn **niet** door onze code beperkt:
ze volgen de ESX-instellingen van jouw versie (meestal groep `admin` en `superadmin`). Geef de groep `admin` dus alleen aan vertrouwde beheerders; `mod` krijgt via deze server alleen kick/warn/check/revive/teleport-naar.
Controleer in jouw ESX-versie welke groepen toegang hebben tot geld- en item-commando's (zoek in `es_extended` naar `ESX.RegisterCommand`).
