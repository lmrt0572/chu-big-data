-- Vérification de la couche Bronze (voir Spec_Bronze.md, partie 8).
-- Chaque ligne du résultat compare une valeur mesurée à la valeur attendue, puis affiche OK ou ECART.
-- Les comptages de lignes passent par count, les liens par une jointure.

-- Sans ce réglage, Hive charge la table patient en mémoire pour les jointures, ce qui échoue sur la VM.
SET hive.auto.convert.join=false;

SELECT controle, mesure, attendu, IF(mesure = attendu, 'OK', 'ECART') AS statut
FROM (
    SELECT 'lignes patient' AS controle, COUNT(*) AS mesure, 100000L AS attendu FROM bronze.patient
    UNION ALL
    SELECT 'lignes consultation' AS controle, COUNT(*) AS mesure, 1027157L AS attendu FROM bronze.consultation
    UNION ALL
    SELECT 'lignes professionnel' AS controle, COUNT(*) AS mesure, 1048575L AS attendu FROM bronze.professionnel
    UNION ALL
    SELECT 'lignes diagnostic' AS controle, COUNT(*) AS mesure, 15490L AS attendu FROM bronze.diagnostic
    UNION ALL
    SELECT 'lignes specialite' AS controle, COUNT(*) AS mesure, 93L AS attendu FROM bronze.specialite
    UNION ALL
    SELECT 'lignes etablissement' AS controle, COUNT(*) AS mesure, 416665L AS attendu FROM bronze.etablissement
    UNION ALL
    SELECT 'lignes activite' AS controle, COUNT(*) AS mesure, 1823588L AS attendu FROM bronze.activite
    UNION ALL
    SELECT 'lignes insee_departement' AS controle, COUNT(*) AS mesure, 101L AS attendu FROM bronze.insee_departement
    UNION ALL
    SELECT 'lignes insee_region' AS controle, COUNT(*) AS mesure, 18L AS attendu FROM bronze.insee_region
    UNION ALL
    SELECT 'lignes sejour' AS controle, COUNT(*) AS mesure, 2479L AS attendu FROM bronze.sejour
    UNION ALL
    SELECT 'lignes deces' AS controle, COUNT(*) AS mesure, 25088208L AS attendu FROM bronze.deces
    UNION ALL
    SELECT 'lignes esatis_2019' AS controle, COUNT(*) AS mesure, 1152L AS attendu FROM bronze.esatis_2019
    UNION ALL
    SELECT 'lignes esatis_2020' AS controle, COUNT(*) AS mesure, 1150L AS attendu FROM bronze.esatis_2020
    UNION ALL
    SELECT 'pseudonymes mal formes patient' AS controle, SUM(IF(id_patient_pseudo RLIKE '^[0-9a-f]{64}$', 0, 1)) AS mesure, 0L AS attendu FROM bronze.patient
    UNION ALL
    SELECT 'pseudonymes mal formes consultation' AS controle, SUM(IF(id_patient_pseudo RLIKE '^[0-9a-f]{64}$', 0, 1)) AS mesure, 0L AS attendu FROM bronze.consultation
    UNION ALL
    SELECT 'pseudonymes mal formes sejour' AS controle, SUM(IF(id_patient_pseudo RLIKE '^[0-9a-f]{64}$', 0, 1)) AS mesure, 0L AS attendu FROM bronze.sejour
    UNION ALL
    SELECT 'consultations sans patient' AS controle, COUNT(*) AS mesure, 0L AS attendu
    FROM bronze.consultation c LEFT JOIN bronze.patient p ON c.id_patient_pseudo = p.id_patient_pseudo
    WHERE p.id_patient_pseudo IS NULL
    UNION ALL
    SELECT 'sejours sans patient' AS controle, COUNT(*) AS mesure, 0L AS attendu
    FROM bronze.sejour s LEFT JOIN bronze.patient p ON s.id_patient_pseudo = p.id_patient_pseudo
    WHERE p.id_patient_pseudo IS NULL
    UNION ALL
    SELECT 'patients marques doublons' AS controle, COUNT(*) AS mesure, 2L AS attendu FROM bronze.patient WHERE doublon_probable = '1'
    UNION ALL
    SELECT 'deces en trop' AS controle, COUNT(*) - COUNT(DISTINCT empreinte_ligne) AS mesure, 161112L AS attendu FROM bronze.deces
    UNION ALL
    SELECT 'deces en trop 2019' AS controle, COUNT(*) - COUNT(DISTINCT empreinte_ligne) AS mesure, 118L AS attendu
    FROM bronze.deces WHERE substr(date_deces, 1, 4) = '2019'
) resultats;
