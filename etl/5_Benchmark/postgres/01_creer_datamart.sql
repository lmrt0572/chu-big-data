-- F2 : datamart PostgreSQL de test, chargé depuis l'export du Gold (export_postgres/*.tsv).
-- Lancement depuis le dossier Benchmark/postgres :
--   psql -d chu_bench -v ON_ERROR_STOP=1 -f 01_creer_datamart.sql
--
-- Organisation :
--   dm : les dimensions, communes à tous les volumes ;
--   v1 : les faits du Gold tels quels (1 million de consultations) ;
--   v10, v50 : les consultations recopiées (02_volume.sql). Les autres faits restent dans v1.
-- Une requête lancée avec « search_path = v10, v1, dm » lit donc les consultations de v10 et le reste de v1.
--
-- Aucune clé primaire ni aucun index ici : c'est l'état « sans index » de F2.
-- Les index sont ajoutés par index_1_btree.sql et index_2_couvrant.sql.
-- Les colonnes techniques (id_execution, date_chargement, source) ne sont pas exportées du Gold.

DROP SCHEMA IF EXISTS v50 CASCADE;
DROP SCHEMA IF EXISTS v10 CASCADE;
DROP SCHEMA IF EXISTS v1 CASCADE;
DROP SCHEMA IF EXISTS dm CASCADE;
CREATE SCHEMA dm;
CREATE SCHEMA v1;

-- Dimensions

CREATE TABLE dm.dim_temps (
    id_temps INTEGER,
    date_jour VARCHAR(10),
    jour INTEGER,
    mois INTEGER,
    trimestre INTEGER,
    annee INTEGER
);

CREATE TABLE dm.dim_tranche_age (
    id_tranche_age INTEGER,
    age_min INTEGER,
    age_max INTEGER,
    libelle_tranche VARCHAR(50)
);

CREATE TABLE dm.dim_region (
    id_region INTEGER,
    code_region VARCHAR(10),
    libelle_region VARCHAR(100)
);

-- code_region et libelle_region recopiés de la région (R15), sans lien vers dim_region (schéma en étoile).
CREATE TABLE dm.dim_etablissement (
    id_etablissement INTEGER,
    identifiant_organisation VARCHAR(50),
    raison_sociale VARCHAR(255),
    code_region VARCHAR(10),
    libelle_region VARCHAR(100)
);

CREATE TABLE dm.dim_diagnostic (
    id_diagnostic INTEGER,
    code_diag VARCHAR(20),
    libelle_diagnostic VARCHAR(500)
);

CREATE TABLE dm.dim_patient (
    id_patient INTEGER,
    sexe VARCHAR(10)
);

CREATE TABLE dm.dim_professionnel (
    id_professionnel INTEGER,
    code_professionnel VARCHAR(50),
    specialite VARCHAR(255)
);

-- Faits, volume réel

CREATE TABLE v1.fait_consultation (
    id_consultation INTEGER,
    id_tranche_age INTEGER,
    id_diagnostic INTEGER,
    id_etablissement INTEGER,
    id_professionnel INTEGER,
    id_patient INTEGER,
    id_temps INTEGER
);

CREATE TABLE v1.fait_hospitalisation (
    id_hospitalisation INTEGER,
    id_etablissement INTEGER,
    id_tranche_age INTEGER,
    id_diagnostic INTEGER,
    id_patient INTEGER,
    id_temps_admission INTEGER
);

CREATE TABLE v1.fait_satisfaction (
    id_satisfaction INTEGER,
    nb_avis INTEGER,
    note_globale NUMERIC(5,2),
    id_region INTEGER,
    id_etablissement INTEGER,
    id_temps INTEGER
);

-- Les décès arrivent agrégés par année et par région, comme prévu au livrable 1.
CREATE TABLE v1.agg_deces_region (
    annee_deces INTEGER,
    id_region INTEGER,
    nb_deces BIGINT
);

-- Chargement. impala-shell a écrit les libellés qui contiennent des guillemets à la façon d'un CSV
-- ("EHPAD """"LE VERT GALANT""""" pour la valeur EHPAD ""LE VERT GALANT"" du Gold), d'où le format csv.
-- Les fins de ligne CRLF sont acceptées par COPY.
-- \copy ne remplace pas les variables psql : les options sont donc répétées sur chaque ligne.
\copy dm.dim_temps FROM '../export_postgres/dim_temps.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy dm.dim_tranche_age FROM '../export_postgres/dim_tranche_age.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy dm.dim_region FROM '../export_postgres/dim_region.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy dm.dim_etablissement FROM '../export_postgres/dim_etablissement.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy dm.dim_diagnostic FROM '../export_postgres/dim_diagnostic.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy dm.dim_patient FROM '../export_postgres/dim_patient.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy dm.dim_professionnel FROM '../export_postgres/dim_professionnel.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy v1.fait_consultation FROM '../export_postgres/fait_consultation.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy v1.fait_hospitalisation FROM '../export_postgres/fait_hospitalisation.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy v1.fait_satisfaction FROM '../export_postgres/fait_satisfaction.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy v1.agg_deces_region FROM '../export_postgres/agg_deces_region.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')

-- VACUUM remplit la carte de visibilité, sans laquelle un index couvrant ne peut pas éviter de lire la table.
VACUUM ANALYZE;

-- Contrôle : mêmes nombres de lignes que dans le Gold (fichier moins sa ligne d'en-tête).
SELECT 'dim_temps' AS table_dm, COUNT(*) AS lignes FROM dm.dim_temps
UNION ALL SELECT 'dim_tranche_age', COUNT(*) FROM dm.dim_tranche_age
UNION ALL SELECT 'dim_region', COUNT(*) FROM dm.dim_region
UNION ALL SELECT 'dim_etablissement', COUNT(*) FROM dm.dim_etablissement
UNION ALL SELECT 'dim_diagnostic', COUNT(*) FROM dm.dim_diagnostic
UNION ALL SELECT 'dim_patient', COUNT(*) FROM dm.dim_patient
UNION ALL SELECT 'dim_professionnel', COUNT(*) FROM dm.dim_professionnel
UNION ALL SELECT 'fait_consultation', COUNT(*) FROM v1.fait_consultation
UNION ALL SELECT 'fait_hospitalisation', COUNT(*) FROM v1.fait_hospitalisation
UNION ALL SELECT 'fait_satisfaction', COUNT(*) FROM v1.fait_satisfaction
UNION ALL SELECT 'agg_deces_region', COUNT(*) FROM v1.agg_deces_region;
