-- J17 Satisfaction : harmonise e-Satis 48 h MCO 2019 et 2020, FINESS géographique, région INSEE.
-- Règles : R16, R17, R18. Aucun rejet, un score absent est gardé mais exclu des moyennes.
-- Contrôle de fin : part des établissements retrouvés (99,7 % en 2020 au profilage).
-- Dépend de J11 (silver.etablissement).
-- Paramètres : load_date, id_execution, debut (voir lancer_silver.sh).

SET hive.auto.convert.join=false;
SET parquet.compression=SNAPPY;
-- Les conteneurs MapReduce de la VM n'ont que 128 Mo par défaut, trop peu pour écrire du Parquet.
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;

-- R16. L'encodage ISO-8859-1 de 2019 est déjà décodé par la table Bronze, il reste un retour chariot en fin de ligne.
-- Virgule décimale remplacée par un point, valeur vide vers NULL.
-- Le FINESS géographique, préfixé de F, donne identifiant_organisation s'il existe dans Silver (R08).
-- Région du fichier traduite en code INSEE 2016. Océan Indien vers La Réunion (04) si FINESS 9704, Mayotte (06) si 9805.
-- code_region_etablissement est la région déduite par J11, gardée pour contrôler la cohérence des deux sources.
INSERT OVERWRITE TABLE silver.satisfaction
SELECT s.annee,
       s.finess_geo,
       s.finess_juridique,
       e.identifiant_organisation,
       s.raison_sociale,
       s.region_source,
       CASE WHEN s.region_min RLIKE '^auvergne' THEN '84'
            WHEN s.region_min RLIKE '^bourgogne' THEN '27'
            WHEN s.region_min = 'bretagne' THEN '53'
            WHEN s.region_min RLIKE '^centre' THEN '24'
            WHEN s.region_min = 'corse' THEN '94'
            WHEN s.region_min = 'grand est' THEN '44'
            WHEN s.region_min = 'guadeloupe' THEN '01'
            WHEN s.region_min = 'guyane' THEN '03'
            WHEN s.region_min RLIKE '^hauts.de.france$' THEN '32'
            WHEN s.region_min RLIKE '^.le.de.france$' THEN '11'
            WHEN s.region_min = 'martinique' THEN '02'
            WHEN s.region_min = 'normandie' THEN '28'
            WHEN s.region_min RLIKE '^nouvelle.aquitaine$' THEN '75'
            WHEN s.region_min = 'occitanie' THEN '76'
            WHEN s.region_min RLIKE 'indien' AND s.finess_geo LIKE '9704%' THEN '04'
            WHEN s.region_min RLIKE 'indien' AND s.finess_geo LIKE '9805%' THEN '06'
            WHEN s.region_min = 'paca' OR s.region_min RLIKE '^provence' THEN '93'
            WHEN s.region_min RLIKE '^pays.de.la.loire$' THEN '52'
            ELSE 'INC' END,
       e.code_region,
       s.participation,
       s.depot,
       s.nb_reponses,
       s.score_global,
       '${hiveconf:id_execution}', '${hiveconf:load_date}', s.source
FROM (
    SELECT annee, finess_geo, finess_juridique, raison_sociale, region_source,
           lower(region_source) AS region_min, participation, depot,
           CAST(IF(nb_rep = '', NULL, nb_rep) AS INT) AS nb_reponses,
           CAST(IF(score = '', NULL, regexp_replace(score, ',', '.')) AS DECIMAL(5,2)) AS score_global,
           source
    FROM (
        SELECT 2019 AS annee, trim(finess_geo) AS finess_geo, trim(finess) AS finess_juridique,
               trim(rs_finess_geo) AS raison_sociale, trim(region) AS region_source,
               trim(participation) AS participation, trim(depot) AS depot,
               trim(regexp_replace(nb_rep_score_all_rea_ajust, '\r', '')) AS nb_rep,
               trim(regexp_replace(score_all_rea_ajust, '\r', '')) AS score,
               'resultats-esatis48h-mco-open-data-2019.csv' AS source
        FROM bronze.esatis_2019
        WHERE load_date = '${hiveconf:load_date}'
        UNION ALL
        SELECT 2020 AS annee, trim(finess_geo) AS finess_geo, trim(finess) AS finess_juridique,
               trim(rs_finess_geo) AS raison_sociale, trim(region) AS region_source,
               trim(participation) AS participation, trim(depot) AS depot,
               trim(nb_rep_score_all_rea_ajust) AS nb_rep, trim(score_all_rea_ajust) AS score,
               'resultats-esatis48h-mco-open-data-2020.xlsx' AS source
        FROM bronze.esatis_2020
        WHERE load_date = '${hiveconf:load_date}'
    ) b
) s
LEFT JOIN silver.etablissement e ON concat('F', s.finess_geo) = e.identifiant_organisation;

-- Audit. Aucun rejet, donc autant de lignes que dans les deux fichiers, une seule par année et FINESS géographique.
-- Le job échoue aussi si une région n'a pas pu être traduite.
INSERT INTO TABLE silver.audit
SELECT '${hiveconf:id_execution}', 'J17', 'satisfaction', '${hiveconf:debut}', from_unixtime(unix_timestamp()),
       IF(l.n = e.n AND e.u = e.n AND e.sans_region = 0, 'OK', 'ECHEC'),
       l.n, e.n, 0L, 0L, '${hiveconf:load_date}'
FROM (
    SELECT SUM(n) AS n FROM (
        SELECT COUNT(*) AS n FROM bronze.esatis_2019 WHERE load_date = '${hiveconf:load_date}'
        UNION ALL
        SELECT COUNT(*) AS n FROM bronze.esatis_2020 WHERE load_date = '${hiveconf:load_date}'
    ) c
) l
CROSS JOIN (
    SELECT COUNT(*) AS n, COUNT(DISTINCT concat(CAST(annee AS STRING), finess_geo)) AS u,
           SUM(IF(code_region = 'INC', 1, 0)) AS sans_region
    FROM silver.satisfaction
) e;

SELECT assert_true(statut = 'OK')
FROM silver.audit
WHERE id_execution = '${hiveconf:id_execution}' AND job = 'J17';

-- Contrôle de fin affiché : part des établissements retrouvés par année.
SELECT 'J17 part retrouvee', annee, ROUND(100 * SUM(IF(identifiant_organisation IS NOT NULL, 1, 0)) / COUNT(*), 2)
FROM silver.satisfaction
GROUP BY annee;
