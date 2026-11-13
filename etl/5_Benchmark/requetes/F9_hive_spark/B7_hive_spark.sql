-- Famille F9 Hive sur Spark (essai qui n'a pas abouti), test B7_hive_spark (voir README_Benchmark.md).
-- Même requête que F4 B7, mais Hive confie l'exécution à Spark au lieu de MapReduce (essai limité à 30 min).
-- Si le coût fixe d'environ 40 s par étape vient bien de MapReduce, il doit disparaître ici après le premier essai.
SET hive.execution.engine=spark;
SET spark.master=yarn-client;
SET spark.executor.instances=1;
SET spark.executor.memory=768m;
SET spark.executor.cores=1;
SET spark.driver.memory=512m;
SELECT r.code_region, r.libelle_region, SUM(f.nb_deces) AS deces_2019
FROM gold.fait_deces f
JOIN gold.dim_region r ON f.id_region = r.id_region
WHERE f.annee_deces = 2019
GROUP BY r.code_region, r.libelle_region;
