-- J22 Faits : consultations, hospitalisations, décès et satisfaction, reliés aux dimensions de J21.
-- Règles : R06, R08, R17, R18.
-- Contrôle de fin : chaque table de faits a autant de lignes que sa table Silver, et aucune clé étrangère vide.
-- Dépend de J21 et de J12 à J17.
-- Paramètres : date_chargement, id_execution, debut (voir lancer_gold.sh).

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
SET hive.exec.max.dynamic.partitions=1000;
SET hive.exec.max.dynamic.partitions.pernode=1000;
-- Trie par année avant l'écriture, pour qu'un reducer n'ait qu'un fichier Parquet ouvert à la fois.
SET hive.optimize.sort.dynamic.partition=true;

-- R06. Âge en années révolues à la date de l'événement, calculé comme dans J16, puis classé dans les tranches de J21.
-- Un événement antérieur à la naissance donne un âge négatif, donc la tranche -1 (les 62 séjours de l'anomalie A17).
-- R08. Un lien absent prend le membre -1 de la dimension.

-- Consultations. Grain : une consultation.
INSERT OVERWRITE TABLE gold.fait_consultation
SELECT ROW_NUMBER() OVER (ORDER BY f.num_consultation) AS id_consultation,
       f.num_consultation,
       1,
       CASE WHEN f.age IS NULL OR f.age < 0 THEN -1
            WHEN f.age <= 17 THEN 1
            WHEN f.age <= 25 THEN 2
            WHEN f.age <= 40 THEN 3
            WHEN f.age <= 60 THEN 4
            WHEN f.age <= 75 THEN 5
            ELSE 6 END,
       f.id_diagnostic, f.id_etablissement, f.id_professionnel, f.id_patient, f.id_temps,
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'silver.consultation'
FROM (
    SELECT c.num_consultation,
           IF(p.date_naissance IS NULL OR c.date_consultation IS NULL, NULL,
              CAST(substr(c.date_consultation, 1, 4) AS INT) - CAST(substr(p.date_naissance, 1, 4) AS INT)
              - IF(substr(c.date_consultation, 6, 5) < substr(p.date_naissance, 6, 5), 1, 0)) AS age,
           COALESCE(dd.id_diagnostic, -1) AS id_diagnostic,
           COALESCE(de.id_etablissement, -1) AS id_etablissement,
           COALESCE(dpr.id_professionnel, -1) AS id_professionnel,
           COALESCE(dp.id_patient, -1) AS id_patient,
           COALESCE(dt.id_temps, -1) AS id_temps
    FROM silver.consultation c
    LEFT JOIN silver.patient p ON c.id_patient_pseudo = p.id_patient_pseudo
    LEFT JOIN gold.dim_patient dp ON c.id_patient_pseudo = dp.patient_pseudo
    LEFT JOIN gold.dim_diagnostic dd ON c.code_diag = dd.code_diag
    LEFT JOIN gold.dim_professionnel dpr ON c.identifiant_professionnel = dpr.code_professionnel
    LEFT JOIN gold.dim_etablissement de ON c.identifiant_organisation = de.identifiant_organisation
    LEFT JOIN gold.dim_temps dt ON c.date_consultation = dt.date_jour
) f;

-- Hospitalisations. Grain : un séjour, daté par son entrée.
INSERT OVERWRITE TABLE gold.fait_hospitalisation
SELECT ROW_NUMBER() OVER (ORDER BY f.num_hospitalisation) AS id_hospitalisation,
       f.num_hospitalisation,
       1,
       f.id_etablissement,
       CASE WHEN f.age IS NULL OR f.age < 0 THEN -1
            WHEN f.age <= 17 THEN 1
            WHEN f.age <= 25 THEN 2
            WHEN f.age <= 40 THEN 3
            WHEN f.age <= 60 THEN 4
            WHEN f.age <= 75 THEN 5
            ELSE 6 END,
       f.id_diagnostic, f.id_patient, f.id_temps,
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'silver.hospitalisation'
FROM (
    SELECT h.num_hospitalisation,
           IF(p.date_naissance IS NULL OR h.date_entree IS NULL, NULL,
              CAST(substr(h.date_entree, 1, 4) AS INT) - CAST(substr(p.date_naissance, 1, 4) AS INT)
              - IF(substr(h.date_entree, 6, 5) < substr(p.date_naissance, 6, 5), 1, 0)) AS age,
           COALESCE(de.id_etablissement, -1) AS id_etablissement,
           COALESCE(dd.id_diagnostic, -1) AS id_diagnostic,
           COALESCE(dp.id_patient, -1) AS id_patient,
           COALESCE(dt.id_temps, -1) AS id_temps
    FROM silver.hospitalisation h
    LEFT JOIN silver.patient p ON h.id_patient_pseudo = p.id_patient_pseudo
    LEFT JOIN gold.dim_patient dp ON h.id_patient_pseudo = dp.patient_pseudo
    LEFT JOIN gold.dim_etablissement de ON h.identifiant_organisation = de.identifiant_organisation
    LEFT JOIN gold.dim_diagnostic dd ON h.code_diag = dd.code_diag
    LEFT JOIN gold.dim_temps dt ON h.date_entree = dt.date_jour
) f;

-- Décès. Grain : un décès, partitionné par année comme silver.deces.
-- id_deces = année x 1 000 000 + rang du décès dans son année : la clé est unique sans trier les 25 millions de lignes d'un bloc.
-- Le code région INC de Silver tombe sur le membre -1 de dim_region.
INSERT OVERWRITE TABLE gold.fait_deces PARTITION (annee_deces)
SELECT CAST(f.annee_deces AS BIGINT) * 1000000 + f.rang,
       1,
       f.id_region,
       f.id_temps,
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'silver.deces',
       f.annee_deces
FROM (
    SELECT d.annee_deces,
           ROW_NUMBER() OVER (PARTITION BY d.annee_deces ORDER BY d.date_deces, d.empreinte_ligne) AS rang,
           COALESCE(dr.id_region, -1) AS id_region,
           COALESCE(dt.id_temps, -1) AS id_temps
    FROM silver.deces d
    LEFT JOIN gold.dim_region dr ON d.code_region = dr.code_region
    LEFT JOIN gold.dim_temps dt ON d.date_deces = dt.date_jour
) f;

-- Satisfaction. Grain : un résultat e-Satis par établissement et par année, daté au 1er janvier.
INSERT OVERWRITE TABLE gold.fait_satisfaction
SELECT ROW_NUMBER() OVER (ORDER BY f.annee, f.finess_geo) AS id_satisfaction,
       f.nb_avis, f.note_globale, f.id_region, f.id_etablissement, f.id_temps,
       '${hivevar:id_execution}', '${hivevar:date_chargement}', 'silver.satisfaction'
FROM (
    SELECT s.annee, s.finess_geo,
           COALESCE(s.nb_reponses, 0) AS nb_avis,
           s.score_global AS note_globale,
           COALESCE(dr.id_region, -1) AS id_region,
           COALESCE(de.id_etablissement, -1) AS id_etablissement,
           COALESCE(dt.id_temps, -1) AS id_temps
    FROM silver.satisfaction s
    LEFT JOIN gold.dim_etablissement de ON s.identifiant_organisation = de.identifiant_organisation
    LEFT JOIN gold.dim_region dr ON s.code_region = dr.code_region
    LEFT JOIN gold.dim_temps dt ON concat(CAST(s.annee AS STRING), '-01-01') = dt.date_jour
) f;

-- Audit (R17). lues = lignes Silver, ecrites = lignes Gold, vides = lignes avec une clé étrangère NULL.
INSERT INTO TABLE gold.audit
SELECT '${hivevar:id_execution}', 'J22', t.table_cible, '${hivevar:debut}', from_unixtime(unix_timestamp()),
       IF(t.lues = t.ecrites AND t.vides = 0, 'OK', 'ECHEC'),
       t.lues, t.ecrites, '${hivevar:date_chargement}'
FROM (
    SELECT 'fait_consultation' AS table_cible, l.n AS lues, e.n AS ecrites, e.v AS vides
    FROM (SELECT COUNT(*) AS n FROM silver.consultation) l
    CROSS JOIN (SELECT COUNT(*) AS n,
                       COALESCE(SUM(IF(id_tranche_age IS NULL OR id_diagnostic IS NULL OR id_etablissement IS NULL
                                       OR id_professionnel IS NULL OR id_patient IS NULL OR id_temps IS NULL, 1, 0)), 0) AS v
                FROM gold.fait_consultation) e
    UNION ALL
    SELECT 'fait_hospitalisation' AS table_cible, l.n AS lues, e.n AS ecrites, e.v AS vides
    FROM (SELECT COUNT(*) AS n FROM silver.hospitalisation) l
    CROSS JOIN (SELECT COUNT(*) AS n,
                       COALESCE(SUM(IF(id_etablissement IS NULL OR id_tranche_age IS NULL OR id_diagnostic IS NULL
                                       OR id_patient IS NULL OR id_temps_admission IS NULL, 1, 0)), 0) AS v
                FROM gold.fait_hospitalisation) e
    UNION ALL
    SELECT 'fait_deces' AS table_cible, l.n AS lues, e.n AS ecrites, e.v AS vides
    FROM (SELECT COUNT(*) AS n FROM silver.deces) l
    CROSS JOIN (SELECT COUNT(*) AS n,
                       COALESCE(SUM(IF(id_region IS NULL OR id_temps IS NULL, 1, 0)), 0) AS v
                FROM gold.fait_deces) e
    UNION ALL
    SELECT 'fait_satisfaction' AS table_cible, l.n AS lues, e.n AS ecrites, e.v AS vides
    FROM (SELECT COUNT(*) AS n FROM silver.satisfaction) l
    CROSS JOIN (SELECT COUNT(*) AS n,
                       COALESCE(SUM(IF(id_region IS NULL OR id_etablissement IS NULL OR id_temps IS NULL, 1, 0)), 0) AS v
                FROM gold.fait_satisfaction) e
) t;

-- Échec du job si une ligne a été perdue ou dupliquée par une jointure, ou si une clé étrangère est vide (R18).
SELECT assert_true(statut = 'OK')
FROM gold.audit
WHERE id_execution = '${hivevar:id_execution}' AND job = 'J22';
