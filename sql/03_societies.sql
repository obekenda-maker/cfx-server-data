-- =====================================================================
-- 03_societies.sql – bedrijfsrekeningen voor esx_society
-- Vereist de tabellen van esx_addonaccount, esx_datastore en esx_addoninventory.
-- (Los bestand: als een van die resources niet is geïnstalleerd mislukt alleen dit bestand.)
-- =====================================================================

INSERT IGNORE INTO `addon_account` (`name`, `label`, `shared`) VALUES
  ('society_police',    'Politie',   1),
  ('society_ambulance', 'Ambulance', 1),
  ('society_mechanic',  'Monteurs',  1),
  ('society_taxi',      'Taxi',      1);

INSERT IGNORE INTO `datastore` (`name`, `label`, `shared`) VALUES
  ('society_police',    'Politie',   1),
  ('society_ambulance', 'Ambulance', 1),
  ('society_mechanic',  'Monteurs',  1),
  ('society_taxi',      'Taxi',      1);

INSERT IGNORE INTO `addon_inventory` (`name`, `label`, `shared`) VALUES
  ('society_police',    'Politie',   1),
  ('society_ambulance', 'Ambulance', 1),
  ('society_mechanic',  'Monteurs',  1),
  ('society_taxi',      'Taxi',      1);
