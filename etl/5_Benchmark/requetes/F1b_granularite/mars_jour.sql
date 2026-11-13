-- Famille F1b Granularité des partitions (année, mois, jour), test mars_jour (voir README_Benchmark.md).
-- Décès de mars 2019 par région, sur les décès partitionnés par jour.
-- Une question sur un seul mois : ici, des partitions plus fines permettent de lire moins de données.
SELECT r.code_region, r.libelle_region, SUM(f.nb_deces) AS deces_mars_2019
FROM bench.deces_p_jour f
JOIN gold.dim_region r ON f.id_region = r.id_region
WHERE f.annee_deces = 2019 AND f.mois = 3
GROUP BY r.code_region, r.libelle_region;
