-- Famille F9 Hive sur Spark (essai qui n'a pas abouti), test B1_hive_spark (voir README_Benchmark.md).
-- Même requête que F4 B1, mais Hive confie l'exécution à Spark au lieu de MapReduce (essai limité à 30 min).
-- Si le coût fixe d'environ 40 s par étape vient bien de MapReduce, il doit disparaître ici après le premier essai.
SET hive.execution.engine=spark;
SET spark.master=yarn-client;
SET spark.executor.instances=1;
SET spark.executor.memory=768m;
SET spark.executor.cores=1;
SET spark.driver.memory=512m;
SELECT e.id_etablissement, e.raison_sociale, t.nb_consultations,
       ROUND(100 * t.nb_consultations / SUM(t.nb_consultations) OVER (), 2) AS part_pct
FROM (
    SELECT id_etablissement, COUNT(*) AS nb_consultations
    FROM gold.fait_consultation
    WHERE id_temps BETWEEN 20190101 AND 20191231
    GROUP BY id_etablissement
) t
JOIN gold.dim_etablissement e ON t.id_etablissement = e.id_etablissement;
