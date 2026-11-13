-- F7 Volume : consultations recopiées pour obtenir 1, 10 et 100 millions de lignes (livrable 1, partie d).
-- Chaque copie décale id_consultation de 2 000 000 et garde les mêmes établissements, professionnels et dates.
-- Ces données sont artificielles : elles servent seulement au test de performance.
CREATE DATABASE IF NOT EXISTS bench;

DROP TABLE IF EXISTS bench.copies;
CREATE TABLE bench.copies (n INT) STORED AS PARQUET;
INSERT INTO TABLE bench.copies VALUES
(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
(20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),(31),(32),(33),(34),(35),(36),(37),(38),(39),
(40),(41),(42),(43),(44),(45),(46),(47),(48),(49),(50),(51),(52),(53),(54),(55),(56),(57),(58),(59),
(60),(61),(62),(63),(64),(65),(66),(67),(68),(69),(70),(71),(72),(73),(74),(75),(76),(77),(78),(79),
(80),(81),(82),(83),(84),(85),(86),(87),(88),(89),(90),(91),(92),(93),(94),(95),(96),(97),(98),(99);

-- La table des copies ne compte que 100 lignes : elle tient en mémoire, d'où le map join pour cette étape.
SET hive.auto.convert.join=true;
-- Sur la VM, la tâche qui charge la petite table plante quand Hive la lance dans un programme à part.
SET hive.exec.submit.local.task.via.child=false;

DROP TABLE IF EXISTS bench.consult_x1;
CREATE TABLE bench.consult_x1 STORED AS PARQUET AS
SELECT f.id_consultation + c.n * 2000000 AS id_consultation,
       f.id_etablissement, f.id_diagnostic, f.id_professionnel, f.id_patient, f.id_temps
FROM gold.fait_consultation f
CROSS JOIN bench.copies c
WHERE c.n < 1;

DROP TABLE IF EXISTS bench.consult_x10;
CREATE TABLE bench.consult_x10 STORED AS PARQUET AS
SELECT f.id_consultation + c.n * 2000000 AS id_consultation,
       f.id_etablissement, f.id_diagnostic, f.id_professionnel, f.id_patient, f.id_temps
FROM gold.fait_consultation f
CROSS JOIN bench.copies c
WHERE c.n < 10;

DROP TABLE IF EXISTS bench.consult_x100;
CREATE TABLE bench.consult_x100 STORED AS PARQUET AS
SELECT f.id_consultation + c.n * 2000000 AS id_consultation,
       f.id_etablissement, f.id_diagnostic, f.id_professionnel, f.id_patient, f.id_temps
FROM gold.fait_consultation f
CROSS JOIN bench.copies c;
