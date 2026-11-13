-- J14 Consultations : établissement du professionnel, durée, liens contrôlés.
-- Règles : R08, R09, R11, R17, R18. Aucun rejet, un lien absent est laissé vide (inconnu, -1 en Gold).
-- Contrôle de fin : part des consultations rattachées à un établissement (63,9 % au profilage).
-- Dépend de J11, J12, J13.
-- Paramètres : load_date, id_execution, debut (voir lancer_silver.sh).

SET hive.auto.convert.join=false;
SET parquet.compression=SNAPPY;
-- Les conteneurs MapReduce de la VM n'ont que 128 Mo par défaut, trop peu pour écrire du Parquet.
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;

-- R08. Patient, professionnel et diagnostic ne sont gardés que s'ils existent dans Silver.
-- R09. La consultation prend l'établissement retenu pour son professionnel par J13.
-- R11. Durée = fin moins début, plus 24 h si le créneau passe minuit (créneau 20 h à 2 h).
INSERT OVERWRITE TABLE silver.consultation
SELECT c.num_consultation,
       pa.id_patient_pseudo,
       pr.identifiant,
       d.code_diag,
       IF(c.date_valide, c.date_consultation, NULL),
       c.heure_debut,
       c.heure_fin,
       CAST(IF(c.fin_minutes < c.debut_minutes, c.fin_minutes + 1440, c.fin_minutes) - c.debut_minutes AS INT),
       pr.identifiant_organisation,
       '${hiveconf:id_execution}', '${hiveconf:load_date}', 'PG DATA2023.Consultation'
FROM (
    SELECT trim(num_consultation) AS num_consultation,
           trim(id_patient_pseudo) AS id_patient_pseudo,
           IF(trim(id_prof_sante) RLIKE '^[0-9]{8}$', lpad(trim(id_prof_sante), 9, '0'), trim(id_prof_sante)) AS id_prof_sante,
           upper(trim(code_diag)) AS code_diag,
           trim(date_consultation) AS date_consultation,
           COALESCE(from_unixtime(unix_timestamp(trim(date_consultation), 'yyyy-MM-dd'), 'yyyy-MM-dd') = trim(date_consultation), false) AS date_valide,
           trim(heure_debut) AS heure_debut,
           trim(heure_fin) AS heure_fin,
           IF(trim(heure_debut) RLIKE '^[0-9]{2}:[0-9]{2}',
              CAST(substr(trim(heure_debut), 1, 2) AS INT) * 60 + CAST(substr(trim(heure_debut), 4, 2) AS INT), NULL) AS debut_minutes,
           IF(trim(heure_fin) RLIKE '^[0-9]{2}:[0-9]{2}',
              CAST(substr(trim(heure_fin), 1, 2) AS INT) * 60 + CAST(substr(trim(heure_fin), 4, 2) AS INT), NULL) AS fin_minutes
    FROM bronze.consultation
    WHERE load_date = '${hiveconf:load_date}'
) c
LEFT JOIN silver.patient pa ON c.id_patient_pseudo = pa.id_patient_pseudo
LEFT JOIN silver.professionnel pr ON c.id_prof_sante = pr.identifiant
LEFT JOIN silver.diagnostic d ON c.code_diag = d.code_diag;

-- Audit. Aucun rejet, donc autant de lignes qu'en Bronze et des numéros uniques.
INSERT INTO TABLE silver.audit
SELECT '${hiveconf:id_execution}', 'J14', 'consultation', '${hiveconf:debut}', from_unixtime(unix_timestamp()),
       IF(l.n = e.n AND e.u = e.n, 'OK', 'ECHEC'),
       l.n, e.n, 0L, 0L, '${hiveconf:load_date}'
FROM (SELECT COUNT(*) AS n FROM bronze.consultation WHERE load_date = '${hiveconf:load_date}') l
CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT num_consultation) AS u FROM silver.consultation) e;

SELECT assert_true(statut = 'OK')
FROM silver.audit
WHERE id_execution = '${hiveconf:id_execution}' AND job = 'J14';

-- Contrôle de fin affiché : part rattachée à un établissement.
SELECT 'J14 part rattachee', ROUND(100 * SUM(IF(identifiant_organisation IS NOT NULL, 1, 0)) / COUNT(*), 2)
FROM silver.consultation;
