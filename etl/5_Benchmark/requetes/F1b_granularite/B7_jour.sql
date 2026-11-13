-- Famille F1b Granularité des partitions (année, mois, jour), test B7_jour (voir README_Benchmark.md).
-- B7 (décès de 2019 par région) sur les décès partitionnés par jour. Filtre sur la colonne de partition annee_deces.
SELECT r.code_region, r.libelle_region, SUM(f.nb_deces) AS deces_2019
FROM bench.deces_p_jour f
JOIN gold.dim_region r ON f.id_region = r.id_region
WHERE f.annee_deces = 2019
GROUP BY r.code_region, r.libelle_region;
