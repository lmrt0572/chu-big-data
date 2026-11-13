-- =====================================================================
-- Vues de la couche Gold lues par Power BI en DirectQuery (livrable 3)
--
-- À lancer une fois sur chaque VM, dans Hue (éditeur Impala) ou avec :
--   impala-shell -i quickstart.cloudera -f vues_powerbi.sql
-- Le script ne copie aucune donnée et ne modifie aucune table du Gold.
-- Une vue est une requête enregistrée sous un nom : Impala la recalcule
-- à chaque fois que Power BI l'interroge. Les vues survivent à un
-- rechargement du Gold, car les jobs du livrable 2 recréent les tables
-- sans supprimer la base.
--
-- En DirectQuery, Power BI ne garde pas les données : chaque visuel envoie
-- sa requête SQL à Impala. Les transformations que faisait Power Query
-- (accents, dates, regroupements) sont donc faites ici, par Impala, pour
-- que Power BI n'ait plus qu'à lire des colonnes prêtes.
-- Écrit pour Impala 2.9 (CDH 5.12), la version de la VM QuickStart.
-- =====================================================================

-- 1. Dimensions

-- Le jour devient une vraie date, et le premier jour du mois sert d'axe aux courbes par mois.
-- Le jour inconnu (-1) a la date « inconnu » dans le Gold : il reste sans date.
DROP VIEW IF EXISTS gold.bi_dim_temps;
CREATE VIEW gold.bi_dim_temps AS
SELECT id_temps,
       CASE WHEN id_temps = -1 THEN CAST(NULL AS TIMESTAMP) ELSE CAST(date_jour AS TIMESTAMP) END AS date_jour,
       jour, mois, nom_mois, trimestre, semaine_iso, annee,
       CASE WHEN id_temps = -1 THEN CAST(NULL AS TIMESTAMP)
            ELSE TRUNC(CAST(date_jour AS TIMESTAMP), 'MM') END AS debut_mois
FROM gold.dim_temps;

DROP VIEW IF EXISTS gold.bi_dim_tranche_age;
CREATE VIEW gold.bi_dim_tranche_age AS
SELECT id_tranche_age, age_min, age_max,
       CASE WHEN libelle_tranche = 'inconnu' THEN 'Âge inconnu' ELSE libelle_tranche END AS libelle_tranche
FROM gold.dim_tranche_age;

DROP VIEW IF EXISTS gold.bi_dim_region;
CREATE VIEW gold.bi_dim_region AS
SELECT id_region, code_region, libelle_region
FROM gold.dim_region;

-- Le libellé de la région vient de dim_region : le Gold du 03/11 n'a pas libelle_region dans dim_etablissement.
DROP VIEW IF EXISTS gold.bi_dim_etablissement;
CREATE VIEW gold.bi_dim_etablissement AS
SELECT e.id_etablissement, e.identifiant_organisation, e.raison_sociale, e.code_region,
       NVL(r.libelle_region, 'Inconnu') AS libelle_region
FROM gold.dim_etablissement e
LEFT JOIN gold.dim_region r ON r.code_region = e.code_region;

DROP VIEW IF EXISTS gold.bi_dim_diagnostic;
CREATE VIEW gold.bi_dim_diagnostic AS
SELECT id_diagnostic, code_diag, libelle_diagnostic
FROM gold.dim_diagnostic;

-- Le pseudonyme du patient n'est pas repris : Power BI ne peut pas le lire.
DROP VIEW IF EXISTS gold.bi_dim_patient;
CREATE VIEW gold.bi_dim_patient AS
SELECT id_patient, sexe,
       CASE sexe WHEN 'M' THEN 'Homme' WHEN 'F' THEN 'Femme' ELSE 'Inconnu' END AS libelle_sexe
FROM gold.dim_patient;

