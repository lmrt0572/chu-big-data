-- Famille F1 Partitionnement des décès par année, test p3_mauvais_filtre (voir README_Benchmark.md).
-- B7 sur la table partitionnée, mais l'année est filtrée dans dim_temps et non sur annee_deces.
-- Hive ne sait plus quel dossier lire : il lit tout, puis fait une jointure de plus.
SELECT r.code_region, r.libelle_region, SUM(f.nb_deces) AS deces_2019
FROM gold.fait_deces f
JOIN gold.dim_temps t ON f.id_temps = t.id_temps
JOIN gold.dim_region r ON f.id_region = r.id_region
WHERE t.annee = 2019
GROUP BY r.code_region, r.libelle_region;
