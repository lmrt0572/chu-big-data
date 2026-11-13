-- Famille F6 Jointures (modèle en étoile et méthodes de jointure de Hive), test j3_shuffle_join (voir README_Benchmark.md).
-- Consultations par spécialité, jointure de base : toutes les lignes des deux tables passent par le shuffle.
SELECT p.specialite, COUNT(*) AS nb_consultations
FROM bench.consult_simple c
JOIN bench.prof_simple p ON c.id_professionnel = p.id_professionnel
GROUP BY p.specialite;