-- La source écrit les spécialités sans accents : la vue les rétablit pour les plus fréquentes.
DROP VIEW IF EXISTS gold.bi_dim_professionnel;
CREATE VIEW gold.bi_dim_professionnel AS
SELECT id_professionnel, code_professionnel,
       CASE specialite
           WHEN 'Medecine Generale' THEN 'Médecine générale'
           WHEN 'Anesthesie-reanimation' THEN 'Anesthésie-réanimation'
           WHEN 'Radio-diagnostic' THEN 'Radiodiagnostic'
           WHEN 'Pediatrie' THEN 'Pédiatrie'
           WHEN 'Medecine du travail' THEN 'Médecine du travail'
           WHEN 'Gynecologie-obstetrique' THEN 'Gynécologie-obstétrique'
           WHEN 'Chirurgie generale' THEN 'Chirurgie générale'
           WHEN 'Dermatologie et venereologie' THEN 'Dermatologie et vénéréologie'
           WHEN 'Gastro-enterologie et hepatologie' THEN 'Gastro-entérologie et hépatologie'
           WHEN 'Chirurgie orthopedique et traumatologie' THEN 'Chirurgie orthopédique et traumatologie'
           WHEN 'Gynecologie medicale et obstetrique' THEN 'Gynécologie médicale et obstétrique'
           WHEN 'Biologie medicale' THEN 'Biologie médicale'
           WHEN 'Medecine interne' THEN 'Médecine interne'
           ELSE specialite
       END AS specialite
FROM gold.dim_professionnel;


-- 2. Faits, avec seulement les colonnes utiles aux indicateurs

DROP VIEW IF EXISTS gold.bi_fait_consultation;
CREATE VIEW gold.bi_fait_consultation AS
SELECT id_consultation, id_tranche_age, id_diagnostic, id_etablissement, id_professionnel, id_patient, id_temps
FROM gold.fait_consultation;

DROP VIEW IF EXISTS gold.bi_fait_hospitalisation;
CREATE VIEW gold.bi_fait_hospitalisation AS
SELECT id_hospitalisation, id_etablissement, id_tranche_age, id_diagnostic, id_patient, id_temps_admission
FROM gold.fait_hospitalisation;


-- 3. Regroupements faits par Impala à chaque requête

-- Décès par année et par région. Un filtre sur l'année ne lit que la partition de cette année.
DROP VIEW IF EXISTS gold.bi_agg_deces_region;
CREATE VIEW gold.bi_agg_deces_region AS
SELECT annee_deces, id_region, SUM(nb_deces) AS nb_deces
FROM gold.fait_deces
GROUP BY annee_deces, id_region;

-- Satisfaction par année et par région. Seuls les avis notés comptent, chaque note pondérée
-- par son nombre d'avis. Le calcul se fait en DOUBLE pour ne pas tronquer les décimales.
DROP VIEW IF EXISTS gold.bi_agg_satisfaction_region;
CREATE VIEW gold.bi_agg_satisfaction_region AS
SELECT t.annee, s.id_region,
       COUNT(*) AS nb_etablissements,
       SUM(s.nb_avis) AS nb_avis,
       SUM(CASE WHEN s.note_globale IS NOT NULL THEN s.nb_avis ELSE 0 END) AS nb_avis_notes,
       SUM(CASE WHEN s.note_globale IS NOT NULL THEN CAST(s.note_globale AS DOUBLE) * s.nb_avis
                ELSE CAST(0 AS DOUBLE) END) AS somme_notes_ponderees
FROM gold.fait_satisfaction s
JOIN gold.dim_temps t ON t.id_temps = s.id_temps
GROUP BY t.annee, s.id_region;

-- Consultations de chaque jour pour tout le groupe. Cette vue n'est reliée à aucun établissement,
-- donc le rôle de sécurité ne la filtre pas : elle donne le total du groupe pour B1.
DROP VIEW IF EXISTS gold.bi_agg_consultation_jour;
CREATE VIEW gold.bi_agg_consultation_jour AS
SELECT id_temps, COUNT(*) AS nb_consultations
FROM gold.fait_consultation
GROUP BY id_temps;

