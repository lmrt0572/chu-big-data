-- F1 Partitionnement : copie de gold.fait_deces sans partition.
-- Mêmes lignes et mêmes colonnes que le Gold, mais annee_deces devient une colonne ordinaire,
-- si bien qu'une requête sur 2019 doit lire les 51 années.
CREATE DATABASE IF NOT EXISTS bench;

DROP TABLE IF EXISTS bench.deces_sans_partition;
CREATE TABLE bench.deces_sans_partition STORED AS PARQUET AS
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces;
