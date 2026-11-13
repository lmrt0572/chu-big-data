-- J21 Dimensions : les 7 dimensions du modèle en étoile, chacune avec son membre -1 (inconnu).
-- Règles : R06, R08, R17, R18.
-- Contrôle de fin : chaque dimension a autant de lignes que sa source plus le membre -1, et aucune clé métier en double.
-- Dépend de J11 à J13 (silver.geographie, etablissement, diagnostic, patient, professionnel).
-- Paramètres : date_chargement, id_execution, debut (voir lancer_gold.sh).
--
-- Le premier essai du 03/11 a échoué sur des SELECT sans FROM réunis par UNION ALL (« The abstract syntax tree is null »).
-- Comme dans le Silver, les lignes fixes sont lues dans une table d'une ligne : un COUNT(*) sans GROUP BY en rend toujours une.

-- Sur la VM, la tâche locale qui charge une table en mémoire échoue même pour une petite table.
SET hive.auto.convert.join=false;
SET parquet.compression=SNAPPY;
-- Les conteneurs MapReduce de la VM n'ont que 128 Mo par défaut, trop peu pour écrire du Parquet.
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;

-- R08. Membre -1 de chaque dimension, écrit en premier. Les vraies lignes sont ajoutées ensuite avec INSERT INTO.
-- Sa clé métier vaut inconnu (INC pour la région, comme dans Silver), jamais NULL, pour rester comptée dans le contrôle de fin.
FROM (SELECT COUNT(*) AS n FROM silver.specialite) une_ligne
INSERT OVERWRITE TABLE gold.dim_temps
SELECT -1, 'inconnu', -1, -1, 'inconnu', -1, -1, -1,
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'membre inconnu'
INSERT OVERWRITE TABLE gold.dim_region
SELECT -1, 'INC', 'Inconnu',
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'membre inconnu'
INSERT OVERWRITE TABLE gold.dim_etablissement
SELECT -1, 'INCONNU', 'Non rattaché ou inconnu', 'INC', 'Inconnu',
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'membre inconnu'
INSERT OVERWRITE TABLE gold.dim_diagnostic
SELECT -1, 'INCONNU', 'Diagnostic inconnu',
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'membre inconnu'
INSERT OVERWRITE TABLE gold.dim_patient
SELECT -1, 'INCONNU', 'I',
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'membre inconnu'
INSERT OVERWRITE TABLE gold.dim_professionnel
SELECT -1, 'INCONNU', 'inconnu',
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'membre inconnu';

-- R06. Tranches d'âge, membre -1 compris. J22 reprend les mêmes bornes.
INSERT OVERWRITE TABLE gold.dim_tranche_age
SELECT t.id_tranche_age, t.age_min, t.age_max, t.libelle_tranche,
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'tranches R06'
FROM (
    SELECT stack(7,
        -1, -1, -1, 'inconnu',
        1, 0, 17, '0-17 ans',
        2, 18, 25, '18-25 ans',
        3, 26, 40, '26-40 ans',
        4, 41, 60, '41-60 ans',
        5, 61, 75, '61-75 ans',
        6, 76, 999, '76 ans et plus'
    ) AS (id_tranche_age, age_min, age_max, libelle_tranche)
    FROM (SELECT COUNT(*) AS n FROM silver.specialite) une_ligne
) t;

-- Calendrier du 01/01/1970 au 31/12/2023, soit 19 723 jours. La clé vaut AAAAMMJJ.
-- space(n) écrit n espaces, split les découpe en n + 1 morceaux et posexplode numérote ces morceaux de 0 à n.
INSERT INTO TABLE gold.dim_temps
SELECT CAST(regexp_replace(c.date_jour, '-', '') AS INT),
       c.date_jour,
       day(c.date_jour),
       month(c.date_jour),
       CASE month(c.date_jour)
           WHEN 1 THEN 'Janvier' WHEN 2 THEN 'Février' WHEN 3 THEN 'Mars' WHEN 4 THEN 'Avril'
           WHEN 5 THEN 'Mai' WHEN 6 THEN 'Juin' WHEN 7 THEN 'Juillet' WHEN 8 THEN 'Août'
           WHEN 9 THEN 'Septembre' WHEN 10 THEN 'Octobre' WHEN 11 THEN 'Novembre' WHEN 12 THEN 'Décembre'
       END,
       CAST(ceil(month(c.date_jour) / 3) AS INT),
       weekofyear(c.date_jour),
       year(c.date_jour),
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'calendrier généré'
FROM (
    SELECT date_add('1970-01-01', j.rang) AS date_jour
    FROM (SELECT COUNT(*) AS n FROM silver.specialite) une_ligne
    LATERAL VIEW posexplode(split(space(datediff('2023-12-31', '1970-01-01')), ' ')) j AS rang, vide
) c;

-- Régions : les 18 régions, plus l'étranger (ETR) et l'outre-mer hors région (COM). INC est le membre -1.
-- Le code 20 de la Corse donne une seconde ligne pour la région 94, d'où le GROUP BY.
INSERT INTO TABLE gold.dim_region
SELECT ROW_NUMBER() OVER (ORDER BY g.code_region) AS id_region, g.code_region, g.libelle_region,
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'silver.geographie'
FROM (
    SELECT code_region, MAX(libelle_region) AS libelle_region
    FROM silver.geographie
    WHERE code_region <> 'INC'
    GROUP BY code_region
) g;

