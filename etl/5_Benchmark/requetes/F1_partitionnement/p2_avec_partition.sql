-- Famille F1 Partitionnement des décès par année, test p2_avec_partition (voir README_Benchmark.md).
-- B7 sur la table du Gold, partitionnée par année : seul le dossier annee_deces=2019 est lu.
SELECT r.code_region, r.libelle_region, SUM(f.nb_deces) AS deces_2019
FROM gold.fait_deces f
JOIN gold.dim_region r ON f.id_region = r.id_region
WHERE f.annee_deces = 2019
GROUP BY r.code_region, r.libelle_region;
