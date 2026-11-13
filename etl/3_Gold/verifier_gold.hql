-- Contrôles de fin de chaîne du Gold, lancés par lancer_gold.sh après J21 et J22.
-- Les contrôles bloquants (lignes perdues, clés en double, membre -1, clés étrangères vides) sont faits dans J21 et J22
-- et écrits dans gold.audit. Ce fichier affiche leur résultat, puis des indicateurs de contrôle.
-- Paramètre : id_execution (voir lancer_gold.sh).

SET hive.cli.print.header=true;
SET hive.auto.convert.join=false;
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;

-- 1. Audit de l'exécution. Attendu : OK sur les 11 tables.
SELECT job, table_cible, statut, lignes_lues, lignes_ecrites
FROM gold.audit
WHERE id_execution = '${hivevar:id_execution}'
ORDER BY job, table_cible;

-- 2. Part des consultations rattachées à un établissement. Attendu : 63,9 % (contrôle F14).
SELECT COUNT(*) AS consultations,
       SUM(IF(id_etablissement <> -1, 1, 0)) AS rattachees,
       ROUND(100 * SUM(IF(id_etablissement <> -1, 1, 0)) / COUNT(*), 2) AS part_rattachee
FROM gold.fait_consultation;

-- 3. Séjours par tranche d'âge. Attendu : 62 séjours en inconnu, ceux qui commencent avant la naissance (A17, contrôle F25).
SELECT ta.libelle_tranche, COUNT(*) AS sejours
FROM gold.fait_hospitalisation fh
JOIN gold.dim_tranche_age ta ON fh.id_tranche_age = ta.id_tranche_age
GROUP BY ta.libelle_tranche
ORDER BY sejours DESC;

-- 4. Indicateur B7 : décès de 2019 par région.
SELECT r.code_region, r.libelle_region, SUM(fd.nb_deces) AS deces_2019
FROM gold.fait_deces fd
JOIN gold.dim_region r ON fd.id_region = r.id_region
WHERE fd.annee_deces = 2019
GROUP BY r.code_region, r.libelle_region
ORDER BY deces_2019 DESC;

-- 5. Indicateur B8 : score e-Satis 2020 par région, pondéré par le nombre de réponses.
SELECT r.code_region, r.libelle_region, SUM(fs.nb_avis) AS reponses,
       ROUND(SUM(fs.note_globale * fs.nb_avis) / SUM(fs.nb_avis), 2) AS score_pondere
FROM gold.fait_satisfaction fs
JOIN gold.dim_region r ON fs.id_region = r.id_region
JOIN gold.dim_temps t ON fs.id_temps = t.id_temps
WHERE t.annee = 2020 AND fs.note_globale IS NOT NULL AND fs.nb_avis > 0
GROUP BY r.code_region, r.libelle_region
ORDER BY score_pondere DESC;

-- 6. Établissements par région (code_region et libelle_region recopiés dans dim_etablissement).
-- Attendu : aucun libellé « Inconnu » hors du membre -1, sauf code région absent de dim_region.
SELECT code_region, libelle_region, COUNT(*) AS etablissements
FROM gold.dim_etablissement
GROUP BY code_region, libelle_region
ORDER BY code_region;
