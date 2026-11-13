-- Datamarts PostgreSQL (livrable 2, job J31). Voir README.md à la racine du dossier etl.
-- À lancer une fois, en superutilisateur, sur la base chu_decisionnel :
--   psql -U postgres -d chu_decisionnel -v ON_ERROR_STOP=1 -f datamarts_tables.sql
-- Le script peut être relancé : il recrée les tables (vides), la fonction de publication et les droits du compte de chargement.
--
-- Organisation de la base :
--   chargement          tables d'arrivée de Sqoop, sans contrainte, colonnes en texte, et journal des publications
--   datamart_praticiens indicateurs B2, B4, B5, B6, B7
--   datamart_direction  indicateurs B1, B3, B6, B7, B8 (la sécurité par établissement est dans datamarts_securite.sql)
-- Sqoop n'écrit que dans chargement. La fonction chargement.publier() recopie ensuite tout dans les deux datamarts
-- en une seule transaction, après avoir vérifié les volumes (R18) : en cas d'écart ou d'erreur, rien n'est modifié
-- et les tableaux de bord gardent la version précédente, comme le prévoit le livrable 1.
-- Le compte chu_etl, propriétaire des tables, est créé sans mot de passe : celui-ci est fixé à part (voir README).

DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'chu_etl') THEN
        CREATE ROLE chu_etl LOGIN;
    END IF;
END $$;

DROP SCHEMA IF EXISTS datamart_praticiens CASCADE;
DROP SCHEMA IF EXISTS datamart_direction CASCADE;
DROP SCHEMA IF EXISTS chargement CASCADE;
CREATE SCHEMA chargement AUTHORIZATION chu_etl;
CREATE SCHEMA datamart_praticiens AUTHORIZATION chu_etl;
CREATE SCHEMA datamart_direction AUTHORIZATION chu_etl;
SET ROLE chu_etl;

-- 1. Tables d'arrivée. Tout est en texte : les valeurs sont converties et contrôlées par publier(),
-- ce qui évite qu'un export Sqoop échoue à moitié sur une conversion.

CREATE TABLE chargement.dim_temps (id_temps TEXT, date_jour TEXT, jour TEXT, mois TEXT, nom_mois TEXT,
    trimestre TEXT, semaine_iso TEXT, annee TEXT);
CREATE TABLE chargement.dim_tranche_age (id_tranche_age TEXT, age_min TEXT, age_max TEXT, libelle_tranche TEXT);
CREATE TABLE chargement.dim_region (id_region TEXT, code_region TEXT, libelle_region TEXT);
CREATE TABLE chargement.dim_etablissement (id_etablissement TEXT, identifiant_organisation TEXT, raison_sociale TEXT,
    code_region TEXT, libelle_region TEXT);
CREATE TABLE chargement.dim_diagnostic (id_diagnostic TEXT, code_diag TEXT, libelle_diagnostic TEXT);
CREATE TABLE chargement.dim_patient (id_patient TEXT, patient_pseudo TEXT, sexe TEXT);
CREATE TABLE chargement.dim_professionnel (id_professionnel TEXT, code_professionnel TEXT, specialite TEXT);
CREATE TABLE chargement.fait_consultation (id_consultation TEXT, num_consultation TEXT, nb_consultation TEXT,
    id_tranche_age TEXT, id_diagnostic TEXT, id_etablissement TEXT, id_professionnel TEXT, id_patient TEXT, id_temps TEXT);
CREATE TABLE chargement.fait_hospitalisation (id_hospitalisation TEXT, num_hospitalisation TEXT, nb_hospitalisation TEXT,
    id_etablissement TEXT, id_tranche_age TEXT, id_diagnostic TEXT, id_patient TEXT, id_temps_admission TEXT);
CREATE TABLE chargement.agg_deces_region (annee_deces TEXT, id_region TEXT, nb_deces TEXT);
CREATE TABLE chargement.agg_satisfaction_region (annee TEXT, id_region TEXT, nb_etablissements TEXT, nb_avis TEXT,
    nb_avis_notes TEXT, somme_notes_ponderees TEXT);

-- Une ligne par table publiée et par exécution (R17), jamais effacée.
CREATE TABLE chargement.journal (
    id_execution VARCHAR(40),
    table_cible VARCHAR(80),
    lignes BIGINT,
    publie_le TIMESTAMP DEFAULT now()
);

-- 2. Les deux datamarts. Mêmes dimensions dans les deux, avec les tailles du MLD
-- (patient_pseudo en VARCHAR(64) : un HMAC-SHA-256 en hexadécimal fait 64 caractères).
-- Hive 1.1 n'a ni clé primaire ni clé étrangère : elles sont déclarées ici.
-- Seules les clés primaires sont indexées : au volume réel, le benchmark n'a montré aucun gain avec d'autres index.

