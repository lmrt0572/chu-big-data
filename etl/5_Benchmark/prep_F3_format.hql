-- F3 Format : deux copies du fichier des décès du Bronze, l'une en texte, l'autre en Parquet.
-- Mêmes lignes et mêmes 5 colonnes, seul le format change.
-- La copie en texte est séparée par des tabulations, car Impala ne sait pas lire les tables du Bronze.
CREATE DATABASE IF NOT EXISTS bench;

DROP TABLE IF EXISTS bench.deces_texte;
CREATE TABLE bench.deces_texte
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE AS
SELECT sexe, date_naissance, date_deces, code_lieu_deces, empreinte_ligne
FROM bronze.deces
WHERE load_date = '2026-10-30';

DROP TABLE IF EXISTS bench.deces_parquet;
CREATE TABLE bench.deces_parquet STORED AS PARQUET AS
SELECT sexe, date_naissance, date_deces, code_lieu_deces, empreinte_ligne
FROM bronze.deces
WHERE load_date = '2026-10-30';
