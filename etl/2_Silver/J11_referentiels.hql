-- J11 Référentiels : géographie, établissements, diagnostics, spécialités.
-- Règles : R14, R15, R17, R18. Aucun rejet, un établissement sans région est classé INC (inconnu).
-- Contrôle de fin : identifiant_organisation unique.
-- Paramètres : load_date, id_execution, debut (voir lancer_silver.sh).

-- Sur la VM, la tâche locale qui charge une table en mémoire échoue même pour une petite table.
SET hive.auto.convert.join=false;
SET parquet.compression=SNAPPY;
-- Les conteneurs MapReduce de la VM n'ont que 128 Mo par défaut, trop peu pour écrire du Parquet.
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;

-- Géographie. Une ligne par code de département, plus les catégories hors région (R14) :
-- ancien code 20 de la Corse (R15), collectivités d'outre-mer (COM), étranger (ETR), inconnu (INC).
INSERT OVERWRITE TABLE silver.geographie
SELECT code_departement, libelle_departement, code_region, libelle_region, categorie,
       '${hiveconf:id_execution}', '${hiveconf:load_date}', source
FROM (
    SELECT d.dep AS code_departement, d.libelle AS libelle_departement,
           r.reg AS code_region, r.libelle AS libelle_region,
           'REGION' AS categorie, 'COG INSEE 2025' AS source
    FROM bronze.insee_departement d
    JOIN bronze.insee_region r ON d.reg = r.reg AND r.load_date = d.load_date
    WHERE d.load_date = '${hiveconf:load_date}'
    UNION ALL
    SELECT '20' AS code_departement, 'Corse (code antérieur à 1976)' AS libelle_departement,
           r.reg AS code_region, r.libelle AS libelle_region, 'REGION' AS categorie, 'R15' AS source
    FROM bronze.insee_region r
    WHERE r.load_date = '${hiveconf:load_date}' AND r.reg = '94'
    UNION ALL
    SELECT c.code_departement, c.libelle_departement, 'COM' AS code_region, 'Outre-mer hors région' AS libelle_region,
           'OUTRE_MER_HORS_REGION' AS categorie, 'R14' AS source
    FROM (
        SELECT stack(8,
            '975', 'Saint-Pierre-et-Miquelon',
            '977', 'Saint-Barthélemy',
            '978', 'Saint-Martin',
            '984', 'Terres australes et antarctiques françaises',
            '986', 'Wallis-et-Futuna',
            '987', 'Polynésie française',
            '988', 'Nouvelle-Calédonie',
            '989', 'Île de Clipperton'
        ) AS (code_departement, libelle_departement)
        FROM bronze.insee_region
        WHERE load_date = '${hiveconf:load_date}' AND reg = '94'
    ) c
    UNION ALL
    SELECT '99' AS code_departement, 'Étranger' AS libelle_departement, 'ETR' AS code_region,
           'Étranger' AS libelle_region, 'ETRANGER' AS categorie, 'R14' AS source
    FROM bronze.insee_region
    WHERE load_date = '${hiveconf:load_date}' AND reg = '94'
    UNION ALL
    SELECT CAST(NULL AS STRING) AS code_departement, 'Inconnu' AS libelle_departement, 'INC' AS code_region,
           'Inconnu' AS libelle_region, 'INCONNU' AS categorie, 'R15' AS source
    FROM bronze.insee_region
    WHERE load_date = '${hiveconf:load_date}' AND reg = '94'
) g;

-- Établissements. Département lu dans le code commune (3 caractères outre-mer), sinon dans le code postal (R15).
-- Un code postal de 4 chiffres a perdu son zéro de tête lors d'un passage par Excel, il est complété.
-- Un code postal 20xxx donne l'ancien département 20, donc la Corse.
INSERT OVERWRITE TABLE silver.etablissement
SELECT e.identifiant_organisation,
       e.raison_sociale,
       e.finess_juridique,
       e.code_commune,
       e.commune,
       e.code_postal,
       COALESCE(gc.code_departement, gp.code_departement),
       COALESCE(gc.code_region, gp.code_region, 'INC'),
       CASE WHEN gc.code_region IS NOT NULL THEN 'CODE_COMMUNE'
            WHEN gp.code_region IS NOT NULL THEN 'CODE_POSTAL'
            ELSE 'AUCUNE' END,
       '${hiveconf:id_execution}',
       '${hiveconf:load_date}',
       'etablissement_sante.csv'
