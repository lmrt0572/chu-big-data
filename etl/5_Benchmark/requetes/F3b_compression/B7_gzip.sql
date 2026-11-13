-- Famille F3b Compression de Parquet (Snappy, Gzip, aucune), test B7_gzip (voir README_Benchmark.md).
-- B7 (décès de 2019 par région) sur la copie des décès en Parquet gzip, sans partition.
SELECT r.code_region, r.libelle_region, SUM(f.nb_deces) AS deces_2019
FROM bench.deces_gzip f
JOIN gold.dim_region r ON f.id_region = r.id_region
WHERE f.annee_deces = 2019
GROUP BY r.code_region, r.libelle_region;
