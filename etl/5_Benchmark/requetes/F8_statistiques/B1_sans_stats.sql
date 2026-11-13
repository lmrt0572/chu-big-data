-- Famille F8 Statistiques (COMPUTE STATS), test B1_sans_stats (voir README_Benchmark.md).
-- B1 sur des copies sans statistiques des consultations et des établissements (comparer à F4 B1, sur le Gold).
SELECT e.id_etablissement, e.raison_sociale, t.nb_consultations,
       ROUND(100 * t.nb_consultations / SUM(t.nb_consultations) OVER (), 2) AS part_pct
FROM (
    SELECT id_etablissement, COUNT(*) AS nb_consultations
    FROM bench.consult_sans_stats
    WHERE id_temps BETWEEN 20190101 AND 20191231
    GROUP BY id_etablissement
) t
JOIN bench.etab_sans_stats e ON t.id_etablissement = e.id_etablissement;
