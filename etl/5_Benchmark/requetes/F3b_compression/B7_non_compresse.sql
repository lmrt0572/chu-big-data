-- Famille F3b Compression de Parquet (Snappy, Gzip, aucune), test B7_non_compresse (voir README_Benchmark.md).
-- B7 (décès de 2019 par région) sur la copie des décès en Parquet non_compresse, sans partition.
SELECT r.code_region, r.libelle_region, SUM(f.nb_deces) AS deces_2019
FROM bench.deces_non_compresse f
JOIN gold.dim_region r ON f.id_region = r.id_region
WHERE f.annee_deces = 2019
GROUP BY r.code_region, r.libelle_region;
