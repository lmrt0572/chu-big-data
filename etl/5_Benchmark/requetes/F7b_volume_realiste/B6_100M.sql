-- Famille F7b Volume réaliste (1, 10, 50 et 100 millions de consultations), test B6_100M (voir README_Benchmark.md).
-- B6 sur bench.consult_v100 (100M de consultations, palier de volume réaliste). Même requête que F2 B6 dans PostgreSQL :
-- la jointure avec les professionnels porte sur toutes les consultations de 2019, avant le regroupement.
SELECT p.id_professionnel, p.specialite, COUNT(*) AS nb_consultations
FROM bench.consult_v100 f
JOIN gold.dim_professionnel p ON f.id_professionnel = p.id_professionnel
WHERE f.id_temps BETWEEN 20190101 AND 20191231
GROUP BY p.id_professionnel, p.specialite
ORDER BY nb_consultations DESC, id_professionnel
LIMIT 20;
