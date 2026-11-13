-- B5 Taux d'hospitalisation par sexe et par âge (praticiens, obligatoire).
-- Version HiveQL, lancée telle quelle dans Hive et dans Impala sur la base gold (famille F4).
-- Définition du livrable 1 : Même calcul que B3 pour un sexe et une tranche d'âge. Un patient qui change de tranche est classé selon
-- son premier événement de la période.
-- Écart avec le livrable 1 : Version simplifiée. La requête compte les séjours et les patients hospitalisés distincts par sexe et par
-- tranche sur toute la période des hospitalisations (2015 à 2021), avec la tranche du séjour, sans dénominateur
-- de patients actifs et sans la règle du premier événement. Les mesures ont été faites avec cette version et
-- n'ont pas été refaites. La version conforme réunirait consultations et séjours de Y, garderait pour chaque
-- patient la tranche de son premier événement (ROW_NUMBER), puis compterait par sexe et par tranche les
-- patients hospitalisés et les patients actifs.
-- Opérations éprouvées : deux jointures (patients et tranches d'âge), regroupement, comptage distinct.
-- Résultat attendu : 14 lignes, empreinte 580bb26d3e95.
-- Médiane des essais 2 à 4, au volume réel : Hive 118 s, Impala 0,61 s, PostgreSQL 0,016 s (sans index).
SELECT p.sexe, ta.libelle_tranche, COUNT(*) AS nb_sejours, COUNT(DISTINCT f.id_patient) AS nb_patients
FROM gold.fait_hospitalisation f
JOIN gold.dim_patient p ON f.id_patient = p.id_patient
JOIN gold.dim_tranche_age ta ON f.id_tranche_age = ta.id_tranche_age
GROUP BY p.sexe, ta.libelle_tranche;
