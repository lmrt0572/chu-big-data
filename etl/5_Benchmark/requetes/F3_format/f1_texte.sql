-- Famille F3 Format de stockage (texte contre Parquet), test f1_texte (voir README_Benchmark.md).
-- Décès 2019 par département, sur la copie en texte : chaque ligne est lue et découpée en entier.
SELECT substr(code_lieu_deces, 1, 2) AS dep, COUNT(*) AS nb_deces
FROM bench.deces_texte
WHERE substr(date_deces, 1, 4) = '2019'
GROUP BY substr(code_lieu_deces, 1, 2);
