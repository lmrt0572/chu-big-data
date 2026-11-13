-- Sécurité des datamarts : rôles par profil, vues métier, sécurité au niveau des lignes (RLS) pour la direction.
-- À lancer en superutilisateur après datamarts_tables.sql (et à relancer après lui, qui recrée les tables) :
--   psql -U postgres -d chu_decisionnel -v ON_ERROR_STOP=1 -f datamarts_securite.sql
--
-- Profils du livrable 1 :
--   lecteur_praticien  lit datamart_praticiens, sans le pseudonyme des patients
--   lecteur_direction  lit datamart_direction, sans le pseudonyme, et seulement les consultations et séjours
--                      des établissements qui lui sont attribués dans datamart_direction.acces_etablissement
-- Ce sont des rôles de groupe, sans connexion. Chaque compte réel (ou le compte de service Power BI d'une direction)
-- en devient membre par GRANT. Les deux comptes de démonstration ci-dessous servent aux tests.

DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'lecteur_praticien') THEN CREATE ROLE lecteur_praticien NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'lecteur_direction') THEN CREATE ROLE lecteur_direction NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'demo_praticien') THEN CREATE ROLE demo_praticien NOLOGIN IN ROLE lecteur_praticien; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'demo_direction') THEN CREATE ROLE demo_direction NOLOGIN IN ROLE lecteur_direction; END IF;
END $$;

REVOKE ALL ON SCHEMA chargement FROM PUBLIC;
REVOKE ALL ON DATABASE chu_decisionnel FROM PUBLIC;
GRANT CONNECT ON DATABASE chu_decisionnel TO chu_etl, lecteur_praticien, lecteur_direction;

SET ROLE chu_etl;

-- 1. Praticiens : toutes les tables, sauf la colonne du pseudonyme (droit par colonne sur dim_patient).

GRANT USAGE ON SCHEMA datamart_praticiens TO lecteur_praticien;
GRANT SELECT ON datamart_praticiens.dim_temps, datamart_praticiens.dim_tranche_age, datamart_praticiens.dim_region,
    datamart_praticiens.dim_etablissement, datamart_praticiens.dim_diagnostic, datamart_praticiens.dim_professionnel,
    datamart_praticiens.fait_consultation, datamart_praticiens.fait_hospitalisation, datamart_praticiens.agg_deces_region
    TO lecteur_praticien;
GRANT SELECT (id_patient, sexe) ON datamart_praticiens.dim_patient TO lecteur_praticien;

-- 2. Direction : établissements attribués à chaque compte, puis RLS sur le détail.

-- L'accès est donné par l'identifiant métier de l'établissement (FINESS préfixé), qui ne change pas d'un chargement
-- à l'autre, contrairement à id_etablissement, renuméroté par J21. Pas de clé étrangère : le TRUNCATE ... CASCADE
-- de chaque publication effacerait sinon les accès.
CREATE TABLE IF NOT EXISTS datamart_direction.acces_etablissement (
    nom_role NAME NOT NULL,
    identifiant_organisation VARCHAR(20) NOT NULL,
    PRIMARY KEY (nom_role, identifiant_organisation)
);

GRANT USAGE ON SCHEMA datamart_direction TO lecteur_direction;
GRANT SELECT ON datamart_direction.dim_temps, datamart_direction.dim_tranche_age, datamart_direction.dim_region,
    datamart_direction.dim_etablissement, datamart_direction.dim_diagnostic, datamart_direction.dim_professionnel,
    datamart_direction.fait_consultation, datamart_direction.fait_hospitalisation, datamart_direction.agg_deces_region,
    datamart_direction.agg_satisfaction_region, datamart_direction.agg_consultation_jour
    TO lecteur_direction;
GRANT SELECT (id_patient, sexe) ON datamart_direction.dim_patient TO lecteur_direction;

