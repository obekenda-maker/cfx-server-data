-- BENADERING van de ESX Legacy-tabellen die onze SQL/resources gebruiken, uitsluitend voor tests.
-- De echte tabellen komen uit es_extended/esx_* (andere versie kan extra kolommen hebben).
CREATE TABLE owned_vehicles (
  owner VARCHAR(60) NOT NULL, plate VARCHAR(12) NOT NULL, vehicle LONGTEXT, `type` VARCHAR(20) NOT NULL DEFAULT 'car',
  job VARCHAR(20) NULL, `stored` TINYINT(1) NOT NULL DEFAULT 0, PRIMARY KEY (plate)
);
CREATE TABLE jobs (name VARCHAR(50) NOT NULL, label VARCHAR(50), whitelisted TINYINT(1) NOT NULL DEFAULT 0, PRIMARY KEY (name));
CREATE TABLE job_grades (
  id INT NOT NULL AUTO_INCREMENT, job_name VARCHAR(50), grade INT NOT NULL, name VARCHAR(50) NOT NULL,
  label VARCHAR(50) NOT NULL, salary INT NOT NULL, skin_male LONGTEXT NOT NULL, skin_female LONGTEXT NOT NULL, PRIMARY KEY (id)
);
CREATE TABLE items (name VARCHAR(50) NOT NULL, label VARCHAR(50), weight INT NOT NULL DEFAULT 1, rare TINYINT NOT NULL DEFAULT 0, can_remove TINYINT NOT NULL DEFAULT 1, PRIMARY KEY (name));
CREATE TABLE addon_account (name VARCHAR(60) NOT NULL, label VARCHAR(100), shared INT NOT NULL, PRIMARY KEY (name));
CREATE TABLE datastore (name VARCHAR(60) NOT NULL, label VARCHAR(100), shared INT NOT NULL, PRIMARY KEY (name));
CREATE TABLE addon_inventory (name VARCHAR(60) NOT NULL, label VARCHAR(100), shared INT NOT NULL, PRIMARY KEY (name));
