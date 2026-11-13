-- F5 Précalcul : tables d'agrégat, l'équivalent du job J23 prévu dans la conception.
-- Le calcul est fait une fois ici, et les requêtes B7, B1 et B2 ne lisent plus que le résultat.
CREATE DATABASE IF NOT EXISTS bench;

-- Au plus 21 lignes par année, quel que soit le nombre de décès.
DROP TABLE IF EXISTS bench.agg_deces_region;
CREATE TABLE bench.agg_deces_region STORED AS PARQUET AS
SELECT annee_deces, id_region, SUM(nb_deces) AS nb_deces
FROM gold.fait_deces
GROUP BY annee_deces, id_region;

-- id_temps vaut AAAAMMJJ, donc l'année est id_temps / 10000 arrondi vers le bas.
DROP TABLE IF EXISTS bench.agg_consultation_etab;
CREATE TABLE bench.agg_consultation_etab STORED AS PARQUET AS
SELECT CAST(FLOOR(id_temps / 10000) AS INT) AS annee, id_etablissement, COUNT(*) AS nb_consultations
FROM gold.fait_consultation
GROUP BY CAST(FLOOR(id_temps / 10000) AS INT), id_etablissement;

DROP TABLE IF EXISTS bench.agg_consultation_diag;
CREATE TABLE bench.agg_consultation_diag STORED AS PARQUET AS
SELECT CAST(FLOOR(id_temps / 10000) AS INT) AS annee, id_diagnostic, COUNT(*) AS nb_consultations
FROM gold.fait_consultation
GROUP BY CAST(FLOOR(id_temps / 10000) AS INT), id_diagnostic;
