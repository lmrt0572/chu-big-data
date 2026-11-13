-- Famille F6 Jointures (modèle en étoile et méthodes de jointure de Hive), test j1_source_4_jointures (voir README_Benchmark.md).
-- Consultations par région depuis les tables d'origine : 4 jointures pour aller de la consultation à la région.
SELECT r.libelle AS region, COUNT(*) AS nb_consultations
FROM bronze.consultation c
JOIN (
    SELECT identifiant, MIN(identifiant_organisation) AS id_org
    FROM bronze.activite
    WHERE identifiant_organisation <> ''
    GROUP BY identifiant
) a ON c.id_prof_sante = a.identifiant
JOIN bronze.etablissement e ON a.id_org = e.identifiant_organisation
JOIN bronze.insee_departement d ON substr(e.code_commune, 1, 2) = d.dep
JOIN bronze.insee_region r ON d.reg = r.reg
GROUP BY r.libelle;
