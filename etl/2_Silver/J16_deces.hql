-- J16 Décès : dates, sexe, doublons, région, reconstruction des années touchées.
-- Règles : R05, R06, R07, R08, R13, R14, R15, R17, R18.
-- Rejets : date de décès partielle ou illisible, antérieure à 1970, antérieure à la naissance (R13).
-- Contrôle de fin : lignes lues = lignes écrites + rejetées + retirées comme doublons.
-- Dépend de J11 (silver.geographie).
-- Paramètres : load_date, id_execution, debut, seuil_rejet (voir lancer_silver.sh).
--
-- Seule la partition Bronze load_date est lue. Les années de décès qu'elle contient sont reconstruites
-- à partir des lignes déjà présentes et des nouvelles, puis dédoublonnées, les autres années ne bougent pas.

-- Sur la VM, la tâche locale qui charge une table en mémoire échoue même pour une petite table.
SET hive.auto.convert.join=false;
SET parquet.compression=SNAPPY;
-- Les conteneurs MapReduce de la VM n'ont que 128 Mo par défaut, trop peu pour écrire du Parquet.
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.exec.max.dynamic.partitions=2000;
SET hive.exec.max.dynamic.partitions.pernode=2000;
-- Trie par année avant l'écriture, pour qu'un reducer n'ait qu'un fichier Parquet ouvert à la fois.
SET hive.optimize.sort.dynamic.partition=true;

-- Étape 1. Doublons du fichier : empreinte_ligne résume les 10 colonnes d'origine, une seule ligne est gardée par empreinte (R13).
-- Les lignes uniques sont ensuite contrôlées puis écrites dans deces_travail ou dans les rejets.
-- R05. Une date n'est valide que si sa relecture redonne le même texte. 1950, 1950-05 ou 1950-00-00 sont partielles.
-- R06. Âge en années révolues, seulement si la date de naissance est complète.
-- R07. 1 devient M, 2 devient F.
-- R14, R15. 99xxx pour l'étranger, 3 caractères pour l'outre-mer, sinon 2 (2A, 2B, ancien 20). Lieu vide ou inconnu : INC.
FROM (
    SELECT u.*,
           CASE WHEN NOT u.deces_valide THEN 'date de deces partielle ou illisible'
                WHEN u.date_deces < '1970-01-01' THEN 'deces anterieur a 1970'
                WHEN u.naissance_valide AND u.date_deces < u.date_naissance THEN 'deces anterieur a la naissance'
           END AS motif
    FROM (
        SELECT b.*,
               COALESCE(from_unixtime(unix_timestamp(b.date_deces, 'yyyy-MM-dd'), 'yyyy-MM-dd') = b.date_deces, false) AS deces_valide,
               COALESCE(from_unixtime(unix_timestamp(b.date_naissance, 'yyyy-MM-dd'), 'yyyy-MM-dd') = b.date_naissance, false) AS naissance_valide,
               CASE WHEN b.code_lieu_deces RLIKE '^99' THEN '99'
                    WHEN b.code_lieu_deces RLIKE '^9[78]' THEN substr(b.code_lieu_deces, 1, 3)
                    WHEN b.code_lieu_deces <> '' THEN substr(b.code_lieu_deces, 1, 2) END AS dep_lieu
        FROM (
            SELECT trim(sexe) AS sexe, trim(date_naissance) AS date_naissance, trim(date_deces) AS date_deces,
                   upper(trim(code_lieu_deces)) AS code_lieu_deces, trim(empreinte_ligne) AS empreinte_ligne,
                   ROW_NUMBER() OVER (PARTITION BY trim(empreinte_ligne) ORDER BY trim(empreinte_ligne)) AS rang
            FROM bronze.deces
            WHERE load_date = '${hiveconf:load_date}'
        ) b
        WHERE b.rang = 1
    ) u
) d
LEFT JOIN silver.geographie g ON d.dep_lieu = g.code_departement
INSERT OVERWRITE TABLE silver.deces_travail
SELECT CASE d.sexe WHEN '1' THEN 'M' WHEN '2' THEN 'F' END,
       IF(d.naissance_valide, d.date_naissance, NULL),
       IF(d.date_naissance RLIKE '^[0-9]{4}', CAST(substr(d.date_naissance, 1, 4) AS INT), NULL),
       d.date_deces,
       IF(d.naissance_valide,
          CAST(substr(d.date_deces, 1, 4) AS INT) - CAST(substr(d.date_naissance, 1, 4) AS INT)
          - IF(substr(d.date_deces, 6, 5) < substr(d.date_naissance, 6, 5), 1, 0), NULL),
       IF(d.code_lieu_deces = '', NULL, d.code_lieu_deces),
       g.code_departement,
       COALESCE(g.code_region, 'INC'),
       d.empreinte_ligne,
       CAST(substr(d.date_deces, 1, 4) AS INT)
