-- Vérification de la couche Silver (voir README_Silver.md).
-- Chaque ligne compare une valeur mesurée à la valeur attendue, puis affiche OK ou ECART.
-- Une ligne sans valeur attendue est une information pour le rapport qualité, elle affiche INFO.
-- Les valeurs attendues viennent du profilage du 25/10/2026 et de verifier_bronze.hql, pour la partition 2026-10-30.
-- Les contrôles des décès supposent un seul chargement.
-- Hive 1.1 exige les mêmes noms de colonnes dans chaque branche d'un UNION ALL, d'où les alias répétés.

SET hive.auto.convert.join=false;
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;

SELECT controle, mesure, attendu, IF(attendu IS NULL, 'INFO', IF(mesure = attendu, 'OK', 'ECART')) AS statut
FROM (
-- Référentiels (J11)
    SELECT 'lignes geographie' AS controle, CAST(COUNT(*) AS STRING) AS mesure, '112' AS attendu FROM silver.geographie
    UNION ALL
    SELECT 'lignes etablissement' AS controle, CAST(COUNT(*) AS STRING) AS mesure, '416665' AS attendu FROM silver.etablissement
    UNION ALL
    SELECT 'etablissements en double' AS controle, CAST(COUNT(*) - COUNT(DISTINCT identifiant_organisation) AS STRING) AS mesure,
           '0' AS attendu
    FROM silver.etablissement
    UNION ALL
    SELECT concat('etablissements region par ', origine_region) AS controle, CAST(COUNT(*) AS STRING) AS mesure,
           CAST(NULL AS STRING) AS attendu
    FROM silver.etablissement GROUP BY origine_region
    UNION ALL
    SELECT 'lignes diagnostic' AS controle, CAST(COUNT(*) AS STRING) AS mesure, '15490' AS attendu FROM silver.diagnostic
    UNION ALL
    SELECT 'lignes specialite' AS controle, CAST(COUNT(*) AS STRING) AS mesure, '93' AS attendu FROM silver.specialite
-- Patients (J12)
    UNION ALL
    SELECT 'lignes patient' AS controle, CAST(COUNT(*) AS STRING) AS mesure, '100000' AS attendu FROM silver.patient
    UNION ALL
    SELECT 'patients en double' AS controle, CAST(COUNT(*) - COUNT(DISTINCT id_patient_pseudo) AS STRING) AS mesure, '0' AS attendu
    FROM silver.patient
    UNION ALL
    SELECT 'patients F' AS controle, CAST(SUM(IF(sexe = 'F', 1, 0)) AS STRING) AS mesure, '59219' AS attendu FROM silver.patient
    UNION ALL
    SELECT 'patients M' AS controle, CAST(SUM(IF(sexe = 'M', 1, 0)) AS STRING) AS mesure, '40781' AS attendu FROM silver.patient
    UNION ALL
    SELECT 'patients marques doublons' AS controle, CAST(SUM(IF(doublon_probable, 1, 0)) AS STRING) AS mesure, '2' AS attendu
    FROM silver.patient
    UNION ALL
    SELECT 'rejets J12' AS controle, CAST(COUNT(*) AS STRING) AS mesure, '0' AS attendu FROM silver.rejet WHERE job = 'J12'
-- Professionnels (J13)
    UNION ALL
    SELECT 'lignes professionnel' AS controle, CAST(COUNT(*) AS STRING) AS mesure, '1048575' AS attendu FROM silver.professionnel
    UNION ALL
    SELECT 'professionnels en double' AS controle, CAST(COUNT(*) - COUNT(DISTINCT identifiant) AS STRING) AS mesure, '0' AS attendu
    FROM silver.professionnel
    UNION ALL
-- Un ADELI peut contenir des lettres (2A0000014, 97A101902). Les 2 attendus sont 9,00E+34 et 9,00E+42,
-- abîmés par Excel dans la source et impossibles à corriger (comme A09).
    SELECT 'ADELI pas a 9 caracteres' AS controle,
           CAST(SUM(IF(type_identifiant = 'ADELI' AND NOT identifiant RLIKE '^[0-9A-Z]{9}$', 1, 0)) AS STRING) AS mesure, '2' AS attendu
    FROM silver.professionnel
    UNION ALL
-- Le seul attendu est le code BM0801 option biologie generale, absent des spécialités, rattaché à inconnu (R08).
    SELECT 'professionnels sans specialite' AS controle, CAST(SUM(IF(code_specialite IS NULL, 1, 0)) AS STRING) AS mesure,
           '1' AS attendu
    FROM silver.professionnel
    UNION ALL
    SELECT concat('professionnels ', attribution) AS controle, CAST(COUNT(*) AS STRING) AS mesure, CAST(NULL AS STRING) AS attendu
    FROM silver.professionnel GROUP BY attribution
-- Consultations (J14)
    UNION ALL
    SELECT 'lignes consultation' AS controle, CAST(COUNT(*) AS STRING) AS mesure, '1027157' AS attendu FROM silver.consultation
    UNION ALL
    SELECT 'consultations sans patient, professionnel ou diagnostic' AS controle,
           CAST(SUM(IF(id_patient_pseudo IS NULL OR identifiant_professionnel IS NULL OR code_diag IS NULL, 1, 0)) AS STRING) AS mesure,
           '0' AS attendu
    FROM silver.consultation
    UNION ALL
    SELECT 'consultations sans date' AS controle, CAST(SUM(IF(date_consultation IS NULL, 1, 0)) AS STRING) AS mesure, '0' AS attendu
    FROM silver.consultation
    UNION ALL
    SELECT 'consultations passant minuit (R11)' AS controle, CAST(SUM(IF(heure_fin < heure_debut, 1, 0)) AS STRING) AS mesure,
           '10' AS attendu
    FROM silver.consultation
    UNION ALL
    SELECT 'consultations de duree nulle, negative ou absente' AS controle,
           CAST(SUM(IF(duree_minutes <= 0 OR duree_minutes IS NULL, 1, 0)) AS STRING) AS mesure, '0' AS attendu
    FROM silver.consultation
    UNION ALL
    SELECT 'professionnels distincts en consultation' AS controle, CAST(COUNT(DISTINCT identifiant_professionnel) AS STRING) AS mesure,
           '201735' AS attendu
    FROM silver.consultation
    UNION ALL
    SELECT 'part des consultations rattachees (B1)' AS controle,
           CAST(ROUND(100 * SUM(IF(identifiant_organisation IS NOT NULL, 1, 0)) / COUNT(*), 1) AS STRING) AS mesure, '63.9' AS attendu
    FROM silver.consultation
    UNION ALL
    SELECT concat('consultations ', a.annee) AS controle, CAST(COALESCE(m.n, 0L) AS STRING) AS mesure, a.attendu AS attendu
    FROM (
        SELECT stack(9, '2015', '33896', '2016', '184308', '2017', '133403', '2018', '160373', '2019', '87497',
                        '2020', '162778', '2021', '145883', '2022', '101991', '2023', '17028') AS (annee, attendu)
        FROM silver.geographie WHERE categorie = 'INCONNU'
    ) a
    LEFT JOIN (
        SELECT substr(date_consultation, 1, 4) AS annee, COUNT(*) AS n
        FROM silver.consultation GROUP BY substr(date_consultation, 1, 4)
    ) m ON a.annee = m.annee
    UNION ALL
    SELECT concat('part des consultations, professionnel ', a.attribution) AS controle,
           CAST(ROUND(100 * a.n / t.n, 2) AS STRING) AS mesure, x.attendu AS attendu
    FROM (
        SELECT p.attribution, COUNT(*) AS n
        FROM silver.consultation c JOIN silver.professionnel p ON c.identifiant_professionnel = p.identifiant
        GROUP BY p.attribution
    ) a
    CROSS JOIN (SELECT COUNT(*) AS n FROM silver.consultation) t
    LEFT JOIN (
        SELECT stack(4, 'UNIQUE', '46.11', 'PRIORITE', '17.77', 'SANS_ORGANISATION', '8.0', 'ABSENT_ACTIVITE', '28.13')
               AS (attribution, attendu)
        FROM silver.geographie WHERE categorie = 'INCONNU'
    ) x ON a.attribution = x.attribution
-- Hospitalisations (J15)
    UNION ALL
    SELECT 'lignes hospitalisation' AS controle, CAST(COUNT(*) AS STRING) AS mesure, '2479' AS attendu FROM silver.hospitalisation
    UNION ALL
    SELECT 'sejours en double' AS controle, CAST(COUNT(*) - COUNT(DISTINCT num_hospitalisation) AS STRING) AS mesure, '0' AS attendu
    FROM silver.hospitalisation
    UNION ALL
    SELECT 'sejours sans patient, etablissement ou diagnostic' AS controle,
           CAST(SUM(IF(id_patient_pseudo IS NULL OR identifiant_organisation IS NULL OR code_diag IS NULL, 1, 0)) AS STRING) AS mesure,
           '0' AS attendu
    FROM silver.hospitalisation
    UNION ALL
    SELECT 'sejours avant la naissance (A17)' AS controle, CAST(COUNT(*) AS STRING) AS mesure, '62' AS attendu
    FROM silver.hospitalisation h JOIN silver.patient p ON h.id_patient_pseudo = p.id_patient_pseudo
    WHERE h.date_entree < p.date_naissance
    UNION ALL
    SELECT concat('hospitalisations ', a.annee) AS controle, CAST(COALESCE(m.n, 0L) AS STRING) AS mesure, a.attendu AS attendu
    FROM (
        SELECT stack(7, '2015', '255', '2016', '395', '2017', '458', '2018', '395', '2019', '374', '2020', '410', '2021', '192')
               AS (annee, attendu)
        FROM silver.geographie WHERE categorie = 'INCONNU'
    ) a
    LEFT JOIN (
        SELECT substr(date_entree, 1, 4) AS annee, COUNT(*) AS n
        FROM silver.hospitalisation GROUP BY substr(date_entree, 1, 4)
    ) m ON a.annee = m.annee
-- Décès (J16)
    UNION ALL
    SELECT 'deces ecrits + rejetes = empreintes distinctes du Bronze' AS controle, CAST(s.n + r.n AS STRING) AS mesure,
           CAST(b.u AS STRING) AS attendu
    FROM (SELECT COUNT(*) AS n FROM silver.deces) s
    CROSS JOIN (SELECT COUNT(*) AS n FROM silver.rejet WHERE job = 'J16') r
    CROSS JOIN (SELECT COUNT(DISTINCT empreinte_ligne) AS u FROM bronze.deces) b
    UNION ALL
    SELECT 'deces retires comme doublons' AS controle, CAST(b.n - s.n - r.n AS STRING) AS mesure, '161112' AS attendu
    FROM (SELECT COUNT(*) AS n FROM silver.deces) s
    CROSS JOIN (SELECT COUNT(*) AS n FROM silver.rejet WHERE job = 'J16') r
    CROSS JOIN (SELECT COUNT(*) AS n FROM bronze.deces) b
    UNION ALL
    SELECT 'deces en double dans Silver' AS controle, CAST(COUNT(*) - COUNT(DISTINCT empreinte_ligne) AS STRING) AS mesure,
           '0' AS attendu
    FROM silver.deces
    UNION ALL
    SELECT concat('rejets J16 : ', motif) AS controle, CAST(COUNT(*) AS STRING) AS mesure, CAST(NULL AS STRING) AS attendu
    FROM silver.rejet WHERE job = 'J16' GROUP BY motif
    UNION ALL
    SELECT 'deces sans sexe' AS controle, CAST(SUM(IF(sexe IS NULL, 1, 0)) AS STRING) AS mesure, '0' AS attendu FROM silver.deces
    UNION ALL
    SELECT 'deces avant 1970 ou sans date' AS controle,
           CAST(SUM(IF(date_deces < '1970-01-01' OR date_deces IS NULL, 1, 0)) AS STRING) AS mesure, '0' AS attendu
    FROM silver.deces
    UNION ALL
    SELECT 'deces avec date de naissance complete sans age' AS controle,
           CAST(SUM(IF(date_naissance IS NOT NULL AND age_deces IS NULL, 1, 0)) AS STRING) AS mesure, '0' AS attendu
    FROM silver.deces
    UNION ALL
    SELECT 'deces 2019' AS controle, CAST(COUNT(*) AS STRING) AS mesure, CAST(NULL AS STRING) AS attendu
    FROM silver.deces WHERE annee_deces = 2019
    UNION ALL
    SELECT concat('deces region ', code_region) AS controle, CAST(COUNT(*) AS STRING) AS mesure, CAST(NULL AS STRING) AS attendu
    FROM silver.deces WHERE code_region IN ('ETR', 'COM', 'INC') GROUP BY code_region
-- Satisfaction (J17)
    UNION ALL
    SELECT concat('lignes satisfaction ', CAST(annee AS STRING)) AS controle, CAST(COUNT(*) AS STRING) AS mesure,
           IF(annee = 2019, '1152', '1150') AS attendu
    FROM silver.satisfaction GROUP BY annee
    UNION ALL
    SELECT 'scores 2020' AS controle, CAST(COUNT(score_global) AS STRING) AS mesure, '837' AS attendu
    FROM silver.satisfaction WHERE annee = 2020
    UNION ALL
    SELECT 'repondants 2020' AS controle, CAST(SUM(IF(score_global IS NOT NULL, nb_reponses, 0)) AS STRING) AS mesure,
           '330224' AS attendu
    FROM silver.satisfaction WHERE annee = 2020
    UNION ALL
    SELECT 'moyenne ponderee 2020 (B8)' AS controle,
           CAST(ROUND(SUM(IF(score_global IS NOT NULL, score_global * nb_reponses, 0))
                      / SUM(IF(score_global IS NOT NULL, nb_reponses, 0)), 2) AS STRING) AS mesure, '73.64' AS attendu
    FROM silver.satisfaction WHERE annee = 2020
    UNION ALL
    SELECT concat('moyenne ponderee 2020 region ', code_region) AS controle,
           CAST(ROUND(SUM(score_global * nb_reponses) / SUM(nb_reponses), 2) AS STRING) AS mesure,
           IF(code_region = '53', '74.95', '65.72') AS attendu
    FROM silver.satisfaction WHERE annee = 2020 AND score_global IS NOT NULL AND code_region IN ('53', '03') GROUP BY code_region
    UNION ALL
    SELECT concat('part retrouvee ', CAST(annee AS STRING)) AS controle,
           CAST(ROUND(100 * SUM(IF(identifiant_organisation IS NOT NULL, 1, 0)) / COUNT(*), 1) AS STRING) AS mesure,
           IF(annee = 2020, '99.7', CAST(NULL AS STRING)) AS attendu
    FROM silver.satisfaction GROUP BY annee
    UNION ALL
    SELECT concat('region e-Satis differente de celle de l etablissement ', CAST(annee AS STRING)) AS controle,
           CAST(SUM(IF(code_region <> code_region_etablissement, 1, 0)) AS STRING) AS mesure, CAST(NULL AS STRING) AS attendu
    FROM silver.satisfaction GROUP BY annee
) resultats;
