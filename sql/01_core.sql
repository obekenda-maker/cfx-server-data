-- =====================================================================
-- 01_core.sql – eigen tabellen van de combat/roleplay server
-- Veilig opnieuw uit te voeren (CREATE TABLE IF NOT EXISTS).
-- Vereist MySQL 5.7+/8 of MariaDB 10.3+.
-- ESX-tabellen (users, owned_vehicles, jobs, ...) komen uit ESX zelf.
-- =====================================================================

-- ---- Logging --------------------------------------------------------
CREATE TABLE IF NOT EXISTS `server_log_entries` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `channel`    VARCHAR(32)  NOT NULL,
  `title`      VARCHAR(120) NOT NULL,
  `message`    TEXT         NOT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_channel_time` (`channel`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---- Regels-akkoord en onboarding (server_welcome) ------------------
-- Per Rockstar-license (niet per personage): welke regelversie is geaccepteerd en is de onboarding doorlopen.
CREATE TABLE IF NOT EXISTS `server_rules_accepted` (
  `license`     VARCHAR(64)  NOT NULL,
  `version`     INT UNSIGNED NOT NULL DEFAULT 0,
  `name`        VARCHAR(64)  NOT NULL DEFAULT '',
  `accepted_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `onboarded`   TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---- Admin: bans & waarschuwingen -----------------------------------
CREATE TABLE IF NOT EXISTS `admin_bans` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `license`    VARCHAR(64)  NULL,
  `discord`    VARCHAR(64)  NULL,
  `fivem`      VARCHAR(64)  NULL,
  `steam`      VARCHAR(64)  NULL,
  `name`       VARCHAR(64)  NOT NULL DEFAULT '',
  `reason`     VARCHAR(255) NOT NULL,
  `banned_by`  VARCHAR(64)  NOT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` TIMESTAMP    NULL DEFAULT NULL,
  `active`     TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_license` (`license`),
  KEY `idx_discord` (`discord`),
  KEY `idx_fivem` (`fivem`),
  KEY `idx_steam` (`steam`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `admin_warnings` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `license`    VARCHAR(64)  NOT NULL,
  `name`       VARCHAR(64)  NOT NULL DEFAULT '',
  `reason`     VARCHAR(255) NOT NULL,
  `warned_by`  VARCHAR(64)  NOT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---- Combat ---------------------------------------------------------
-- Eén rij per ESX-identifier (xPlayer.identifier, dus ook met char-prefix).
CREATE TABLE IF NOT EXISTS `combat_stats` (
  `identifier`   VARCHAR(60)  NOT NULL,
  `name`         VARCHAR(64)  NOT NULL DEFAULT '',
  `kills`        INT UNSIGNED NOT NULL DEFAULT 0,
  `deaths`       INT UNSIGNED NOT NULL DEFAULT 0,
  `best_streak`  INT UNSIGNED NOT NULL DEFAULT 0,
  `xp`           INT UNSIGNED NOT NULL DEFAULT 0,
  `earned_today` INT UNSIGNED NOT NULL DEFAULT 0,
  `earned_date`  VARCHAR(10)  NULL,
  `updated_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`),
  KEY `idx_kills` (`kills`),
  KEY `idx_xp` (`xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Audit van beloonde kills (wordt periodiek opgeschoond door combat_core)
CREATE TABLE IF NOT EXISTS `combat_kill_log` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `killer`     VARCHAR(60)  NOT NULL,
  `victim`     VARCHAR(60)  NOT NULL,
  `zone`       VARCHAR(48)  NOT NULL,
  `weapon`     VARCHAR(48)  NOT NULL DEFAULT '',
  `money`      INT UNSIGNED NOT NULL DEFAULT 0,
  `xp`         INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_killer` (`killer`),
  KEY `idx_time` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---- Gangs ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rp_gangs` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(32)  NOT NULL,
  `label`      VARCHAR(48)  NOT NULL,
  `color`      VARCHAR(9)   NOT NULL DEFAULT '#ff0000',
  `bank`       INT UNSIGNED NOT NULL DEFAULT 0,
  `created_by` VARCHAR(60)  NOT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rp_gang_members` (
  `identifier` VARCHAR(60)  NOT NULL,
  `gang_id`    INT UNSIGNED NOT NULL,
  `grade`      TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `name`       VARCHAR(64)  NOT NULL DEFAULT '',
  `joined_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`),
  KEY `idx_gang` (`gang_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rp_gang_territories` (
  `territory`      VARCHAR(48)  NOT NULL,
  `gang_id`        INT UNSIGNED NULL,
  `claimed_at`     TIMESTAMP    NULL DEFAULT NULL,
  `locked_until`   TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`territory`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Cooldowns/dagelijkse limieten voor illegale activiteiten (per speler)
CREATE TABLE IF NOT EXISTS `rp_cooldowns` (
  `identifier` VARCHAR(60)  NOT NULL,
  `action`     VARCHAR(48)  NOT NULL,
  `day`        VARCHAR(10)  NOT NULL,
  `count`      INT UNSIGNED NOT NULL DEFAULT 0,
  `amount`     INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`identifier`, `action`, `day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---- Jobs: kolom 'whitelisted' ---------------------------------------
-- ESX 1.13.x heeft in `jobs` alleen name + label. rp_jobs (catalogus/jobcentrum) gebruikt deze kolom;
-- ESX zelf negeert hem. Veilig opnieuw uit te voeren (MariaDB: IF NOT EXISTS).
ALTER TABLE `jobs` ADD COLUMN IF NOT EXISTS `whitelisted` TINYINT(1) NOT NULL DEFAULT 0;

-- ---- Voertuigen: tabel owned_vehicles ------------------------------
-- In ESX 1.13.x staat deze tabel alleen nog in [SQL]/legacy.sql (niet in es_extended.sql); daarom hier aangemaakt.
CREATE TABLE IF NOT EXISTS `owned_vehicles` (
  `owner`   VARCHAR(60) DEFAULT NULL,
  `plate`   VARCHAR(12) NOT NULL,
  `vehicle` LONGTEXT DEFAULT NULL,
  `type`    VARCHAR(20) NOT NULL DEFAULT 'car',
  `job`     VARCHAR(20) DEFAULT NULL,
  `stored`  TINYINT(1) NOT NULL DEFAULT 0,
  `parking` VARCHAR(60) DEFAULT NULL,
  `pound`   VARCHAR(60) DEFAULT NULL,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---- Voertuigen: kolom 'stored' ------------------------------------
-- owned_vehicles komt uit es_extended (legacy.sql). In recente ESX-versies bestaat
-- `stored` al. Op MariaDB kun je dit veilig draaien; op MySQL geeft het een
-- foutmelding als de kolom/index al bestaat (negeer die dan).
ALTER TABLE `owned_vehicles` ADD COLUMN IF NOT EXISTS `stored` TINYINT(1) NOT NULL DEFAULT 0;

-- Index op eigenaar: garage-/depotlijsten filteren op owner (anders een volledige tabelscan per menu-opening)
ALTER TABLE `owned_vehicles` ADD INDEX IF NOT EXISTS `idx_owner` (`owner`);
