-- Famille F5 Précalcul (tables d'agrégat), test a3_B2_agregat (voir README_Benchmark.md).
-- B2 lu dans la table d'agrégat par diagnostic et par année.
SELECT d.id_diagnostic, d.code_diag, a.nb_consultations,
       ROUND(100 * a.nb_consultations / SUM(a.nb_consultations) OVER (), 2) AS part_pct
FROM bench.agg_consultation_diag a
JOIN gold.dim_diagnostic d ON a.id_diagnostic = d.id_diagnostic
WHERE a.annee = 2019;
