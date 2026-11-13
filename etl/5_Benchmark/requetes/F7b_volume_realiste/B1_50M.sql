-- Famille F7b Volume réaliste (1, 10, 50 et 100 millions de consultations), test B1_50M (voir README_Benchmark.md).
-- B1 sur bench.consult_v50 (50M de consultations, palier de volume réaliste). Même requête que F2 B1 dans PostgreSQL.
SELECT e.id_etablissement, e.raison_sociale, t.nb_consultations,
       ROUND(100 * t.nb_consultations / SUM(t.nb_consultations) OVER (), 2) AS part_pct
FROM (
    SELECT id_etablissement, COUNT(*) AS nb_consultations
    FROM bench.consult_v50
    WHERE id_temps BETWEEN 20190101 AND 20191231
    GROUP BY id_etablissement
) t
JOIN gold.dim_etablissement e ON t.id_etablissement = e.id_etablissement;
