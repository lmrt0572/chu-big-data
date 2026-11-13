-- B8 Satisfaction globale par région en 2020 (direction, optionnel).
-- Version HiveQL, lancée telle quelle dans Hive et dans Impala sur la base gold (famille F4).
-- Définition du livrable 1 : Moyenne pondérée somme(note_globale x nb_avis) / somme(nb_avis), scores absents exclus.
-- Écart avec le livrable 1 : Conforme.
-- Opérations éprouvées : deux jointures (région et calendrier), moyenne pondérée, division de deux sommes décimales.
-- Résultat attendu : 17 lignes, empreinte da4a29c5c30f.
-- Médiane des essais 2 à 4, au volume réel : Hive 128 s, Impala 0,76 s, PostgreSQL 0,006 s (sans index).
-- Empreintes : Impala tronque la division de deux décimaux au lieu de l'arrondir (71,59 au lieu de 71,60 pour la
-- Martinique), d'où une empreinte différente (49abaf924a17). Convertir les sommes en DOUBLE dans la version
-- Impala corrigerait l'écart. Cette variante n'a pas été écrite ni mesurée.
SELECT r.code_region, r.libelle_region, SUM(s.nb_avis) AS reponses,
       ROUND(SUM(s.note_globale * s.nb_avis) / SUM(s.nb_avis), 2) AS score_pondere
FROM gold.fait_satisfaction s
JOIN gold.dim_region r ON s.id_region = r.id_region
JOIN gold.dim_temps t ON s.id_temps = t.id_temps
WHERE t.annee = 2020 AND s.note_globale IS NOT NULL AND s.nb_avis > 0
GROUP BY r.code_region, r.libelle_region;
