-- =====================================================================
-- 02_jobs_items.sql – jobs, jobgrades (salarissen) en items voor deze server
-- Vereist de ESX-tabellen `jobs`, `job_grades` en `items` (es_extended).
-- Veilig opnieuw uit te voeren: jobs worden bijgewerkt, grades van onze jobs worden vervangen.
--
-- SALARISSEN: pas de kolom `salary` hieronder aan. ESX betaalt dit uit volgens
-- Config.PaycheckInterval in es_extended. Zet in esx_society `Config.EnableSocietyPayouts = true`
-- als je wilt dat salarissen uit de bedrijfskas komen (realistischer economie).
-- Naamconventie: 'off' + jobnaam = af dienst (salaris 0). De top-grade heet 'boss' (esx_society).
-- =====================================================================

INSERT INTO `jobs` (`name`, `label`, `whitelisted`) VALUES
  ('police',      'Politie',                 1),
  ('offpolice',   'Politie (af dienst)',     1),
  ('ambulance',   'Ambulance',               1),
  ('offambulance','Ambulance (af dienst)',   1),
  ('mechanic',    'Monteur',                 0),
  ('offmechanic', 'Monteur (af dienst)',     0),
  ('taxi',        'Taxichauffeur',           0),
  ('trucker',     'Vrachtwagenchauffeur',    0),
  ('courier',     'Bezorger',                0)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

DELETE FROM `job_grades` WHERE `job_name` IN
  ('police','offpolice','ambulance','offambulance','mechanic','offmechanic','taxi','trucker','courier');

INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
  ('police', 0, 'cadet',      'Cadet',        350,  '{}', '{}'),
  ('police', 1, 'agent',      'Agent',        500,  '{}', '{}'),
  ('police', 2, 'brigadier',  'Brigadier',    650,  '{}', '{}'),
  ('police', 3, 'inspecteur', 'Inspecteur',   800,  '{}', '{}'),
  ('police', 4, 'boss',       'Commissaris',  1000, '{}', '{}'),

  ('offpolice', 0, 'cadet',      'Cadet',       0, '{}', '{}'),
  ('offpolice', 1, 'agent',      'Agent',       0, '{}', '{}'),
  ('offpolice', 2, 'brigadier',  'Brigadier',   0, '{}', '{}'),
  ('offpolice', 3, 'inspecteur', 'Inspecteur',  0, '{}', '{}'),
  ('offpolice', 4, 'boss',       'Commissaris', 0, '{}', '{}'),

  ('ambulance', 0, 'ambulancier', 'Ambulancier', 400, '{}', '{}'),
  ('ambulance', 1, 'verpleger',   'Verpleger',   550, '{}', '{}'),
  ('ambulance', 2, 'arts',        'Arts',        750, '{}', '{}'),
  ('ambulance', 3, 'boss',        'Chef',        950, '{}', '{}'),

  ('offambulance', 0, 'ambulancier', 'Ambulancier', 0, '{}', '{}'),
  ('offambulance', 1, 'verpleger',   'Verpleger',   0, '{}', '{}'),
  ('offambulance', 2, 'arts',        'Arts',        0, '{}', '{}'),
  ('offambulance', 3, 'boss',        'Chef',        0, '{}', '{}'),

  ('mechanic', 0, 'leerling', 'Leerling',  250, '{}', '{}'),
  ('mechanic', 1, 'monteur',  'Monteur',   400, '{}', '{}'),
  ('mechanic', 2, 'boss',     'Eigenaar',  650, '{}', '{}'),

  ('offmechanic', 0, 'leerling', 'Leerling', 0, '{}', '{}'),
  ('offmechanic', 1, 'monteur',  'Monteur',  0, '{}', '{}'),
  ('offmechanic', 2, 'boss',     'Eigenaar', 0, '{}', '{}'),

  ('taxi',    0, 'chauffeur', 'Chauffeur', 200, '{}', '{}'),
  ('taxi',    1, 'boss',      'Manager',   400, '{}', '{}'),
  ('trucker', 0, 'chauffeur', 'Chauffeur', 150, '{}', '{}'),
  ('courier', 0, 'bezorger',  'Bezorger',  100, '{}', '{}');

-- ---- Items -----------------------------------------------------------
-- bread en water komen uit es_extended/esx_basicneeds en staan hier bewust niet in.
INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
  ('burger',      'Burger',          1, 0, 1),
  ('cola',        'Cola',            1, 0, 1),
  ('energydrink', 'Energiedrank',    1, 0, 1),
  ('bandage',     'Verband',         1, 0, 1),
  ('medkit',      'EHBO-kit',        2, 0, 1),
  ('repairkit',   'Reparatiekit',    3, 0, 1),
  ('lockpick',    'Lockpick',        1, 0, 1),
  ('schroot',     'Schroot',         2, 0, 1);
