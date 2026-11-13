-- Famille F6 Jointures (modèle en étoile et méthodes de jointure de Hive), test j5b_bucket_map_join_indice (voir README_Benchmark.md).
-- Bucket map join sur les tables en 4 buckets : chaque tâche ne charge en mémoire qu'un bucket des professionnels.
-- Hive 1.1 ne le choisit pas seul sur MapReduce : il faut l'indice MAPJOIN, que Hive ignore par défaut.
SET hive.ignore.mapjoin.hint=false;
SET hive.optimize.bucketmapjoin=true;
-- Sur la VM, la tâche qui charge la petite table plante quand Hive la lance dans un programme à part.
SET hive.exec.submit.local.task.via.child=false;
SELECT /*+ MAPJOIN(p) */ p.specialite, COUNT(*) AS nb_consultations
FROM bench.consult_bucket c
JOIN bench.prof_bucket p ON c.id_professionnel = p.id_professionnel
GROUP BY p.specialite;
