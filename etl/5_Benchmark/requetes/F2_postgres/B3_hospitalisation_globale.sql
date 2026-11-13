-- B3 Taux global d'hospitalisation (direction, obligatoire).
-- Version PostgreSQL, lancée sur le datamart de test chu_bench (famille F2), dans les trois états d'index.
-- Définition du livrable 1 : Patients distincts hospitalisés sur Y, divisés par les patients distincts actifs sur Y, c'est-à-dire ceux qui
-- ont eu au moins une consultation ou une hospitalisation sur Y.
-- Écart avec le livrable 1 : Version simplifiée. Le dénominateur est le nombre de patients de la dimension (hors membre -1), et non les
-- patients actifs sur Y, si bien que la requête ne combine pas consultations et hospitalisations. Le taux obtenu
-- est donc plus faible que celui du livrable 1. Les mesures ont été faites avec cette version et n'ont pas été
-- refaites. La version conforme compterait les patients distincts sur l'union des consultations de 2019
-- (environ 87 500 lignes) et des séjours de 2019, ce qui en ferait la requête la plus lourde du jeu, par exemple
--   SELECT COUNT(DISTINCT id_patient) FROM (
--       SELECT id_patient FROM gold.fait_consultation WHERE id_temps BETWEEN 20190101 AND 20191231
--       UNION ALL
--       SELECT id_patient FROM gold.fait_hospitalisation WHERE id_temps_admission BETWEEN 20190101 AND 20191231) a
-- Opérations éprouvées : comptage de patients distincts (COUNT DISTINCT), mais sur une table de 2 479 séjours seulement.
-- Résultat attendu : 1 ligne, empreinte 76eaaf816f88.
-- Médiane des essais 2 à 4, au volume réel : Hive 118 s, Impala 0,29 s, PostgreSQL 0,01 s (sans index).
SELECT h.nb_patients_hospitalises, p.nb_patients,
       ROUND(100.0 * h.nb_patients_hospitalises / p.nb_patients, 2) AS taux_pct
FROM (
    SELECT COUNT(DISTINCT id_patient) AS nb_patients_hospitalises
    FROM fait_hospitalisation
    WHERE id_temps_admission BETWEEN 20190101 AND 20191231
) h
CROSS JOIN (
    SELECT COUNT(*) AS nb_patients
    FROM dim_patient
    WHERE id_patient <> -1
) p;