-- Établissements. J11 garantit déjà un identifiant_organisation unique.
-- Le libellé de la région est lu dans dim_region, écrite juste au-dessus avec une seule ligne par code :
-- la jointure ne peut donc pas dupliquer un établissement. Un code absent de dim_region donne « Inconnu ».
INSERT INTO TABLE gold.dim_etablissement
SELECT ROW_NUMBER() OVER (ORDER BY e.identifiant_organisation) AS id_etablissement, e.identifiant_organisation,
       COALESCE(e.raison_sociale, 'inconnue'), e.code_region, COALESCE(r.libelle_region, 'Inconnu'),
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'silver.etablissement'
FROM silver.etablissement e
LEFT JOIN gold.dim_region r ON e.code_region = r.code_region;

-- Diagnostics (CIM-10).
INSERT INTO TABLE gold.dim_diagnostic
SELECT ROW_NUMBER() OVER (ORDER BY code_diag) AS id_diagnostic, code_diag, libelle_diagnostic,
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'silver.diagnostic'
FROM silver.diagnostic;

-- Patients. Sexe inconnu : I.
INSERT INTO TABLE gold.dim_patient
SELECT ROW_NUMBER() OVER (ORDER BY id_patient_pseudo) AS id_patient, id_patient_pseudo, COALESCE(sexe, 'I'),
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'silver.patient'
FROM silver.patient;

-- Professionnels. J13 a déjà recopié le libellé de la spécialité.
INSERT INTO TABLE gold.dim_professionnel
SELECT ROW_NUMBER() OVER (ORDER BY identifiant) AS id_professionnel, identifiant, COALESCE(specialite, 'inconnu'),
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'silver.professionnel'
FROM silver.professionnel;

-- Audit (R17). lues = lignes attendues, ecrites = lignes de la dimension membre -1 compris,
-- cles = clés métier distinctes, inconnus = lignes à -1.
INSERT INTO TABLE gold.audit
SELECT '${hivevar:id_execution}', 'J21', t.table_cible, '${hivevar:debut}', from_unixtime(unix_timestamp()),
       IF(t.ecrites = t.lues + 1 AND t.cles = t.ecrites AND t.inconnus = 1, 'OK', 'ECHEC'),
       t.lues, t.ecrites, '${hivevar:date_chargement}'
FROM (
    SELECT 'dim_tranche_age' AS table_cible, 6L AS lues, e.n AS ecrites, e.u AS cles, e.m AS inconnus
    FROM (SELECT COUNT(*) AS n, COUNT(DISTINCT libelle_tranche) AS u, SUM(IF(id_tranche_age = -1, 1, 0)) AS m
          FROM gold.dim_tranche_age) e
    UNION ALL
    SELECT 'dim_temps' AS table_cible, 19723L AS lues, e.n AS ecrites, e.u AS cles, e.m AS inconnus
    FROM (SELECT COUNT(*) AS n, COUNT(DISTINCT date_jour) AS u, SUM(IF(id_temps = -1, 1, 0)) AS m
          FROM gold.dim_temps) e
    UNION ALL
    SELECT 'dim_region' AS table_cible, l.n AS lues, e.n AS ecrites, e.u AS cles, e.m AS inconnus
    FROM (SELECT COUNT(DISTINCT code_region) AS n FROM silver.geographie WHERE code_region <> 'INC') l
    CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT code_region) AS u, SUM(IF(id_region = -1, 1, 0)) AS m
                FROM gold.dim_region) e
    UNION ALL
    SELECT 'dim_etablissement' AS table_cible, l.n AS lues, e.n AS ecrites, e.u AS cles, e.m AS inconnus
    FROM (SELECT COUNT(*) AS n FROM silver.etablissement) l
    CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT identifiant_organisation) AS u, SUM(IF(id_etablissement = -1, 1, 0)) AS m
                FROM gold.dim_etablissement) e
    UNION ALL
    SELECT 'dim_diagnostic' AS table_cible, l.n AS lues, e.n AS ecrites, e.u AS cles, e.m AS inconnus
    FROM (SELECT COUNT(*) AS n FROM silver.diagnostic) l
    CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT code_diag) AS u, SUM(IF(id_diagnostic = -1, 1, 0)) AS m
                FROM gold.dim_diagnostic) e
    UNION ALL
    SELECT 'dim_patient' AS table_cible, l.n AS lues, e.n AS ecrites, e.u AS cles, e.m AS inconnus
    FROM (SELECT COUNT(*) AS n FROM silver.patient) l
    CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT patient_pseudo) AS u, SUM(IF(id_patient = -1, 1, 0)) AS m
                FROM gold.dim_patient) e
    UNION ALL
    SELECT 'dim_professionnel' AS table_cible, l.n AS lues, e.n AS ecrites, e.u AS cles, e.m AS inconnus
    FROM (SELECT COUNT(*) AS n FROM silver.professionnel) l
    CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT code_professionnel) AS u, SUM(IF(id_professionnel = -1, 1, 0)) AS m
                FROM gold.dim_professionnel) e
) t;

-- Échec du job si une ligne manque, si une clé métier est en double ou si le membre -1 manque (R18).
SELECT assert_true(statut = 'OK')
FROM gold.audit
WHERE id_execution = '${hivevar:id_execution}' AND job = 'J21';
