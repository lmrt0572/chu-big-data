-- Famille F7 Volume par copies identiques (remplacée par F7b, gardée pour mémoire), test B1_x10 (voir README_Benchmark.md).
-- B1 sur les consultations recopiées 10 fois, 10 millions de lignes.
SELECT e.id_etablissement, e.raison_sociale, t.nb_consultations,
       ROUND(100 * t.nb_consultations / SUM(t.nb_consultations) OVER (), 2) AS part_pct
FROM (
    SELECT id_etablissement, COUNT(*) AS nb_consultations
    FROM bench.consult_x10
    WHERE id_temps BETWEEN 20190101 AND 20191231
    GROUP BY id_etablissement
) t
JOIN gold.dim_etablissement e ON t.id_etablissement = e.id_etablissement;
