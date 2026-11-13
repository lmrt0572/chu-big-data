-- B6 Taux de consultation par professionnel (les deux profils, obligatoire).
-- Version HiveQL, lancée telle quelle dans Hive et dans Impala sur la base gold (famille F4).
-- Définition du livrable 1 : Part des consultations du groupe assurées par le professionnel P sur la période Y, affichée avec sa spécialité.
-- Écart avec le livrable 1 : Partiellement conforme. La requête rend les 20 professionnels qui ont le plus consulté en 2019, avec leur
-- spécialité, ce qui correspond au visuel du tableau de bord, mais elle ne calcule pas la part.
-- Opérations éprouvées : jointure de 1 million de consultations avec une dimension de 1 million de professionnels, regroupement,
-- tri complet puis LIMIT. C'est la requête qui profite le plus de la mémoire de tri (work_mem).
-- Résultat attendu : 20 lignes, empreinte 18d11aa39e40.
-- Médiane des essais 2 à 4, au volume réel : Hive 123 s, Impala 0,57 s, PostgreSQL 0,20 s (sans index).
-- Le second critère de tri rend le résultat identique d'un moteur à l'autre en cas d'égalité.
SELECT p.id_professionnel, p.specialite, COUNT(*) AS nb_consultations
FROM gold.fait_consultation f
JOIN gold.dim_professionnel p ON f.id_professionnel = p.id_professionnel
WHERE f.id_temps BETWEEN 20190101 AND 20191231
GROUP BY p.id_professionnel, p.specialite
ORDER BY nb_consultations DESC, id_professionnel
LIMIT 20;
