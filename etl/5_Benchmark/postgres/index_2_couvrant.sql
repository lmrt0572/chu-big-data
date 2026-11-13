-- F2, état 2 : des index pensés pour les requêtes du tableau de bord, en plus de ceux de l'état 1.
-- Ils commencent par la colonne filtrée (la date) et contiennent (INCLUDE) les colonnes regroupées :
-- PostgreSQL peut alors répondre en lisant l'index seul, sans aller dans la table (« Index Only Scan »).
-- Lancement : psql -d chu_bench -v schema=v1 -f index_2_couvrant.sql (puis v10, v50).

\if :{?schema}
\else
    \echo 'Il manque -v schema=v1 (ou v10, v50).'
    \quit
\endif

\ir index_1_btree.sql

SELECT :'schema' = 'v1' AS avec_dimensions \gset
\if :avec_dimensions
    -- B4 : séjours d'une année par diagnostic ; B3 : patients hospitalisés d'une année.
    CREATE INDEX IF NOT EXISTS cv_hosp_temps ON v1.fait_hospitalisation (id_temps_admission)
        INCLUDE (id_diagnostic, id_patient);
    -- B7 : décès d'une année par région.
    CREATE INDEX IF NOT EXISTS cv_deces_annee ON v1.agg_deces_region (annee_deces, id_region)
        INCLUDE (nb_deces);
\endif

-- B1, B2, B6 : consultations d'une année par établissement, diagnostic ou professionnel.
CREATE INDEX IF NOT EXISTS cv_consult_temps ON :"schema".fait_consultation (id_temps)
    INCLUDE (id_etablissement, id_diagnostic, id_professionnel);

VACUUM ANALYZE;