FROM (
    SELECT identifiant_organisation, raison_sociale, finess_juridique, code_commune, commune, code_postal,
           CASE WHEN code_commune RLIKE '^9[78]' THEN substr(code_commune, 1, 3)
                WHEN code_commune IS NOT NULL THEN substr(code_commune, 1, 2) END AS dep_commune,
           CASE WHEN code_postal RLIKE '^9[78][0-9]{3}$' THEN substr(code_postal, 1, 3)
                WHEN code_postal RLIKE '^[0-9]{5}$' THEN substr(code_postal, 1, 2) END AS dep_postal
    FROM (
        SELECT trim(identifiant_organisation) AS identifiant_organisation,
               IF(trim(raison_sociale_site) = '', NULL, trim(raison_sociale_site)) AS raison_sociale,
               IF(trim(finess_etablissement_juridique) = '', NULL, trim(finess_etablissement_juridique)) AS finess_juridique,
               IF(trim(code_commune) = '', NULL, upper(trim(code_commune))) AS code_commune,
               IF(trim(commune) = '', NULL, trim(commune)) AS commune,
               CASE WHEN trim(code_postal) = '' THEN NULL
                    WHEN trim(code_postal) RLIKE '^[0-9]{4}$' THEN concat('0', trim(code_postal))
                    ELSE trim(code_postal) END AS code_postal
        FROM bronze.etablissement
        WHERE load_date = '${hiveconf:load_date}'
    ) b
) e
LEFT JOIN silver.geographie gc ON e.dep_commune = gc.code_departement
LEFT JOIN silver.geographie gp ON e.dep_postal = gp.code_departement;

-- Diagnostics (CIM-10).
INSERT OVERWRITE TABLE silver.diagnostic
SELECT upper(trim(code_diag)), trim(diagnostic),
       '${hiveconf:id_execution}', '${hiveconf:load_date}', 'PG DATA2023.Diagnostic'
FROM bronze.diagnostic
WHERE load_date = '${hiveconf:load_date}';

-- Spécialités.
INSERT OVERWRITE TABLE silver.specialite
SELECT trim(code_specialite), trim(specialite),
       '${hiveconf:id_execution}', '${hiveconf:load_date}', 'PG DATA2023.Specialites'
FROM bronze.specialite
WHERE load_date = '${hiveconf:load_date}';

-- Audit. Aucun rejet dans ce job, donc chaque table doit compter autant de lignes que sa source.
INSERT INTO TABLE silver.audit
SELECT '${hiveconf:id_execution}', 'J11', t.table_cible, '${hiveconf:debut}', from_unixtime(unix_timestamp()),
       IF(t.lues = t.ecrites AND t.uniques = t.ecrites, 'OK', 'ECHEC'),
       t.lues, t.ecrites, 0L, 0L, '${hiveconf:load_date}'
FROM (
    SELECT 'etablissement' AS table_cible, l.n AS lues, e.n AS ecrites, e.u AS uniques
    FROM (SELECT COUNT(*) AS n FROM bronze.etablissement WHERE load_date = '${hiveconf:load_date}') l
    CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT identifiant_organisation) AS u FROM silver.etablissement) e
    UNION ALL
    SELECT 'diagnostic' AS table_cible, l.n AS lues, e.n AS ecrites, e.u AS uniques
    FROM (SELECT COUNT(*) AS n FROM bronze.diagnostic WHERE load_date = '${hiveconf:load_date}') l
    CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT code_diag) AS u FROM silver.diagnostic) e
    UNION ALL
    SELECT 'specialite' AS table_cible, l.n AS lues, e.n AS ecrites, e.u AS uniques
    FROM (SELECT COUNT(*) AS n FROM bronze.specialite WHERE load_date = '${hiveconf:load_date}') l
    CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT code_specialite) AS u FROM silver.specialite) e
) t;

-- Échec du job si une clé est en double ou si une ligne a été perdue (R18).
SELECT assert_true(statut = 'OK')
FROM silver.audit
WHERE id_execution = '${hiveconf:id_execution}' AND job = 'J11';
