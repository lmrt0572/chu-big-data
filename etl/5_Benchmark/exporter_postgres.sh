#!/bin/bash
# Exporte du Gold les tables utiles aux tests PostgreSQL (famille F2, index), en texte séparé par des tabulations.
# Comme prévu au livrable 1, les décès arrivent agrégés par année et par région, pas en détail.
# Les colonnes techniques (id_execution, date_chargement, source) ne sont pas exportées.
cd "$(dirname "$0")"
mkdir -p export_postgres

exporter() {
    impala-shell -B --print_header -o "export_postgres/$1.tsv" -q "$2" < /dev/null || return 1
    echo "$1 : $(($(wc -l < "export_postgres/$1.tsv") - 1)) lignes"
}

exporter dim_temps "SELECT id_temps, date_jour, jour, mois, trimestre, annee FROM gold.dim_temps" &&
exporter dim_tranche_age "SELECT id_tranche_age, age_min, age_max, libelle_tranche FROM gold.dim_tranche_age" &&
exporter dim_region "SELECT id_region, code_region, libelle_region FROM gold.dim_region" &&
exporter dim_etablissement "SELECT id_etablissement, identifiant_organisation, raison_sociale, code_region, libelle_region FROM gold.dim_etablissement" &&
exporter dim_diagnostic "SELECT id_diagnostic, code_diag, libelle_diagnostic FROM gold.dim_diagnostic" &&
exporter dim_patient "SELECT id_patient, sexe FROM gold.dim_patient" &&
exporter dim_professionnel "SELECT id_professionnel, code_professionnel, specialite FROM gold.dim_professionnel" &&
exporter fait_consultation "SELECT id_consultation, id_tranche_age, id_diagnostic, id_etablissement, id_professionnel, id_patient, id_temps FROM gold.fait_consultation" &&
exporter fait_hospitalisation "SELECT id_hospitalisation, id_etablissement, id_tranche_age, id_diagnostic, id_patient, id_temps_admission FROM gold.fait_hospitalisation" &&
exporter fait_satisfaction "SELECT id_satisfaction, nb_avis, note_globale, id_region, id_etablissement, id_temps FROM gold.fait_satisfaction" &&
# L'agrégat est recalculé sur le Gold, pour ne pas dépendre d'une table du benchmark construite sur un Gold plus ancien.
exporter agg_deces_region "SELECT annee_deces, id_region, SUM(nb_deces) AS nb_deces FROM gold.fait_deces GROUP BY annee_deces, id_region"
