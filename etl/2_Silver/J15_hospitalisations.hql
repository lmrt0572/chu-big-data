-- J15 Hospitalisations : date d'entrée, contrôle des liens.
-- Règles : R05, R08, R17, R18. Rejet : date d'entrée illisible (aucune au profilage).
-- Contrôle de fin : patient, diagnostic et établissement retrouvés pour chaque séjour.
-- Dépend de J11, J12.
-- Paramètres : load_date, id_execution, debut, seuil_rejet (voir lancer_silver.sh).

SET hive.auto.convert.join=false;
SET parquet.compression=SNAPPY;
-- Les conteneurs MapReduce de la VM n'ont que 128 Mo par défaut, trop peu pour écrire du Parquet.
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;

-- R05. La date dd/MM/yyyy est réécrite en yyyy-MM-dd, puis relue pour écarter les dates impossibles.
-- R08. Patient, établissement et diagnostic ne sont gardés que s'ils existent dans Silver.
FROM (
    SELECT num_hospitalisation, id_patient_pseudo, identifiant_organisation, code_diagnostic,
           date_entree, jour_hospitalisation, date_iso,
           COALESCE(from_unixtime(unix_timestamp(date_iso, 'yyyy-MM-dd'), 'yyyy-MM-dd') = date_iso, false) AS date_valide
    FROM (
        SELECT trim(num_hospitalisation) AS num_hospitalisation,
               trim(id_patient_pseudo) AS id_patient_pseudo,
               trim(identifiant_organisation) AS identifiant_organisation,
               upper(trim(code_diagnostic)) AS code_diagnostic,
               date_entree,
               jour_hospitalisation,
               concat(regexp_extract(trim(date_entree), '^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$', 3), '-',
                      lpad(regexp_extract(trim(date_entree), '^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$', 2), 2, '0'), '-',
                      lpad(regexp_extract(trim(date_entree), '^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$', 1), 2, '0')) AS date_iso
        FROM bronze.sejour
        WHERE load_date = '${hiveconf:load_date}'
    ) b
) s
LEFT JOIN silver.patient pa ON s.id_patient_pseudo = pa.id_patient_pseudo
LEFT JOIN silver.etablissement e ON s.identifiant_organisation = e.identifiant_organisation
LEFT JOIN silver.diagnostic d ON s.code_diagnostic = d.code_diag
INSERT OVERWRITE TABLE silver.hospitalisation
SELECT s.num_hospitalisation,
       pa.id_patient_pseudo,
       e.identifiant_organisation,
       d.code_diag,
       s.date_iso,
       CAST(trim(s.jour_hospitalisation) AS INT),
       '${hiveconf:id_execution}', '${hiveconf:load_date}', 'Hospitalisations.csv'
WHERE s.date_valide
INSERT OVERWRITE TABLE silver.rejet PARTITION (job = 'J15')
SELECT '${hiveconf:id_execution}', 'Hospitalisations.csv',
       concat_ws('\073', s.num_hospitalisation, s.id_patient_pseudo, s.identifiant_organisation,
                 s.code_diagnostic, s.date_entree, s.jour_hospitalisation),
       'R05', "date d'entree illisible", '${hiveconf:load_date}'
WHERE NOT s.date_valide;

-- Audit. Un lien absent ne bloque pas la ligne (R08), mais le job échoue au-delà du seuil (R18).
INSERT INTO TABLE silver.audit
SELECT '${hiveconf:id_execution}', 'J15', 'hospitalisation', '${hiveconf:debut}', from_unixtime(unix_timestamp()),
       IF(r.n <= ${hiveconf:seuil_rejet} * l.n AND e.sans_lien <= ${hiveconf:seuil_rejet} * l.n
          AND l.n = e.n + r.n AND e.u = e.n, 'OK', 'ECHEC'),
       l.n, e.n, r.n, 0L, '${hiveconf:load_date}'
FROM (SELECT COUNT(*) AS n FROM bronze.sejour WHERE load_date = '${hiveconf:load_date}') l
CROSS JOIN (
    SELECT COUNT(*) AS n, COUNT(DISTINCT num_hospitalisation) AS u,
           SUM(IF(id_patient_pseudo IS NULL OR identifiant_organisation IS NULL OR code_diag IS NULL, 1, 0)) AS sans_lien
    FROM silver.hospitalisation
) e
CROSS JOIN (SELECT COUNT(*) AS n FROM silver.rejet WHERE job = 'J15') r;

SELECT assert_true(statut = 'OK')
FROM silver.audit
WHERE id_execution = '${hiveconf:id_execution}' AND job = 'J15';

-- Contrôle de fin affiché : séjours sans patient, sans établissement, sans diagnostic (0 au profilage).
SELECT 'J15 liens absents', SUM(IF(id_patient_pseudo IS NULL, 1, 0)),
       SUM(IF(identifiant_organisation IS NULL, 1, 0)), SUM(IF(code_diag IS NULL, 1, 0))
FROM silver.hospitalisation;
