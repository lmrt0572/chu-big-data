-- J12 Patients : date de naissance et sexe.
-- Règles : R05, R07, R17, R18. Rejet : date de naissance illisible.
-- Contrôle de fin : un seul pseudonyme par patient.
-- Paramètres : load_date, id_execution, debut, seuil_rejet (voir lancer_silver.sh).

SET hive.auto.convert.join=false;
SET parquet.compression=SNAPPY;
-- Les conteneurs MapReduce de la VM n'ont que 128 Mo par défaut, trop peu pour écrire du Parquet.
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;

-- R05. La date M/D/YYYY est réécrite en yyyy-MM-dd, puis relue. Le lecteur de dates de Hive est permissif
-- (le 2/30/1950 deviendrait le 2 mars), donc une date n'est valide que si la relecture redonne le même texte.
-- R07. male et female deviennent M et F.
FROM (
    SELECT id_patient_pseudo, sexe, date_naissance, doublon_probable, date_iso,
           COALESCE(from_unixtime(unix_timestamp(date_iso, 'yyyy-MM-dd'), 'yyyy-MM-dd') = date_iso, false) AS date_valide
    FROM (
        SELECT id_patient_pseudo, sexe, date_naissance, doublon_probable,
               concat(regexp_extract(trim(date_naissance), '^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$', 3), '-',
                      lpad(regexp_extract(trim(date_naissance), '^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$', 1), 2, '0'), '-',
                      lpad(regexp_extract(trim(date_naissance), '^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$', 2), 2, '0')) AS date_iso
        FROM bronze.patient
        WHERE load_date = '${hiveconf:load_date}'
    ) b
) p
INSERT OVERWRITE TABLE silver.patient
SELECT id_patient_pseudo,
       CASE lower(trim(sexe)) WHEN 'female' THEN 'F' WHEN 'male' THEN 'M' END,
       date_iso,
       CAST(substr(date_iso, 1, 4) AS INT),
       trim(doublon_probable) = '1',
       '${hiveconf:id_execution}', '${hiveconf:load_date}', 'PG DATA2023.Patient'
WHERE date_valide
INSERT OVERWRITE TABLE silver.rejet PARTITION (job = 'J12')
SELECT '${hiveconf:id_execution}', 'PG DATA2023.Patient',
       concat_ws('\073', id_patient_pseudo, sexe, date_naissance, doublon_probable),
       'R05', 'date de naissance illisible', '${hiveconf:load_date}'
WHERE NOT date_valide;

INSERT INTO TABLE silver.audit
SELECT '${hiveconf:id_execution}', 'J12', 'patient', '${hiveconf:debut}', from_unixtime(unix_timestamp()),
       IF(r.n <= ${hiveconf:seuil_rejet} * l.n AND e.u = e.n AND l.n = e.n + r.n, 'OK', 'ECHEC'),
       l.n, e.n, r.n, 0L, '${hiveconf:load_date}'
FROM (SELECT COUNT(*) AS n FROM bronze.patient WHERE load_date = '${hiveconf:load_date}') l
CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT id_patient_pseudo) AS u FROM silver.patient) e
CROSS JOIN (SELECT COUNT(*) AS n FROM silver.rejet WHERE job = 'J12') r;

-- Échec du job si plus de seuil_rejet de rejets ou si un pseudonyme est en double (R18).
SELECT assert_true(statut = 'OK')
FROM silver.audit
WHERE id_execution = '${hiveconf:id_execution}' AND job = 'J12';
