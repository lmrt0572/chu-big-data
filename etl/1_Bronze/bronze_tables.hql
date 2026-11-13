-- Tables de la couche Bronze (voir Spec_Bronze.md).
-- Une table externe décrit des fichiers déjà présents dans HDFS. La supprimer ne supprime pas les fichiers.
-- Toutes les colonnes sont en texte, car le typage se fait en Silver.
-- Ce fichier peut être relancé sans risque après chaque job.
-- \073 est le code du caractère point-virgule. Il est écrit ainsi pour que Hive ne coupe pas la commande à cet endroit.

CREATE DATABASE IF NOT EXISTS bronze;
USE bronze;

-- J01 : base PostgreSQL

CREATE EXTERNAL TABLE IF NOT EXISTS patient (
    id_patient_pseudo STRING,
    sexe STRING,
    date_naissance STRING,
    doublon_probable STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/postgres/patient';

CREATE EXTERNAL TABLE IF NOT EXISTS consultation (
    num_consultation STRING,
    id_patient_pseudo STRING,
    id_prof_sante STRING,
    code_diag STRING,
    date_consultation STRING,
    heure_debut STRING,
    heure_fin STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/postgres/consultation';

CREATE EXTERNAL TABLE IF NOT EXISTS professionnel (
    identifiant STRING,
    profession STRING,
    type_identifiant STRING,
    code_specialite STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/postgres/professionnel';

CREATE EXTERNAL TABLE IF NOT EXISTS diagnostic (
    code_diag STRING,
    diagnostic STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/postgres/diagnostic';

CREATE EXTERNAL TABLE IF NOT EXISTS specialite (
    code_specialite STRING,
    fonction STRING,
    specialite STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/postgres/specialite';

-- J02 : référentiels

CREATE EXTERNAL TABLE IF NOT EXISTS etablissement (
    identifiant_organisation STRING,
    raison_sociale_site STRING,
    finess_etablissement_juridique STRING,
    code_commune STRING,
    commune STRING,
    code_postal STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/referentiels/etablissement';

CREATE EXTERNAL TABLE IF NOT EXISTS activite (
    identifiant STRING,
    identifiant_organisation STRING,
    mode_exercice STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/referentiels/activite';

CREATE EXTERNAL TABLE IF NOT EXISTS insee_departement (
    dep STRING,
    reg STRING,
    cheflieu STRING,
    tncc STRING,
    ncc STRING,
    nccenr STRING,
    libelle STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/referentiels/insee_departement';

CREATE EXTERNAL TABLE IF NOT EXISTS insee_region (
    reg STRING,
    cheflieu STRING,
    tncc STRING,
    ncc STRING,
    nccenr STRING,
    libelle STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/referentiels/insee_region';

-- J03 : hospitalisations

CREATE EXTERNAL TABLE IF NOT EXISTS sejour (
    num_hospitalisation STRING,
    id_patient_pseudo STRING,
    identifiant_organisation STRING,
    code_diagnostic STRING,
    date_entree STRING,
    jour_hospitalisation STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/hospitalisations/sejour';

-- J04 : open data

CREATE EXTERNAL TABLE IF NOT EXISTS deces (
    sexe STRING,
    date_naissance STRING,
    date_deces STRING,
    code_lieu_deces STRING,
    empreinte_ligne STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/opendata/deces';

-- Le fichier 2019 est gardé tel quel, en ISO-8859-1, d'où la déclaration de son encodage.
CREATE EXTERNAL TABLE IF NOT EXISTS esatis_2019 (
    finess STRING,
    rs_finess STRING,
    finess_geo STRING,
    rs_finess_geo STRING,
    region STRING,
    participation STRING,
    depot STRING,
    nb_rep_score_all_rea_ajust STRING,
    score_all_rea_ajust STRING,
    classement STRING,
    evolution STRING,
    nb_rep_score_accueil_rea_ajust STRING,
    score_accueil_rea_ajust STRING,
    nb_rep_score_pecinf_rea_ajust STRING,
    score_pecinf_rea_ajust STRING,
    nb_rep_score_pecmed_rea_ajust STRING,
    score_pecmed_rea_ajust STRING,
    nb_rep_score_chambre_rea_ajust STRING,
    score_chambre_rea_ajust STRING,
    nb_rep_score_repas_rea_ajust STRING,
    score_repas_rea_ajust STRING,
    nb_rep_score_sortie_rea_ajust STRING,
    score_sortie_rea_ajust STRING,
    taux_reco_brut STRING,
    nb_reco_brut STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES ('field.delim'='\073', 'serialization.encoding'='ISO-8859-1')
STORED AS TEXTFILE
LOCATION '/chu/bronze/opendata/esatis_2019'
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE IF NOT EXISTS esatis_2020 (
    finess STRING,
    rs_finess STRING,
    finess_geo STRING,
    rs_finess_geo STRING,
    region STRING,
    participation STRING,
    depot STRING,
    nb_rep_score_all_rea_ajust STRING,
    score_all_rea_ajust STRING,
    classement STRING,
    evolution STRING,
    nb_rep_score_accueil_rea_ajust STRING,
    score_accueil_rea_ajust STRING,
    nb_rep_score_pecinf_rea_ajust STRING,
    score_pecinf_rea_ajust STRING,
    nb_rep_score_pecmed_rea_ajust STRING,
    score_pecmed_rea_ajust STRING,
    nb_rep_score_chambre_rea_ajust STRING,
    score_chambre_rea_ajust STRING,
    nb_rep_score_repas_rea_ajust STRING,
    score_repas_rea_ajust STRING,
    nb_rep_score_sortie_rea_ajust STRING,
    score_sortie_rea_ajust STRING,
    taux_reco_brut STRING,
    nb_reco_brut STRING
)
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\073'
STORED AS TEXTFILE
LOCATION '/chu/bronze/opendata/esatis_2020'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Déclare à Hive les dossiers load_date=... présents dans HDFS.
MSCK REPAIR TABLE patient;
MSCK REPAIR TABLE consultation;
MSCK REPAIR TABLE professionnel;
MSCK REPAIR TABLE diagnostic;
MSCK REPAIR TABLE specialite;
MSCK REPAIR TABLE etablissement;
MSCK REPAIR TABLE activite;
MSCK REPAIR TABLE insee_departement;
MSCK REPAIR TABLE insee_region;
MSCK REPAIR TABLE sejour;
MSCK REPAIR TABLE deces;
MSCK REPAIR TABLE esatis_2019;
MSCK REPAIR TABLE esatis_2020;
