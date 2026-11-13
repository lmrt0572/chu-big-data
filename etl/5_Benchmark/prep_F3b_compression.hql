-- F3b Compression de Parquet : la même copie des décès (24,9 M de lignes, sans partition) écrite trois fois,
-- en Snappy (le choix du Silver et du Gold), en Gzip, puis sans compression.
-- On compare la place sur le disque (logs/fichiers_tables.txt) et le temps de B7.
-- Lancé dans Hive, car c'est Hive qui écrit le Silver et le Gold : parquet.compression y règle le codec.
CREATE DATABASE IF NOT EXISTS bench;

SET parquet.compression=SNAPPY;
DROP TABLE IF EXISTS bench.deces_snappy;
CREATE TABLE bench.deces_snappy STORED AS PARQUET AS
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces FROM gold.fait_deces;

SET parquet.compression=GZIP;
DROP TABLE IF EXISTS bench.deces_gzip;
CREATE TABLE bench.deces_gzip STORED AS PARQUET AS
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces FROM gold.fait_deces;

SET parquet.compression=UNCOMPRESSED;
DROP TABLE IF EXISTS bench.deces_non_compresse;
CREATE TABLE bench.deces_non_compresse STORED AS PARQUET AS
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces FROM gold.fait_deces;
