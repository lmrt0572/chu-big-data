-- Tables de la couche Silver (voir README_Silver.md).
-- Les tables sont gérées par Hive, au format Parquet, sous /chu/silver.
-- Les dates sont du texte yyyy-MM-dd, car Hive 1.1 refuse le type DATE en Parquet.
-- Les identifiants restent du texte.
-- Chaque ligne porte id_execution, date_chargement et source (R17).
-- Ce fichier peut être relancé sans risque, il ne supprime aucune donnée.

CREATE DATABASE IF NOT EXISTS silver LOCATION '/chu/silver';
USE silver;

-- J11 : référentiels

CREATE TABLE IF NOT EXISTS geographie (
    code_departement STRING,
    libelle_departement STRING,
    code_region STRING,
    libelle_region STRING,
    categorie STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/silver/geographie';

CREATE TABLE IF NOT EXISTS etablissement (
    identifiant_organisation STRING,
    raison_sociale STRING,
    finess_juridique STRING,
    code_commune STRING,
    commune STRING,
    code_postal STRING,
    code_departement STRING,
    code_region STRING,
    origine_region STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/silver/etablissement';

CREATE TABLE IF NOT EXISTS diagnostic (
    code_diag STRING,
    libelle_diagnostic STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/silver/diagnostic';

CREATE TABLE IF NOT EXISTS specialite (
    code_specialite STRING,
    specialite STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/silver/specialite';

-- J12 : patients

CREATE TABLE IF NOT EXISTS patient (
    id_patient_pseudo STRING,
    sexe STRING,
    date_naissance STRING,
    annee_naissance INT,
    doublon_probable BOOLEAN,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/silver/patient';

-- J13 : professionnels

CREATE TABLE IF NOT EXISTS professionnel (
    identifiant STRING,
    type_identifiant STRING,
    profession STRING,
    code_specialite STRING,
    specialite STRING,
    identifiant_organisation STRING,
    mode_exercice STRING,
    nb_etablissements INT,
    attribution STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/silver/professionnel';

-- J14 : consultations

CREATE TABLE IF NOT EXISTS consultation (
    num_consultation STRING,
    id_patient_pseudo STRING,
    identifiant_professionnel STRING,
    code_diag STRING,
    date_consultation STRING,
    heure_debut STRING,
    heure_fin STRING,
    duree_minutes INT,
    identifiant_organisation STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/silver/consultation';

-- J15 : hospitalisations

CREATE TABLE IF NOT EXISTS hospitalisation (
    num_hospitalisation STRING,
    id_patient_pseudo STRING,
    identifiant_organisation STRING,
    code_diag STRING,
    date_entree STRING,
    duree_sejour_jours INT,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/silver/hospitalisation';

-- J16 : décès, partitionnés par année de décès

CREATE TABLE IF NOT EXISTS deces (
    sexe STRING,
    date_naissance STRING,
    annee_naissance INT,
    date_deces STRING,
    age_deces INT,
    code_lieu_deces STRING,
    code_departement STRING,
    code_region STRING,
    empreinte_ligne STRING,
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
PARTITIONED BY (annee_deces INT)
STORED AS PARQUET
LOCATION '/chu/silver/deces';

-- Lignes du nouveau fichier, uniques, contrôlées et typées, avant fusion avec les années déjà présentes.
CREATE TABLE IF NOT EXISTS deces_travail (
    sexe STRING,
    date_naissance STRING,
    annee_naissance INT,
    date_deces STRING,
    age_deces INT,
    code_lieu_deces STRING,
    code_departement STRING,
    code_region STRING,
    empreinte_ligne STRING,
    annee_deces INT
)
STORED AS PARQUET
LOCATION '/chu/silver/deces_travail';

-- J17 : satisfaction

CREATE TABLE IF NOT EXISTS satisfaction (
    annee INT,
    finess_geo STRING,
    finess_juridique STRING,
    identifiant_organisation STRING,
    raison_sociale STRING,
    region_source STRING,
    code_region STRING,
    code_region_etablissement STRING,
    participation STRING,
    depot STRING,
    nb_reponses INT,
    score_global DECIMAL(5,2),
    id_execution STRING,
    date_chargement STRING,
    source STRING
)
STORED AS PARQUET
LOCATION '/chu/silver/satisfaction';

-- Traçabilité (R17, R18)

-- Une partition par job. Chaque job remplace la sienne, donc une relance ne crée pas de doublon.
CREATE TABLE IF NOT EXISTS rejet (
    id_execution STRING,
    source STRING,
    ligne_origine STRING,
    regle STRING,
    motif STRING,
    date_chargement STRING
)
PARTITIONED BY (job STRING)
STORED AS PARQUET
LOCATION '/chu/silver/rejet';

-- Une ligne par table écrite et par exécution, jamais remplacée.
CREATE TABLE IF NOT EXISTS audit (
    id_execution STRING,
    job STRING,
    table_cible STRING,
    debut STRING,
    fin STRING,
    statut STRING,
    lignes_lues BIGINT,
    lignes_ecrites BIGINT,
    lignes_rejetees BIGINT,
    lignes_doublons BIGINT,
    date_chargement STRING
)
STORED AS PARQUET
LOCATION '/chu/silver/audit';
