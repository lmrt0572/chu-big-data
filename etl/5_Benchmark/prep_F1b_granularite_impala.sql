-- F1b Granularité des partitions : les décès du Gold rangés par année, par mois, puis par jour.
-- Même données, même requête (B7 sur 2019) ; seule la taille des partitions change.
-- Par année : 51 dossiers de quelques Mo. Par jour : environ 18 600 dossiers de quelques Ko.
-- Le but est de montrer qu'on peut trop partitionner : beaucoup de petits fichiers coûtent cher à lister et à ouvrir.
-- Créé dans Impala : l'indice /* +CLUSTERED */ trie les lignes par partition avant l'écriture,
-- pour n'avoir qu'un fichier ouvert à la fois (sinon des milliers de fichiers ouverts saturent la mémoire).
-- Le démon Impala de la VM n'a que 512 Mo : trier les 24,9 M de décès d'un coup dépasse la limite.
-- Les lignes sont donc écrites par tranches de 3 années (les tranches vides ne coûtent rien).
-- Les trois tables sont écrites de la même façon, pour que seule la granularité change.

CREATE DATABASE IF NOT EXISTS bench;

DROP TABLE IF EXISTS bench.deces_p_annee;
CREATE TABLE bench.deces_p_annee (id_deces BIGINT, nb_deces INT, id_region INT, id_temps INT)
PARTITIONED BY (annee_deces INT)
STORED AS PARQUET;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN -1 AND -1;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1900 AND 1902;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1903 AND 1905;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1906 AND 1908;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1909 AND 1911;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1912 AND 1914;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1915 AND 1917;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1918 AND 1920;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1921 AND 1923;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1924 AND 1926;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1927 AND 1929;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1930 AND 1932;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1933 AND 1935;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1936 AND 1938;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1939 AND 1941;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1942 AND 1944;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1945 AND 1947;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1948 AND 1950;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1951 AND 1953;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1954 AND 1956;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1957 AND 1959;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1960 AND 1962;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1963 AND 1965;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1966 AND 1968;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1969 AND 1971;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1972 AND 1974;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1975 AND 1977;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1978 AND 1980;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1981 AND 1983;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1984 AND 1986;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1987 AND 1989;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1990 AND 1992;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1993 AND 1995;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1996 AND 1998;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 1999 AND 2001;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 2002 AND 2004;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 2005 AND 2007;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 2008 AND 2010;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 2011 AND 2013;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 2014 AND 2016;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 2017 AND 2019;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 2020 AND 2022;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 2023 AND 2025;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 2026 AND 2028;
INSERT INTO bench.deces_p_annee PARTITION (annee_deces) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces
FROM gold.fait_deces WHERE annee_deces BETWEEN 2029 AND 2031;

-- mois et jour sont tirés de id_temps (aaaammjj) ; une date inconnue (-1) donne le mois 0 et le jour 0.
DROP TABLE IF EXISTS bench.deces_p_mois;
CREATE TABLE bench.deces_p_mois (id_deces BIGINT, nb_deces INT, id_region INT, id_temps INT)
PARTITIONED BY (annee_deces INT, mois INT)
STORED AS PARQUET;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN -1 AND -1;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1900 AND 1902;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1903 AND 1905;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1906 AND 1908;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1909 AND 1911;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1912 AND 1914;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1915 AND 1917;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1918 AND 1920;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1921 AND 1923;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1924 AND 1926;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1927 AND 1929;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1930 AND 1932;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1933 AND 1935;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1936 AND 1938;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1939 AND 1941;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1942 AND 1944;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1945 AND 1947;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1948 AND 1950;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1951 AND 1953;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1954 AND 1956;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1957 AND 1959;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1960 AND 1962;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1963 AND 1965;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1966 AND 1968;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1969 AND 1971;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1972 AND 1974;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1975 AND 1977;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1978 AND 1980;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1981 AND 1983;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1984 AND 1986;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1987 AND 1989;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1990 AND 1992;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1993 AND 1995;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1996 AND 1998;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1999 AND 2001;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2002 AND 2004;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2005 AND 2007;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2008 AND 2010;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2011 AND 2013;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2014 AND 2016;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2017 AND 2019;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2020 AND 2022;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2023 AND 2025;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2026 AND 2028;
INSERT INTO bench.deces_p_mois PARTITION (annee_deces, mois) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2029 AND 2031;

DROP TABLE IF EXISTS bench.deces_p_jour;
CREATE TABLE bench.deces_p_jour (id_deces BIGINT, nb_deces INT, id_region INT, id_temps INT)
PARTITIONED BY (annee_deces INT, mois INT, jour INT)
STORED AS PARQUET;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN -1 AND -1;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1900 AND 1902;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1903 AND 1905;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1906 AND 1908;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1909 AND 1911;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1912 AND 1914;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1915 AND 1917;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1918 AND 1920;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1921 AND 1923;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1924 AND 1926;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1927 AND 1929;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1930 AND 1932;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1933 AND 1935;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1936 AND 1938;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1939 AND 1941;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1942 AND 1944;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1945 AND 1947;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1948 AND 1950;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1951 AND 1953;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1954 AND 1956;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1957 AND 1959;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1960 AND 1962;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1963 AND 1965;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1966 AND 1968;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1969 AND 1971;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1972 AND 1974;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1975 AND 1977;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1978 AND 1980;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1981 AND 1983;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1984 AND 1986;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1987 AND 1989;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1990 AND 1992;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1993 AND 1995;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1996 AND 1998;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 1999 AND 2001;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2002 AND 2004;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2005 AND 2007;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2008 AND 2010;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2011 AND 2013;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2014 AND 2016;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2017 AND 2019;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2020 AND 2022;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2023 AND 2025;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2026 AND 2028;
INSERT INTO bench.deces_p_jour PARTITION (annee_deces, mois, jour) /* +CLUSTERED */
SELECT id_deces, nb_deces, id_region, id_temps, annee_deces,
       CAST(CASE WHEN id_temps > 0 THEN pmod(CAST(id_temps / 100 AS INT), 100) ELSE 0 END AS INT),
       CAST(CASE WHEN id_temps > 0 THEN pmod(id_temps, 100) ELSE 0 END AS INT)
FROM gold.fait_deces WHERE annee_deces BETWEEN 2029 AND 2031;

-- Contrôle : mêmes totaux dans les trois tables.
SELECT 'annee' AS rangement, COUNT(*) AS lignes, SUM(nb_deces) AS deces FROM bench.deces_p_annee
UNION ALL SELECT 'mois', COUNT(*), SUM(nb_deces) FROM bench.deces_p_mois
UNION ALL SELECT 'jour', COUNT(*), SUM(nb_deces) FROM bench.deces_p_jour;
