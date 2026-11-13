-- Famille F6 Jointures (modèle en étoile et méthodes de jointure de Hive), test j2_etoile_1_jointure (voir README_Benchmark.md).
-- Même question sur le modèle en étoile : la région est déjà dans la dimension, il reste 1 jointure.
SELECT d.region, COUNT(*) AS nb_consultations
FROM bench.fait_consult_etab f
JOIN bench.dim_etab_region d ON f.identifiant_organisation = d.identifiant_organisation
GROUP BY d.region;
