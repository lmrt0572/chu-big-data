-- Famille F1 Partitionnement des décès par année, test p1_sans_partition (voir README_Benchmark.md).
-- B7 sur la copie sans partition : Hive doit lire les 51 années pour garder 2019.
SELECT r.code_region, r.libelle_region, SUM(f.nb_deces) AS deces_2019
FROM bench.deces_sans_partition f
JOIN gold.dim_region r ON f.id_region = r.id_region
WHERE f.annee_deces = 2019
GROUP BY r.code_region, r.libelle_region;