-- Le propriétaire (chu_etl, qui charge les tables) n'est pas soumis à la RLS. Les lecteurs le sont :
-- une direction ne voit que les lignes de ses établissements. Les consultations sans établissement (-1)
-- ne sont visibles d'aucune direction. Le total du groupe, nécessaire à B1, est dans agg_consultation_jour.
ALTER TABLE datamart_direction.fait_consultation ENABLE ROW LEVEL SECURITY;
ALTER TABLE datamart_direction.fait_hospitalisation ENABLE ROW LEVEL SECURITY;

-- Les politiques lisent la table des accès avec les droits du lecteur : il doit pouvoir la lire,
-- mais n'y voit que ses propres lignes.
GRANT SELECT ON datamart_direction.acces_etablissement TO lecteur_direction;
ALTER TABLE datamart_direction.acces_etablissement ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ses_acces ON datamart_direction.acces_etablissement;
CREATE POLICY ses_acces ON datamart_direction.acces_etablissement FOR SELECT TO lecteur_direction
    USING (nom_role = current_user);

DROP POLICY IF EXISTS direction_son_etablissement ON datamart_direction.fait_consultation;
DROP POLICY IF EXISTS direction_son_etablissement ON datamart_direction.fait_hospitalisation;
CREATE POLICY direction_son_etablissement ON datamart_direction.fait_consultation FOR SELECT TO lecteur_direction
    USING (id_etablissement IN (SELECT e.id_etablissement FROM datamart_direction.dim_etablissement e
                                JOIN datamart_direction.acces_etablissement a
                                  ON a.identifiant_organisation = e.identifiant_organisation
                                WHERE a.nom_role = current_user));
CREATE POLICY direction_son_etablissement ON datamart_direction.fait_hospitalisation FOR SELECT TO lecteur_direction
    USING (id_etablissement IN (SELECT e.id_etablissement FROM datamart_direction.dim_etablissement e
                                JOIN datamart_direction.acces_etablissement a
                                  ON a.identifiant_organisation = e.identifiant_organisation
                                WHERE a.nom_role = current_user));

-- 3. Vues métier, lisibles par le profil concerné. Elles ne lisent que des tables sans RLS ou des agrégats :
-- une vue s'exécute avec les droits de son propriétaire, elle contournerait donc la RLS si elle lisait le détail.

-- B7, pour les deux profils.
CREATE OR REPLACE VIEW datamart_praticiens.v_deces_region AS
SELECT d.annee_deces, r.code_region, r.libelle_region, d.nb_deces
FROM datamart_praticiens.agg_deces_region d JOIN datamart_praticiens.dim_region r ON r.id_region = d.id_region;

CREATE OR REPLACE VIEW datamart_direction.v_deces_region AS
SELECT d.annee_deces, r.code_region, r.libelle_region, d.nb_deces
FROM datamart_direction.agg_deces_region d JOIN datamart_direction.dim_region r ON r.id_region = d.id_region;

-- B8, pour la direction : moyenne pondérée par le nombre d'avis, scores absents exclus.
CREATE OR REPLACE VIEW datamart_direction.v_satisfaction_region AS
SELECT s.annee, r.code_region, r.libelle_region, s.nb_etablissements, s.nb_avis_notes,
       ROUND(s.somme_notes_ponderees / NULLIF(s.nb_avis_notes, 0), 2) AS score_pondere
FROM datamart_direction.agg_satisfaction_region s JOIN datamart_direction.dim_region r ON r.id_region = s.id_region;

-- B1, dénominateur : consultations du groupe par mois, sans détail.
CREATE OR REPLACE VIEW datamart_direction.v_consultations_groupe_mois AS
SELECT t.annee, t.mois, SUM(c.nb_consultations) AS nb_consultations_groupe
FROM datamart_direction.agg_consultation_jour c JOIN datamart_direction.dim_temps t ON t.id_temps = c.id_temps
GROUP BY t.annee, t.mois;

GRANT SELECT ON datamart_praticiens.v_deces_region TO lecteur_praticien;
GRANT SELECT ON datamart_direction.v_deces_region, datamart_direction.v_satisfaction_region,
    datamart_direction.v_consultations_groupe_mois TO lecteur_direction;

RESET ROLE;
