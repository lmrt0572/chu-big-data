-- Famille F6 Jointures (modèle en étoile et méthodes de jointure de Hive), test j5_bucket_map_join (voir README_Benchmark.md).
-- Même requête sur les tables en 4 buckets, en map join automatique.
-- Le plan (EXPLAIN EXTENDED) montre que Hive 1.1 n'en fait pas un bucket map join : c'est un map join ordinaire.
-- Le vrai bucket map join est mesuré dans j5b, avec l'indice MAPJOIN.
SET hive.auto.convert.join=true;
-- Sur la VM, la tâche qui charge la petite table plante quand Hive la lance dans un programme à part.
SET hive.exec.submit.local.task.via.child=false;
SET hive.optimize.bucketmapjoin=true;
SELECT p.specialite, COUNT(*) AS nb_consultations
FROM bench.consult_bucket c
JOIN bench.prof_bucket p ON c.id_professionnel = p.id_professionnel
GROUP BY p.specialite;