-- Taux d'hospitalisation du groupe (B3), par mois puis par année : patients venus (consultation
-- ou séjour) et patients hospitalisés. Comme la vue précédente, le rôle de sécurité ne la filtre pas.
DROP VIEW IF EXISTS gold.bi_b3_groupe_mois;
CREATE VIEW gold.bi_b3_groupe_mois AS
SELECT v.annee, v.mois, COUNT(*) AS patients_actifs, MAX(x.patients_hospitalises) AS patients_hospitalises
FROM (SELECT t.annee, t.mois, c.id_patient FROM gold.fait_consultation c
        JOIN gold.dim_temps t ON t.id_temps = c.id_temps
      UNION
      SELECT t.annee, t.mois, h.id_patient FROM gold.fait_hospitalisation h
        JOIN gold.dim_temps t ON t.id_temps = h.id_temps_admission) v
LEFT JOIN (SELECT t.annee, t.mois, COUNT(DISTINCT h.id_patient) AS patients_hospitalises
             FROM gold.fait_hospitalisation h
             JOIN gold.dim_temps t ON t.id_temps = h.id_temps_admission
            GROUP BY t.annee, t.mois) x ON x.annee = v.annee AND x.mois = v.mois
GROUP BY v.annee, v.mois;

DROP VIEW IF EXISTS gold.bi_b3_groupe_annee;
CREATE VIEW gold.bi_b3_groupe_annee AS
SELECT v.annee, COUNT(*) AS patients_actifs, MAX(x.patients_hospitalises) AS patients_hospitalises
FROM (SELECT t.annee, c.id_patient FROM gold.fait_consultation c
        JOIN gold.dim_temps t ON t.id_temps = c.id_temps
      UNION
      SELECT t.annee, h.id_patient FROM gold.fait_hospitalisation h
        JOIN gold.dim_temps t ON t.id_temps = h.id_temps_admission) v
LEFT JOIN (SELECT t.annee, COUNT(DISTINCT h.id_patient) AS patients_hospitalises
             FROM gold.fait_hospitalisation h
             JOIN gold.dim_temps t ON t.id_temps = h.id_temps_admission
            GROUP BY t.annee) x ON x.annee = v.annee
GROUP BY v.annee;


-- 4. Vérification

-- Les quatorze vues doivent apparaître.
SHOW TABLES IN gold LIKE 'bi_*';

-- Attendu pour 2019 : 87 497 consultations, 373 patients hospitalisés sur 58 797 venus,
-- 620 490 décès, score 73,43 (73,64 en 2020), et 1 jour sans date (le jour inconnu).
SELECT a.consultations, b.patients_hospitalises, b.patients_actifs, d.deces, s.score_2019, s.score_2020, j.sans_date
FROM (SELECT SUM(nb_consultations) AS consultations FROM gold.bi_agg_consultation_jour
       WHERE id_temps BETWEEN 20190101 AND 20191231) a
CROSS JOIN (SELECT patients_hospitalises, patients_actifs FROM gold.bi_b3_groupe_annee WHERE annee = 2019) b
CROSS JOIN (SELECT SUM(nb_deces) AS deces FROM gold.bi_agg_deces_region WHERE annee_deces = 2019) d
CROSS JOIN (SELECT ROUND(SUM(CASE WHEN annee = 2019 THEN somme_notes_ponderees END)
                         / SUM(CASE WHEN annee = 2019 THEN nb_avis_notes END), 2) AS score_2019,
                   ROUND(SUM(CASE WHEN annee = 2020 THEN somme_notes_ponderees END)
                         / SUM(CASE WHEN annee = 2020 THEN nb_avis_notes END), 2) AS score_2020
              FROM gold.bi_agg_satisfaction_region) s
CROSS JOIN (SELECT COUNT(*) AS sans_date FROM gold.bi_dim_temps WHERE date_jour IS NULL) j;
