-- B1 Taux de consultation dans un établissement (direction, obligatoire).
-- Version HiveQL, lancée telle quelle dans Hive et dans Impala sur la base gold (famille F4).
-- Définition du livrable 1 : Part des consultations du groupe réalisées dans l'établissement X sur la période Y. Les consultations
-- sans établissement restent dans le total et s'affichent « non rattachées ».
-- Écart avec le livrable 1 : Conforme. Y vaut 2019 et tous les établissements sont calculés d'un coup, le tableau de bord filtrant ensuite.
-- La ligne -1 regroupe les consultations non rattachées (35,97 % en 2019).
-- Opérations éprouvées : filtre sur la date, regroupement de 1 million de consultations, jointure avec la dimension des
-- établissements, part calculée par une fonction de fenêtre (SUM ... OVER).
-- Résultat attendu : 22 778 lignes, empreinte 8753868e6ca3.
-- Médiane des essais 2 à 4, au volume réel : Hive 124 s, Impala 0,52 s, PostgreSQL 0,17 s (sans index).
-- Empreintes : Impala rend une empreinte différente (fae320f9b933) parce qu'impala-shell double les guillemets de 96 noms
-- d'établissement à l'affichage. Les valeurs sont identiques ligne à ligne.
SELECT e.id_etablissement, e.raison_sociale, t.nb_consultations,
       ROUND(100 * t.nb_consultations / SUM(t.nb_consultations) OVER (), 2) AS part_pct
FROM (
    SELECT id_etablissement, COUNT(*) AS nb_consultations
    FROM gold.fait_consultation
    WHERE id_temps BETWEEN 20190101 AND 20191231
    GROUP BY id_etablissement
) t
JOIN gold.dim_etablissement e ON t.id_etablissement = e.id_etablissement;