CREATE FUNCTION chargement.creer_datamart(s TEXT, avec_satisfaction BOOLEAN) RETURNS VOID LANGUAGE plpgsql AS $f$
BEGIN
    EXECUTE format($q$
        CREATE TABLE %1$I.dim_temps (id_temps INTEGER PRIMARY KEY, date_jour DATE, jour INTEGER, mois INTEGER,
            nom_mois VARCHAR(50), trimestre INTEGER, semaine_iso INTEGER, annee INTEGER);
        CREATE TABLE %1$I.dim_tranche_age (id_tranche_age INTEGER PRIMARY KEY, age_min INTEGER, age_max INTEGER,
            libelle_tranche VARCHAR(20));
        CREATE TABLE %1$I.dim_region (id_region INTEGER PRIMARY KEY, code_region VARCHAR(3), libelle_region VARCHAR(50));
        CREATE TABLE %1$I.dim_etablissement (id_etablissement INTEGER PRIMARY KEY, identifiant_organisation VARCHAR(20),
            raison_sociale VARCHAR(255), code_region VARCHAR(3), libelle_region VARCHAR(50));
        CREATE TABLE %1$I.dim_diagnostic (id_diagnostic INTEGER PRIMARY KEY, code_diag VARCHAR(8),
            libelle_diagnostic VARCHAR(255));
        CREATE TABLE %1$I.dim_patient (id_patient INTEGER PRIMARY KEY, patient_pseudo VARCHAR(64), sexe VARCHAR(1));
        CREATE TABLE %1$I.dim_professionnel (id_professionnel INTEGER PRIMARY KEY, code_professionnel VARCHAR(11),
            specialite VARCHAR(100));
        CREATE TABLE %1$I.fait_consultation (
            id_consultation INTEGER PRIMARY KEY, num_consultation VARCHAR(20), nb_consultation INTEGER,
            id_tranche_age INTEGER NOT NULL REFERENCES %1$I.dim_tranche_age,
            id_diagnostic INTEGER NOT NULL REFERENCES %1$I.dim_diagnostic,
            id_etablissement INTEGER NOT NULL REFERENCES %1$I.dim_etablissement,
            id_professionnel INTEGER NOT NULL REFERENCES %1$I.dim_professionnel,
            id_patient INTEGER NOT NULL REFERENCES %1$I.dim_patient,
            id_temps INTEGER NOT NULL REFERENCES %1$I.dim_temps);
        CREATE TABLE %1$I.fait_hospitalisation (
            id_hospitalisation INTEGER PRIMARY KEY, num_hospitalisation VARCHAR(20), nb_hospitalisation INTEGER,
            id_etablissement INTEGER NOT NULL REFERENCES %1$I.dim_etablissement,
            id_tranche_age INTEGER NOT NULL REFERENCES %1$I.dim_tranche_age,
            id_diagnostic INTEGER NOT NULL REFERENCES %1$I.dim_diagnostic,
            id_patient INTEGER NOT NULL REFERENCES %1$I.dim_patient,
            id_temps_admission INTEGER NOT NULL REFERENCES %1$I.dim_temps);
        -- Les décès n'arrivent qu'agrégés par année et par région (règle de répartition du livrable 1).
        CREATE TABLE %1$I.agg_deces_region (
            annee_deces INTEGER, id_region INTEGER REFERENCES %1$I.dim_region, nb_deces BIGINT,
            PRIMARY KEY (annee_deces, id_region));
    $q$, s);
    IF avec_satisfaction THEN
        -- B8 : moyenne pondérée = somme_notes_ponderees / nb_avis_notes, les établissements sans note étant exclus.
        EXECUTE format($q$
            CREATE TABLE %1$I.agg_satisfaction_region (
                annee INTEGER, id_region INTEGER REFERENCES %1$I.dim_region, nb_etablissements INTEGER,
                nb_avis BIGINT, nb_avis_notes BIGINT, somme_notes_ponderees NUMERIC(16,2),
                PRIMARY KEY (annee, id_region));
            -- Dénominateur de B1 pour une direction, qui ne voit que ses propres consultations (RLS) :
            -- le nombre de consultations de tout le groupe, par jour.
            CREATE TABLE %1$I.agg_consultation_jour (
                id_temps INTEGER PRIMARY KEY REFERENCES %1$I.dim_temps, nb_consultations BIGINT);
        $q$, s);
    END IF;
END $f$;

SELECT chargement.creer_datamart('datamart_praticiens', false);
SELECT chargement.creer_datamart('datamart_direction', true);

-- 3. Publication. Appelée par J31 après les exports Sqoop, avec les volumes comptés dans Hive :
--   SELECT * FROM chargement.publier('DM_20261030_120000', 'dim_temps=19724,dim_region=21,...');
-- Tout se passe dans la transaction de l'appel : la moindre erreur (écart de volume, valeur trop longue,
-- clé étrangère sans dimension) annule l'ensemble et laisse les datamarts tels qu'ils étaient.