WHERE d.motif IS NULL
INSERT OVERWRITE TABLE silver.rejet PARTITION (job = 'J16')
SELECT '${hiveconf:id_execution}', 'deces.csv',
       concat_ws('\073', d.sexe, d.date_naissance, d.date_deces, d.code_lieu_deces, d.empreinte_ligne),
       'R13', d.motif, '${hiveconf:load_date}'
WHERE d.motif IS NOT NULL;

-- Étape 2. Reconstruction des années touchées. Une ligne déjà présente garde sa traçabilité d'origine,
-- une nouvelle ligne dont l'empreinte existe déjà est un doublon entre deux chargements.
INSERT OVERWRITE TABLE silver.deces PARTITION (annee_deces)
SELECT sexe, date_naissance, annee_naissance, date_deces, age_deces, code_lieu_deces, code_departement,
       code_region, empreinte_ligne, id_execution, date_chargement, source, annee_deces
FROM (
    SELECT x.*, ROW_NUMBER() OVER (PARTITION BY x.empreinte_ligne ORDER BY x.priorite) AS rang
    FROM (
        SELECT s.sexe, s.date_naissance, s.annee_naissance, s.date_deces, s.age_deces, s.code_lieu_deces,
               s.code_departement, s.code_region, s.empreinte_ligne, s.id_execution, s.date_chargement,
               s.source, s.annee_deces, 1 AS priorite
        FROM silver.deces s
        LEFT SEMI JOIN (SELECT DISTINCT annee_deces FROM silver.deces_travail) a ON s.annee_deces = a.annee_deces
        UNION ALL
        SELECT t.sexe, t.date_naissance, t.annee_naissance, t.date_deces, t.age_deces, t.code_lieu_deces,
               t.code_departement, t.code_region, t.empreinte_ligne, '${hiveconf:id_execution}' AS id_execution,
               '${hiveconf:load_date}' AS date_chargement, 'deces.csv' AS source, t.annee_deces, 2 AS priorite
        FROM silver.deces_travail t
    ) x
) y
WHERE rang = 1;

-- Audit. Les doublons sont ceux du fichier plus ceux déjà présents dans Silver.
INSERT INTO TABLE silver.audit
SELECT '${hiveconf:id_execution}', 'J16', 'deces', '${hiveconf:debut}', from_unixtime(unix_timestamp()),
       IF(r.n <= ${hiveconf:seuil_rejet} * l.n, 'OK', 'ECHEC'),
       l.n, e.n, r.n, l.n - e.n - r.n, '${hiveconf:load_date}'
FROM (SELECT COUNT(*) AS n FROM bronze.deces WHERE load_date = '${hiveconf:load_date}') l
CROSS JOIN (SELECT COUNT(*) AS n FROM silver.deces WHERE id_execution = '${hiveconf:id_execution}') e
CROSS JOIN (SELECT COUNT(*) AS n FROM silver.rejet WHERE job = 'J16') r;

SELECT assert_true(statut = 'OK')
FROM silver.audit
WHERE id_execution = '${hiveconf:id_execution}' AND job = 'J16';
