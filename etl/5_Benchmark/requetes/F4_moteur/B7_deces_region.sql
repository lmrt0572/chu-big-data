-- B7 Nombre de décès par région en 2019 (les deux profils, optionnel).
-- Version HiveQL, lancée telle quelle dans Hive et dans Impala sur la base gold (famille F4).
-- Définition du livrable 1 : Compte simple des décès de 2019 par région, pas un taux.
-- Écart avec le livrable 1 : Conforme.
-- Opérations éprouvées : agrégation sur la table des décès (24,9 millions de lignes), filtrée sur la colonne de partition annee_deces,
-- si bien que seul le dossier de 2019 est lu.
-- Résultat attendu : 20 lignes, empreinte c204a9bf61ab.
-- Médiane des essais 2 à 4, au volume réel : Hive 83 s, Impala 0,50 s, PostgreSQL 0,003 s (sur l'agrégat).
SELECT r.code_region, r.libelle_region, SUM(f.nb_deces) AS deces_2019
FROM gold.fait_deces f
JOIN gold.dim_region r ON f.id_region = r.id_region
WHERE f.annee_deces = 2019
GROUP BY r.code_region, r.libelle_region;
