-- Famille F3 Format de stockage (texte contre Parquet), test f2_parquet (voir README_Benchmark.md).
-- Même requête sur la copie en Parquet : seules les colonnes date_deces et code_lieu_deces sont lues.
SELECT substr(code_lieu_deces, 1, 2) AS dep, COUNT(*) AS nb_deces
FROM bench.deces_parquet
WHERE substr(date_deces, 1, 4) = '2019'
GROUP BY substr(code_lieu_deces, 1, 2);
