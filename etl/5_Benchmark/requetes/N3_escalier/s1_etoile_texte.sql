-- Famille N3 Escalier avant et après, test s1_etoile_texte (voir README_Benchmark.md).
-- Marche 1 de l'escalier : modèle en étoile (1 jointure), mais tables en texte. Seul le modèle change par rapport à la marche 0.
SELECT d.region, COUNT(*) AS nb_consultations
FROM bench.fait_consult_etab_texte f
JOIN bench.dim_etab_region_texte d ON f.identifiant_organisation = d.identifiant_organisation
GROUP BY d.region;
