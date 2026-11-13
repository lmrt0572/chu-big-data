-- F6 Jointures : tables de test pour les deux comparaisons de jointures.
CREATE DATABASE IF NOT EXISTS bench;

-- 1. Nombre de jointures. Le modèle en étoile est reconstruit depuis le Bronze avec la même règle
-- simplifiée que la requête sur les tables d'origine (un seul établissement par professionnel),
-- pour que les deux versions donnent exactement le même résultat.
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

-- 2. Façon de joindre. Les mêmes données sont rangées deux fois : sans buckets, puis en 4 buckets
-- triés sur id_professionnel des deux côtés de la jointure.
DROP TABLE IF EXISTS bench.consult_simple;
CREATE TABLE bench.consult_simple STORED AS PARQUET AS
SELECT id_consultation, id_professionnel
FROM gold.fait_consultation;

DROP TABLE IF EXISTS bench.prof_simple;
CREATE TABLE bench.prof_simple STORED AS PARQUET AS
SELECT id_professionnel, specialite
FROM gold.dim_professionnel;

-- Sans ces deux réglages, Hive ne garantit pas que les fichiers respectent les buckets déclarés.
SET hive.enforce.bucketing=true;
SET hive.enforce.sorting=true;

DROP TABLE IF EXISTS bench.consult_bucket;
CREATE TABLE bench.consult_bucket (id_consultation INT, id_professionnel INT)
CLUSTERED BY (id_professionnel) SORTED BY (id_professionnel) INTO 4 BUCKETS
STORED AS PARQUET;
INSERT OVERWRITE TABLE bench.consult_bucket
SELECT id_consultation, id_professionnel FROM gold.fait_consultation;

DROP TABLE IF EXISTS bench.prof_bucket;
CREATE TABLE bench.prof_bucket (id_professionnel INT, specialite STRING)
CLUSTERED BY (id_professionnel) SORTED BY (id_professionnel) INTO 4 BUCKETS
STORED AS PARQUET;
INSERT OVERWRITE TABLE bench.prof_bucket
SELECT id_professionnel, specialite FROM gold.dim_professionnel;
