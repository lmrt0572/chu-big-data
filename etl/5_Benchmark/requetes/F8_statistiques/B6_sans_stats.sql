-- Famille F8 Statistiques (COMPUTE STATS), test B6_sans_stats (voir README_Benchmark.md).
-- B6 sur des copies sans statistiques des consultations et des professionnels (comparer à F4 B6, sur le Gold).
-- Le second critère de tri rend le résultat identique d'un moteur à l'autre en cas d'égalité.
SELECT p.id_professionnel, p.specialite, COUNT(*) AS nb_consultations
FROM bench.consult_sans_stats f
JOIN bench.prof_sans_stats p ON f.id_professionnel = p.id_professionnel
WHERE f.id_temps BETWEEN 20190101 AND 20191231
GROUP BY p.id_professionnel, p.specialite
ORDER BY nb_consultations DESC, id_professionnel
LIMIT 20;
