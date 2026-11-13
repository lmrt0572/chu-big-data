-- Famille F6 Jointures (modèle en étoile et méthodes de jointure de Hive), test j6_sort_merge_bucket (voir README_Benchmark.md).
-- Même requête en sort-merge bucket join : les buckets triés sont fusionnés deux à deux, sans table en mémoire.
SET hive.auto.convert.join=true;
SET hive.auto.convert.sortmerge.join=true;
SET hive.auto.convert.sortmerge.join.to.mapjoin=false;
SET hive.optimize.bucketmapjoin=true;
SET hive.optimize.bucketmapjoin.sortedmerge=true;
SET hive.input.format=org.apache.hadoop.hive.ql.io.BucketizedHiveInputFormat;
SELECT p.specialite, COUNT(*) AS nb_consultations
FROM bench.consult_bucket c
JOIN bench.prof_bucket p ON c.id_professionnel = p.id_professionnel
GROUP BY p.specialite;
