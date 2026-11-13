-- Famille F7b Volume réaliste (1, 10, 50 et 100 millions de consultations), test B2_100M (voir README_Benchmark.md).
-- B2 sur bench.consult_v100 (100M de consultations, palier de volume réaliste). Même requête que F2 B2 dans PostgreSQL.
SELECT d.id_diagnostic, d.code_diag, t.nb_consultations,
       ROUND(100 * t.nb_consultations / SUM(t.nb_consultations) OVER (), 2) AS part_pct
FROM (
    SELECT id_diagnostic, COUNT(*) AS nb_consultations
    FROM bench.consult_v100
    WHERE id_temps BETWEEN 20190101 AND 20191231
    GROUP BY id_diagnostic
) t
JOIN gold.dim_diagnostic d ON t.id_diagnostic = d.id_diagnostic;
