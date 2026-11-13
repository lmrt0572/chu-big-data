-- J31 Datamarts, étape Hive : copie texte des tables du Gold à exporter vers PostgreSQL.
-- Sqoop exporte mal le Parquet sous CDH 5 (livrable 1), d'où cette copie en texte séparé par des tabulations,
-- sous /chu/datamart_export. Les valeurs absentes sont écrites \N, que Sqoop relit comme NULL.
-- Les colonnes techniques (R17) ne sont pas recopiées : la traçabilité est assurée par chargement.journal.
-- Les tabulations et retours à la ligne éventuels des libellés sont remplacés par une espace,
-- sinon ils décaleraient les colonnes du fichier texte.
-- Les décès et la satisfaction ne partent qu'agrégés par année et par région (règle de répartition).
-- Paramètre : aucun. Lancé par J31_datamarts.sh, qui contrôle ensuite les volumes.

SET hive.auto.convert.join=false;
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;

CREATE DATABASE IF NOT EXISTS datamart_export LOCATION '/chu/datamart_export';
USE datamart_export;

DROP TABLE IF EXISTS dim_temps;
CREATE TABLE dim_temps ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT id_temps, date_jour, jour, mois, nom_mois, trimestre, semaine_iso, annee FROM gold.dim_temps;

DROP TABLE IF EXISTS dim_tranche_age;
CREATE TABLE dim_tranche_age ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT id_tranche_age, age_min, age_max, libelle_tranche FROM gold.dim_tranche_age;

DROP TABLE IF EXISTS dim_region;
CREATE TABLE dim_region ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT id_region, code_region, regexp_replace(libelle_region, '[\t\r\n]', ' ') AS libelle_region FROM gold.dim_region;

DROP TABLE IF EXISTS dim_etablissement;
CREATE TABLE dim_etablissement ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT id_etablissement, identifiant_organisation,
       regexp_replace(raison_sociale, '[\t\r\n]', ' ') AS raison_sociale,
       code_region, regexp_replace(libelle_region, '[\t\r\n]', ' ') AS libelle_region
FROM gold.dim_etablissement;

DROP TABLE IF EXISTS dim_diagnostic;
CREATE TABLE dim_diagnostic ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT id_diagnostic, code_diag, regexp_replace(libelle_diagnostic, '[\t\r\n]', ' ') AS libelle_diagnostic
FROM gold.dim_diagnostic;

DROP TABLE IF EXISTS dim_patient;
CREATE TABLE dim_patient ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT id_patient, patient_pseudo, sexe FROM gold.dim_patient;

DROP TABLE IF EXISTS dim_professionnel;
CREATE TABLE dim_professionnel ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT id_professionnel, code_professionnel, regexp_replace(specialite, '[\t\r\n]', ' ') AS specialite
FROM gold.dim_professionnel;

DROP TABLE IF EXISTS fait_consultation;
CREATE TABLE fait_consultation ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT id_consultation, num_consultation, nb_consultation, id_tranche_age, id_diagnostic, id_etablissement,
       id_professionnel, id_patient, id_temps
FROM gold.fait_consultation;

DROP TABLE IF EXISTS fait_hospitalisation;
CREATE TABLE fait_hospitalisation ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT id_hospitalisation, num_hospitalisation, nb_hospitalisation, id_etablissement, id_tranche_age,
       id_diagnostic, id_patient, id_temps_admission
FROM gold.fait_hospitalisation;

-- B7 : un nombre de décès par année et par région (environ un millier de lignes au lieu de 25 millions).
DROP TABLE IF EXISTS agg_deces_region;
CREATE TABLE agg_deces_region ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT annee_deces, id_region, SUM(nb_deces) AS nb_deces
FROM gold.fait_deces
GROUP BY annee_deces, id_region;

-- B8 : de quoi recalculer la moyenne pondérée par région, les notes absentes étant exclues (A15).
DROP TABLE IF EXISTS agg_satisfaction_region;
CREATE TABLE agg_satisfaction_region ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE AS
SELECT t.annee, s.id_region,
       COUNT(*) AS nb_etablissements,
       SUM(s.nb_avis) AS nb_avis,
       SUM(CASE WHEN s.note_globale IS NOT NULL THEN s.nb_avis ELSE 0 END) AS nb_avis_notes,
       SUM(CASE WHEN s.note_globale IS NOT NULL THEN s.note_globale * s.nb_avis ELSE 0 END) AS somme_notes_ponderees
FROM gold.fait_satisfaction s
JOIN gold.dim_temps t ON s.id_temps = t.id_temps
GROUP BY t.annee, s.id_region;
