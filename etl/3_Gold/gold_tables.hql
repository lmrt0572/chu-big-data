-- Tables de la couche Gold : modèle en étoile, 7 dimensions et 4 tables de faits (voir Spec_Gold.md).
-- Les tables sont gérées par Hive, au format Parquet, sous /chu/gold.
-- Les dimensions et les faits sont recalculés en entier à chaque exécution, donc supprimés puis recréés ici.
-- Les textes sont en STRING comme dans Silver : un VARCHAR trop court couperait la valeur sans prévenir.
-- La table d'audit n'est jamais supprimée, elle garde l'historique des exécutions.

CREATE DATABASE IF NOT EXISTS gold
COMMENT 'Couche Gold - modèle en étoile du CHU'
LOCATION '/chu/gold';

USE gold;

-- Dimensions

DROP TABLE IF EXISTS gold.dim_temps;
CREATE TABLE gold.dim_temps (
    id_temps INT,
    date_jour STRING,
    jour INT,
    mois INT,
    nom_mois STRING,
    trimestre INT,
    semaine_iso INT,
    annee INT,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/dim_temps';

DROP TABLE IF EXISTS gold.dim_tranche_age;
CREATE TABLE gold.dim_tranche_age (
    id_tranche_age INT,
    age_min INT,
    age_max INT,
    libelle_tranche STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/dim_tranche_age';

DROP TABLE IF EXISTS gold.dim_region;
CREATE TABLE gold.dim_region (
    id_region INT,
    code_region STRING,
    libelle_region STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/dim_region';

-- code_region et libelle_region sont recopiés dans la dimension établissement (R15), sans lien vers dim_region :
-- le modèle reste en étoile, sans flocon.
DROP TABLE IF EXISTS gold.dim_etablissement;
CREATE TABLE gold.dim_etablissement (
    id_etablissement INT,
    identifiant_organisation STRING,
    raison_sociale STRING,
    code_region STRING,
    libelle_region STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/dim_etablissement';

DROP TABLE IF EXISTS gold.dim_diagnostic;
CREATE TABLE gold.dim_diagnostic (
    id_diagnostic INT,
    code_diag STRING,
    libelle_diagnostic STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/dim_diagnostic';

-- La date de naissance reste dans Silver (minimisation RGPD).
DROP TABLE IF EXISTS gold.dim_patient;
CREATE TABLE gold.dim_patient (
    id_patient INT,
    patient_pseudo STRING,
    sexe STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/dim_patient';

DROP TABLE IF EXISTS gold.dim_professionnel;
CREATE TABLE gold.dim_professionnel (
    id_professionnel INT,
    code_professionnel STRING,
    specialite STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/dim_professionnel';

-- Faits

DROP TABLE IF EXISTS gold.fait_consultation;
CREATE TABLE gold.fait_consultation (
    id_consultation INT,
    num_consultation STRING,
    nb_consultation INT,
    id_tranche_age INT,
    id_diagnostic INT,
    id_etablissement INT,
    id_professionnel INT,
    id_patient INT,
    id_temps INT,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/fait_consultation';

DROP TABLE IF EXISTS gold.fait_hospitalisation;
CREATE TABLE gold.fait_hospitalisation (
    id_hospitalisation INT,
    num_hospitalisation STRING,
    nb_hospitalisation INT,
    id_etablissement INT,
    id_tranche_age INT,
    id_diagnostic INT,
    id_patient INT,
    id_temps_admission INT,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/fait_hospitalisation';

-- id_deces vaut année x 1 000 000 + rang du décès dans l'année, d'où le BIGINT.
DROP TABLE IF EXISTS gold.fait_deces;
CREATE TABLE gold.fait_deces (
    id_deces BIGINT,
    nb_deces INT,
    id_region INT,
    id_temps INT,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
PARTITIONED BY (annee_deces INT)
STORED AS PARQUET
LOCATION '/chu/gold/fait_deces';

DROP TABLE IF EXISTS gold.fait_satisfaction;
CREATE TABLE gold.fait_satisfaction (
    id_satisfaction INT,
    nb_avis INT,
    note_globale DECIMAL(5,2),
    id_region INT,
    id_etablissement INT,
    id_temps INT,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/fait_satisfaction';

-- Traçabilité (R17, R18) : une ligne par table écrite et par exécution, comme silver.audit.
-- Elle remplace gold.audit_execution, restée vide après le premier essai du 03/11.
DROP TABLE IF EXISTS gold.audit_execution;
CREATE TABLE IF NOT EXISTS gold.audit (
    id_execution STRING,
    job STRING,
    table_cible STRING,
    debut STRING,
    fin STRING,
    statut STRING,
    lignes_lues BIGINT,
    lignes_ecrites BIGINT,
    date_chargement STRING
)
STORED AS PARQUET
LOCATION '/chu/gold/audit';
