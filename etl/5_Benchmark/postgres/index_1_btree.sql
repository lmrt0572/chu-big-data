-- F2, état 1 : l'indexation « classique » qu'on poserait sans réfléchir aux requêtes.
-- Un index unique sur l'identifiant de chaque dimension (l'équivalent d'une clé primaire),
-- et un index B-tree par clé étrangère des faits, chacun sur une seule colonne.
-- Lancement : psql -d chu_bench -v schema=v1 -f index_1_btree.sql (puis v10, v50 pour les consultations).
-- Les dimensions et les petits faits ne sont indexés qu'avec schema=v1.

\if :{?schema}
\else
    \echo 'Il manque -v schema=v1 (ou v10, v50).'
    \quit
\endif

SELECT :'schema' = 'v1' AS avec_dimensions \gset
\if :avec_dimensions
    CREATE UNIQUE INDEX IF NOT EXISTS pk_dim_temps ON dm.dim_temps (id_temps);
    CREATE UNIQUE INDEX IF NOT EXISTS pk_dim_tranche_age ON dm.dim_tranche_age (id_tranche_age);
    CREATE UNIQUE INDEX IF NOT EXISTS pk_dim_region ON dm.dim_region (id_region);
    CREATE UNIQUE INDEX IF NOT EXISTS pk_dim_etablissement ON dm.dim_etablissement (id_etablissement);
    CREATE UNIQUE INDEX IF NOT EXISTS pk_dim_diagnostic ON dm.dim_diagnostic (id_diagnostic);
    CREATE UNIQUE INDEX IF NOT EXISTS pk_dim_patient ON dm.dim_patient (id_patient);
    CREATE UNIQUE INDEX IF NOT EXISTS pk_dim_professionnel ON dm.dim_professionnel (id_professionnel);

    CREATE INDEX IF NOT EXISTS ix_hosp_temps ON v1.fait_hospitalisation (id_temps_admission);
    CREATE INDEX IF NOT EXISTS ix_hosp_diag ON v1.fait_hospitalisation (id_diagnostic);
    CREATE INDEX IF NOT EXISTS ix_hosp_patient ON v1.fait_hospitalisation (id_patient);
    CREATE INDEX IF NOT EXISTS ix_hosp_tranche ON v1.fait_hospitalisation (id_tranche_age);
    CREATE INDEX IF NOT EXISTS ix_satis_temps ON v1.fait_satisfaction (id_temps);
    CREATE INDEX IF NOT EXISTS ix_satis_region ON v1.fait_satisfaction (id_region);
    CREATE INDEX IF NOT EXISTS ix_deces_annee ON v1.agg_deces_region (annee_deces);
    CREATE INDEX IF NOT EXISTS ix_deces_region ON v1.agg_deces_region (id_region);
\endif

CREATE INDEX IF NOT EXISTS ix_consult_temps ON :"schema".fait_consultation (id_temps);
CREATE INDEX IF NOT EXISTS ix_consult_etab ON :"schema".fait_consultation (id_etablissement);
CREATE INDEX IF NOT EXISTS ix_consult_diag ON :"schema".fait_consultation (id_diagnostic);
CREATE INDEX IF NOT EXISTS ix_consult_pro ON :"schema".fait_consultation (id_professionnel);
CREATE INDEX IF NOT EXISTS ix_consult_patient ON :"schema".fait_consultation (id_patient);

VACUUM ANALYZE;
