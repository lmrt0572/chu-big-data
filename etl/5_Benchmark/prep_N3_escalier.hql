-- N3 Escalier avant/après : consultations par région, en ne changeant qu'un seul facteur à chaque marche.
--   marche 0 : tables d'origine du Bronze, en texte, 4 jointures, Hive   (requetes/F6_jointures/j1)
--   marche 1 : modèle en étoile, 1 jointure, mais encore en texte        (étoile texte, Hive puis Impala)
--   marche 2 : même modèle en étoile, en Parquet                          (étoile Parquet, Hive puis Impala)
-- Le modèle en étoile est reconstruit depuis le Bronze avec la même règle simplifiée que la marche 0
-- (un seul établissement par professionnel), pour que toutes les marches rendent exactement le même résultat.
CREATE DATABASE IF NOT EXISTS bench;

DROP TABLE IF EXISTS bench.dim_etab_region;
CREATE TABLE bench.dim_etab_region STORED AS PARQUET AS
SELECT e.identifiant_organisation, r.libelle AS region
FROM bronze.etablissement e
JOIN bronze.insee_departement d ON substr(e.code_commune, 1, 2) = d.dep
JOIN bronze.insee_region r ON d.reg = r.reg;

DROP TABLE IF EXISTS bench.fait_consult_etab;
CREATE TABLE bench.fait_consult_etab STORED AS PARQUET AS
SELECT c.num_consultation, a.id_org AS identifiant_organisation
FROM bronze.consultation c
JOIN (
    SELECT identifiant, MIN(identifiant_organisation) AS id_org
    FROM bronze.activite
    WHERE identifiant_organisation <> ''
    GROUP BY identifiant
) a ON c.id_prof_sante = a.identifiant;

-- Les mêmes tables en texte séparé par des tabulations (lisible par Impala, contrairement au Bronze).
DROP TABLE IF EXISTS bench.dim_etab_region_texte;
CREATE TABLE bench.dim_etab_region_texte
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE AS
SELECT identifiant_organisation, region FROM bench.dim_etab_region;

DROP TABLE IF EXISTS bench.fait_consult_etab_texte;
CREATE TABLE bench.fait_consult_etab_texte
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE AS
SELECT num_consultation, identifiant_organisation FROM bench.fait_consult_etab;
