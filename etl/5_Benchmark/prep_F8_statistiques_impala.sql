-- F8 Statistiques : copies des consultations et des dimensions sans statistiques (COMPUTE STATS jamais lancé).
-- Les mêmes requêtes sur les tables du Gold, qui ont leurs statistiques, servent de comparaison.
-- Sans statistiques, Impala ne connaît pas la taille des tables : il peut se tromper de côté pour la table
-- chargée en mémoire dans une jointure, ou choisir une jointure redistribuée au lieu d'une diffusion.
-- lancer_benchmark.sh ne lance pas COMPUTE STATS sur les tables dont le nom contient « sans_stats ».
-- Le test ne tourne que dans Impala : dans Hive, hive.auto.convert.join=false (imposé sur la VM)
-- empêche les statistiques de changer la façon de joindre.

CREATE DATABASE IF NOT EXISTS bench;

DROP TABLE IF EXISTS bench.consult_sans_stats;
CREATE TABLE bench.consult_sans_stats STORED AS PARQUET AS
SELECT id_consultation, id_tranche_age, id_diagnostic, id_etablissement, id_professionnel, id_patient, id_temps
FROM gold.fait_consultation;

DROP TABLE IF EXISTS bench.etab_sans_stats;
CREATE TABLE bench.etab_sans_stats STORED AS PARQUET AS
SELECT id_etablissement, identifiant_organisation, raison_sociale, code_region, libelle_region
FROM gold.dim_etablissement;

DROP TABLE IF EXISTS bench.prof_sans_stats;
CREATE TABLE bench.prof_sans_stats STORED AS PARQUET AS
SELECT id_professionnel, code_professionnel, specialite
FROM gold.dim_professionnel;
