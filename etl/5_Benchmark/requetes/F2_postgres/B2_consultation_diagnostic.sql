-- B2 Taux de consultation pour un diagnostic (praticiens, obligatoire).
-- Version PostgreSQL, lancée sur le datamart de test chu_bench (famille F2), dans les trois états d'index.
-- Définition du livrable 1 : Part des consultations du groupe portant sur le diagnostic X sur la période Y.
-- Écart avec le livrable 1 : Conforme. Y vaut 2019 et tous les diagnostics sont calculés d'un coup.
-- Opérations éprouvées : les mêmes que B1, sur la dimension des diagnostics (codes CIM-10).
-- Résultat attendu : 15 368 lignes, empreinte c431c313f59a.
-- Médiane des essais 2 à 4, au volume réel : Hive 122 s, Impala 0,38 s, PostgreSQL 0,10 s (sans index).
-- Empreintes : PostgreSQL rend une empreinte différente (c0f877d29dab) à cause de la mise en forme de sa sortie. Les valeurs
-- sont identiques ligne à ligne.
SELECT d.id_diagnostic, d.code_diag, t.nb_consultations,
       ROUND(100.0 * t.nb_consultations / SUM(t.nb_consultations) OVER (), 2) AS part_pct
FROM (
    SELECT id_diagnostic, COUNT(*) AS nb_consultations
    FROM fait_consultation
    WHERE id_temps BETWEEN 20190101 AND 20191231
    GROUP BY id_diagnostic
) t
JOIN dim_diagnostic d ON t.id_diagnostic = d.id_diagnostic;
