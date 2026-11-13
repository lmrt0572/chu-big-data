-- Famille F5 Précalcul (tables d'agrégat), test a1_B7_agregat (voir README_Benchmark.md).
-- B7 lu dans la table d'agrégat : 21 lignes au lieu de 620 000 décès.
SELECT r.code_region, r.libelle_region, a.nb_deces AS deces_2019
FROM bench.agg_deces_region a
JOIN gold.dim_region r ON a.id_region = r.id_region
WHERE a.annee_deces = 2019;
