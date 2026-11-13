-- B4 Taux d'hospitalisation par diagnostic (praticiens, obligatoire).
-- Version PostgreSQL, lancée sur le datamart de test chu_bench (famille F2), dans les trois états d'index.
-- Définition du livrable 1 : Part des séjours du groupe portant sur le diagnostic X sur la période Y.
-- Écart avec le livrable 1 : Partiellement conforme. La requête compte les séjours de 2019 par diagnostic mais ne calcule pas la part,
-- qui demanderait une fonction de fenêtre comme dans B1. Le coût de lecture et de regroupement est le même.
-- Opérations éprouvées : filtre sur la date, jointure avec la dimension des diagnostics, regroupement.
-- Résultat attendu : 371 lignes, empreinte d2b873cef59c.
-- Médiane des essais 2 à 4, au volume réel : Hive 82 s, Impala 0,38 s, PostgreSQL 0,005 s (sans index).
SELECT d.code_diag, COUNT(*) AS nb_sejours
FROM fait_hospitalisation f
JOIN dim_diagnostic d ON f.id_diagnostic = d.id_diagnostic
WHERE f.id_temps_admission BETWEEN 20190101 AND 20191231
GROUP BY d.code_diag;
