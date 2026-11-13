-- F7b Volume réaliste : consultations recopiées 10, 50 et 100 fois, avec des clés déplacées à chaque copie.
-- Remplace l'ancien F7, où les copies identiques se compressaient trop bien (12 Mo lus pour 100 M de lignes).
-- Lancé dans Impala (impala-shell -f), pas dans Hive : avec hive.auto.convert.join=false, imposé sur la VM,
-- Hive ferait 10 jointures redistribuées sur 100 M de lignes, trop long et trop gourmand en disque.
--
-- Même formule que Benchmark/postgres/02_volume.sql, pour obtenir exactement les mêmes tables qu'en PostgreSQL :
--   copie k (k = 0 : la ligne d'origine) ; rang = position parmi les valeurs connues triées (0, 1, 2...) ;
--   nouvelle valeur = celle de rang pmod(rang + k * pas, nombre de valeurs) ;
--   pas = 7919 (professionnel), 4547 (établissement), 2003 (diagnostic), 3001 (patient), 31 (date) ;
--   id_consultation + k * 2 000 000 ; les clés inconnues (-1) restent à -1.
-- Ces données sont artificielles : elles servent seulement au test de performance.

CREATE DATABASE IF NOT EXISTS bench;

DROP TABLE IF EXISTS bench.copies;
CREATE TABLE bench.copies (n INT) STORED AS PARQUET;
INSERT INTO bench.copies VALUES
(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
(20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),(31),(32),(33),(34),(35),(36),(37),(38),(39),
(40),(41),(42),(43),(44),(45),(46),(47),(48),(49),(50),(51),(52),(53),(54),(55),(56),(57),(58),(59),
(60),(61),(62),(63),(64),(65),(66),(67),(68),(69),(70),(71),(72),(73),(74),(75),(76),(77),(78),(79),
(80),(81),(82),(83),(84),(85),(86),(87),(88),(89),(90),(91),(92),(93),(94),(95),(96),(97),(98),(99);

DROP TABLE IF EXISTS bench.rang_pro;
CREATE TABLE bench.rang_pro STORED AS PARQUET AS
SELECT id, CAST(ROW_NUMBER() OVER (ORDER BY id) - 1 AS INT) AS rang
FROM (SELECT DISTINCT id_professionnel AS id FROM gold.fait_consultation WHERE id_professionnel <> -1) s;

DROP TABLE IF EXISTS bench.rang_etab;
CREATE TABLE bench.rang_etab STORED AS PARQUET AS
SELECT id, CAST(ROW_NUMBER() OVER (ORDER BY id) - 1 AS INT) AS rang
FROM (SELECT DISTINCT id_etablissement AS id FROM gold.fait_consultation WHERE id_etablissement <> -1) s;

DROP TABLE IF EXISTS bench.rang_diag;
CREATE TABLE bench.rang_diag STORED AS PARQUET AS
SELECT id, CAST(ROW_NUMBER() OVER (ORDER BY id) - 1 AS INT) AS rang
FROM (SELECT DISTINCT id_diagnostic AS id FROM gold.fait_consultation WHERE id_diagnostic <> -1) s;

DROP TABLE IF EXISTS bench.rang_pat;
CREATE TABLE bench.rang_pat STORED AS PARQUET AS
SELECT id, CAST(ROW_NUMBER() OVER (ORDER BY id) - 1 AS INT) AS rang
FROM (SELECT DISTINCT id_patient AS id FROM gold.fait_consultation WHERE id_patient <> -1) s;

DROP TABLE IF EXISTS bench.rang_date;
CREATE TABLE bench.rang_date STORED AS PARQUET AS
SELECT id, CAST(ROW_NUMBER() OVER (ORDER BY id) - 1 AS INT) AS rang
FROM (SELECT DISTINCT id_temps AS id FROM gold.fait_consultation WHERE id_temps <> -1) s;

DROP TABLE IF EXISTS bench.nb_rangs;
CREATE TABLE bench.nb_rangs STORED AS PARQUET AS
SELECT p.n AS n_pro, e.n AS n_etab, d.n AS n_diag, pa.n AS n_pat, t.n AS n_date
FROM (SELECT COUNT(*) AS n FROM bench.rang_pro) p
CROSS JOIN (SELECT COUNT(*) AS n FROM bench.rang_etab) e
CROSS JOIN (SELECT COUNT(*) AS n FROM bench.rang_diag) d
CROSS JOIN (SELECT COUNT(*) AS n FROM bench.rang_pat) pa
CROSS JOIN (SELECT COUNT(*) AS n FROM bench.rang_date) t;

COMPUTE STATS bench.rang_pro;
COMPUTE STATS bench.rang_etab;
COMPUTE STATS bench.rang_diag;
COMPUTE STATS bench.rang_pat;
COMPUTE STATS bench.rang_date;

-- Une vue porte la formule ; chaque palier ne garde que ses copies.
DROP VIEW IF EXISTS bench.consult_varie;
CREATE VIEW bench.consult_varie AS
SELECT k.n AS copie,
       CAST(c.id_consultation + k.n * 2000000 AS INT) AS id_consultation,
       c.id_tranche_age,
       COALESCE(d2.id, c.id_diagnostic) AS id_diagnostic,
       COALESCE(e2.id, c.id_etablissement) AS id_etablissement,
       COALESCE(p2.id, c.id_professionnel) AS id_professionnel,
       COALESCE(pa2.id, c.id_patient) AS id_patient,
       COALESCE(t2.id, c.id_temps) AS id_temps
FROM gold.fait_consultation c
CROSS JOIN bench.copies k
CROSS JOIN bench.nb_rangs nb
LEFT JOIN bench.rang_pro p1 ON p1.id = c.id_professionnel
LEFT JOIN bench.rang_pro p2 ON p2.rang = pmod(p1.rang + k.n * 7919, nb.n_pro)
LEFT JOIN bench.rang_etab e1 ON e1.id = c.id_etablissement
LEFT JOIN bench.rang_etab e2 ON e2.rang = pmod(e1.rang + k.n * 4547, nb.n_etab)
LEFT JOIN bench.rang_diag d1 ON d1.id = c.id_diagnostic
LEFT JOIN bench.rang_diag d2 ON d2.rang = pmod(d1.rang + k.n * 2003, nb.n_diag)
LEFT JOIN bench.rang_pat pa1 ON pa1.id = c.id_patient
LEFT JOIN bench.rang_pat pa2 ON pa2.rang = pmod(pa1.rang + k.n * 3001, nb.n_pat)
LEFT JOIN bench.rang_date t1 ON t1.id = c.id_temps
LEFT JOIN bench.rang_date t2 ON t2.rang = pmod(t1.rang + k.n * 31, nb.n_date);

DROP TABLE IF EXISTS bench.consult_v10;
CREATE TABLE bench.consult_v10 STORED AS PARQUET AS
SELECT id_consultation, id_tranche_age, id_diagnostic, id_etablissement, id_professionnel, id_patient, id_temps
FROM bench.consult_varie WHERE copie < 10;

DROP TABLE IF EXISTS bench.consult_v50;
CREATE TABLE bench.consult_v50 STORED AS PARQUET AS
SELECT id_consultation, id_tranche_age, id_diagnostic, id_etablissement, id_professionnel, id_patient, id_temps
FROM bench.consult_varie WHERE copie < 50;

DROP TABLE IF EXISTS bench.consult_v100;
CREATE TABLE bench.consult_v100 STORED AS PARQUET AS
SELECT id_consultation, id_tranche_age, id_diagnostic, id_etablissement, id_professionnel, id_patient, id_temps
FROM bench.consult_varie;

-- Contrôles, à comparer avec 02_volume.sql dans PostgreSQL (10 271 570 lignes, 63,87 % rattachées, 11,45 % en 2019).
SELECT COUNT(*) AS lignes,
       ROUND(100 * SUM(CASE WHEN id_etablissement <> -1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_rattachees,
       ROUND(100 * SUM(CASE WHEN id_temps BETWEEN 20190101 AND 20191231 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_2019
FROM bench.consult_v10;
