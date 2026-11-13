-- J13 Professionnels : spécialité contrôlée, ADELI complété, un établissement par professionnel.
-- Règles : R08, R09, R10, R12, R17, R18. Aucun rejet, une spécialité absente est laissée vide (inconnu).
-- Contrôle de fin : un seul établissement par professionnel.
-- Dépend de J11 (silver.specialite, silver.etablissement).
-- Paramètres : load_date, id_execution, debut (voir lancer_silver.sh).

SET hive.auto.convert.join=false;
SET parquet.compression=SNAPPY;
-- Les conteneurs MapReduce de la VM n'ont que 128 Mo par défaut, trop peu pour écrire du Parquet.
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;

-- R12. Un ADELI de 8 chiffres a perdu son zéro de tête, il est complété à 9.
-- R10. Parmi les établissements connus du professionnel, priorité salarié, puis libéral, puis bénévole.
-- À priorité égale, le plus petit identifiant_organisation est retenu, pour que le choix soit reproductible.
-- Une même paire professionnel établissement peut figurer avec deux modes, elle ne compte qu'une fois.
-- attribution : UNIQUE (un seul établissement), PRIORITE (choisi par R10), SANS_ORGANISATION (présent
-- dans l'activité sans établissement), ABSENT_ACTIVITE (absent du fichier des activités).
WITH pro AS (
    SELECT IF(trim(identifiant) RLIKE '^[0-9]{8}$' AND upper(trim(type_identifiant)) = 'ADELI',
              lpad(trim(identifiant), 9, '0'), trim(identifiant)) AS identifiant,
           upper(trim(type_identifiant)) AS type_identifiant,
           trim(profession) AS profession,
           trim(code_specialite) AS code_specialite
    FROM bronze.professionnel
    WHERE load_date = '${hiveconf:load_date}'
),
activite AS (
    SELECT IF(trim(a.identifiant) RLIKE '^[0-9]{8}$', lpad(trim(a.identifiant), 9, '0'), trim(a.identifiant)) AS identifiant,
           trim(a.identifiant_organisation) AS identifiant_organisation,
           IF(trim(a.mode_exercice) = '', NULL, trim(a.mode_exercice)) AS mode_exercice,
           CASE WHEN trim(a.mode_exercice) RLIKE '^Salari' THEN 1
                WHEN trim(a.mode_exercice) RLIKE '^Lib' THEN 2
                WHEN trim(a.mode_exercice) RLIKE '^B' THEN 3
                ELSE 4 END AS priorite
    FROM bronze.activite a
    WHERE a.load_date = '${hiveconf:load_date}'
),
presence AS (
    SELECT DISTINCT identifiant FROM activite
),
paire AS (
    SELECT identifiant, identifiant_organisation, mode_exercice, priorite,
           ROW_NUMBER() OVER (PARTITION BY identifiant, identifiant_organisation ORDER BY priorite) AS rang_paire
    FROM (
        SELECT a.identifiant, a.identifiant_organisation, a.mode_exercice, a.priorite
        FROM activite a
        JOIN silver.etablissement e ON a.identifiant_organisation = e.identifiant_organisation
    ) x
),
choix AS (
    SELECT identifiant, identifiant_organisation, mode_exercice,
           COUNT(*) OVER (PARTITION BY identifiant) AS nb_etablissements,
           ROW_NUMBER() OVER (PARTITION BY identifiant ORDER BY priorite, identifiant_organisation) AS rang
    FROM paire
    WHERE rang_paire = 1
)
INSERT OVERWRITE TABLE silver.professionnel
SELECT p.identifiant,
       p.type_identifiant,
       p.profession,
       s.code_specialite,
       s.specialite,
       c.identifiant_organisation,
       c.mode_exercice,
       CAST(COALESCE(c.nb_etablissements, 0) AS INT),
       CASE WHEN c.nb_etablissements = 1 THEN 'UNIQUE'
            WHEN c.nb_etablissements > 1 THEN 'PRIORITE'
            WHEN pr.identifiant IS NOT NULL THEN 'SANS_ORGANISATION'
            ELSE 'ABSENT_ACTIVITE' END,
       '${hiveconf:id_execution}', '${hiveconf:load_date}', 'PG DATA2023.Professionnel_de_sante, activite_professionnel_sante.csv'
FROM pro p
LEFT JOIN silver.specialite s ON p.code_specialite = s.code_specialite
LEFT JOIN (SELECT * FROM choix WHERE rang = 1) c ON p.identifiant = c.identifiant
LEFT JOIN presence pr ON p.identifiant = pr.identifiant;

INSERT INTO TABLE silver.audit
SELECT '${hiveconf:id_execution}', 'J13', 'professionnel', '${hiveconf:debut}', from_unixtime(unix_timestamp()),
       IF(l.n = e.n AND e.u = e.n, 'OK', 'ECHEC'),
       l.n, e.n, 0L, 0L, '${hiveconf:load_date}'
FROM (SELECT COUNT(*) AS n FROM bronze.professionnel WHERE load_date = '${hiveconf:load_date}') l
CROSS JOIN (SELECT COUNT(*) AS n, COUNT(DISTINCT identifiant) AS u FROM silver.professionnel) e;

-- Échec du job si une ligne est perdue ou si un professionnel apparaît deux fois, donc avec deux établissements (R18).
SELECT assert_true(statut = 'OK')
FROM silver.audit
WHERE id_execution = '${hiveconf:id_execution}' AND job = 'J13';
