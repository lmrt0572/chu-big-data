-- Famille F5 Précalcul (tables d'agrégat), test a2_B1_agregat (voir README_Benchmark.md).
-- B1 lu dans la table d'agrégat par établissement et par année.
SELECT e.id_etablissement, e.raison_sociale, a.nb_consultations,
       ROUND(100 * a.nb_consultations / SUM(a.nb_consultations) OVER (), 2) AS part_pct
FROM bench.agg_consultation_etab a
JOIN gold.dim_etablissement e ON a.id_etablissement = e.id_etablissement
WHERE a.annee = 2019;