CREATE FUNCTION chargement.copier(s TEXT, avec_satisfaction BOOLEAN) RETURNS VOID LANGUAGE plpgsql AS $f$
BEGIN
    EXECUTE format($q$
        TRUNCATE %1$I.fait_consultation, %1$I.fait_hospitalisation, %1$I.agg_deces_region,
                 %1$I.dim_temps, %1$I.dim_tranche_age, %1$I.dim_region, %1$I.dim_etablissement,
                 %1$I.dim_diagnostic, %1$I.dim_patient, %1$I.dim_professionnel CASCADE;
        -- Le membre -1 de dim_temps n'a pas de date réelle : seule une date bien formée est convertie.
        INSERT INTO %1$I.dim_temps SELECT id_temps::int,
            CASE WHEN date_jour ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN date_jour::date END,
            jour::int, mois::int, nom_mois, trimestre::int, semaine_iso::int, annee::int FROM chargement.dim_temps;
        INSERT INTO %1$I.dim_tranche_age SELECT id_tranche_age::int, age_min::int, age_max::int, libelle_tranche
            FROM chargement.dim_tranche_age;
        INSERT INTO %1$I.dim_region SELECT id_region::int, code_region, libelle_region FROM chargement.dim_region;
        INSERT INTO %1$I.dim_etablissement SELECT id_etablissement::int, identifiant_organisation, raison_sociale,
            code_region, libelle_region FROM chargement.dim_etablissement;
        INSERT INTO %1$I.dim_diagnostic SELECT id_diagnostic::int, code_diag, libelle_diagnostic
            FROM chargement.dim_diagnostic;
        INSERT INTO %1$I.dim_patient SELECT id_patient::int, patient_pseudo, sexe FROM chargement.dim_patient;
        INSERT INTO %1$I.dim_professionnel SELECT id_professionnel::int, code_professionnel, specialite
            FROM chargement.dim_professionnel;
        INSERT INTO %1$I.fait_consultation SELECT id_consultation::int, num_consultation, nb_consultation::int,
            id_tranche_age::int, id_diagnostic::int, id_etablissement::int, id_professionnel::int, id_patient::int,
            id_temps::int FROM chargement.fait_consultation;
        INSERT INTO %1$I.fait_hospitalisation SELECT id_hospitalisation::int, num_hospitalisation,
            nb_hospitalisation::int, id_etablissement::int, id_tranche_age::int, id_diagnostic::int, id_patient::int,
            id_temps_admission::int FROM chargement.fait_hospitalisation;
        INSERT INTO %1$I.agg_deces_region SELECT annee_deces::int, id_region::int, nb_deces::bigint
            FROM chargement.agg_deces_region;
    $q$, s);
    IF avec_satisfaction THEN
        EXECUTE format($q$
            TRUNCATE %1$I.agg_satisfaction_region, %1$I.agg_consultation_jour;
            INSERT INTO %1$I.agg_satisfaction_region SELECT annee::int, id_region::int, nb_etablissements::int,
                nb_avis::bigint, nb_avis_notes::bigint, somme_notes_ponderees::numeric
                FROM chargement.agg_satisfaction_region;
            INSERT INTO %1$I.agg_consultation_jour SELECT id_temps, COUNT(*) FROM %1$I.fait_consultation
                GROUP BY id_temps;
        $q$, s);
    END IF;
END $f$;

CREATE FUNCTION chargement.publier(p_id_execution TEXT, p_attendus TEXT)
RETURNS TABLE (table_cible TEXT, lignes BIGINT) LANGUAGE plpgsql AS $f$
DECLARE
    paire TEXT;
    nom TEXT;
    attendu BIGINT;
    trouve BIGINT;
BEGIN
    -- R18 : chaque table d'arrivée doit contenir exactement les lignes écrites par Hive.
    FOREACH paire IN ARRAY string_to_array(p_attendus, ',') LOOP
        nom := split_part(paire, '=', 1);
        attendu := split_part(paire, '=', 2)::bigint;
        EXECUTE format('SELECT COUNT(*) FROM chargement.%I', nom) INTO trouve;
        IF trouve <> attendu THEN
            RAISE EXCEPTION 'J31 ECHEC : chargement.% contient % lignes, % attendues', nom, trouve, attendu;
        END IF;
    END LOOP;

    PERFORM chargement.copier('datamart_praticiens', false);
    PERFORM chargement.copier('datamart_direction', true);

    -- Volumes publiés, inscrits au journal et renvoyés à J31.
    FOR table_cible, lignes IN
        SELECT n.nspname || '.' || c.relname, 0::bigint FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname IN ('datamart_praticiens', 'datamart_direction') AND c.relkind = 'r' ORDER BY 1
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM %s', table_cible) INTO lignes;
        INSERT INTO chargement.journal (id_execution, table_cible, lignes) VALUES (p_id_execution, table_cible, lignes);
        RETURN NEXT;
    END LOOP;
END $f$;

-- Vide les tables d'arrivée avant un nouvel export (appelée par J31).
CREATE FUNCTION chargement.vider() RETURNS TEXT LANGUAGE plpgsql AS $f$
BEGIN
    TRUNCATE chargement.dim_temps, chargement.dim_tranche_age, chargement.dim_region, chargement.dim_etablissement,
             chargement.dim_diagnostic, chargement.dim_patient, chargement.dim_professionnel,
             chargement.fait_consultation, chargement.fait_hospitalisation, chargement.agg_deces_region,
             chargement.agg_satisfaction_region;
    RETURN 'tables de chargement videes';
END $f$;

RESET ROLE;
