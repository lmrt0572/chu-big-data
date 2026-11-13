-- Famille F7 Volume par copies identiques (remplacée par F7b, gardée pour mémoire), test B6_x1 (voir README_Benchmark.md).
-- Consultations par spécialité sur les consultations de départ : la jointure porte sur 1 million de lignes.
SELECT p.specialite, COUNT(*) AS nb_consultations
FROM bench.consult_x1 f
JOIN gold.dim_professionnel p ON f.id_professionnel = p.id_professionnel
GROUP BY p.specialite;
