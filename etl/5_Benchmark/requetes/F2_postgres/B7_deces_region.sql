-- B7 Nombre de décès par région en 2019 (les deux profils, optionnel).
-- Version PostgreSQL, lancée sur le datamart de test chu_bench (famille F2), dans les trois états d'index.
-- Définition du livrable 1 : Compte simple des décès de 2019 par région, pas un taux.
-- Écart avec le livrable 1 : Conforme.
-- Opérations éprouvées : lecture de l'agrégat agg_deces_region (1 068 lignes, une par région et par année).
-- Le datamart ne reçoit que cet agrégat (règle de répartition du livrable 1), alors que la version Hive et Impala
-- lit le détail partitionné du Gold. Les deux versions rendent le même résultat.
-- Résultat attendu : 20 lignes, empreinte c204a9bf61ab.
-- Médiane des essais 2 à 4, au volume réel : Hive 83 s, Impala 0,50 s, PostgreSQL 0,003 s (sur l'agrégat).
SELECT r.code_region, r.libelle_region, SUM(a.nb_deces) AS deces_2019
FROM agg_deces_region a
JOIN dim_region r ON a.id_region = r.id_region
WHERE a.annee_deces = 2019
GROUP BY r.code_region, r.libelle_region;
