-- Index des datamarts PostgreSQL (livrable 2).
-- À lancer en superutilisateur après datamarts_tables.sql, qui pose déjà une clé primaire (donc un index unique)
-- sur chaque table :
--   psql -U postgres -d chu_decisionnel -v ON_ERROR_STOP=1 -f datamarts_index.sql
-- Les index survivent aux publications de J31 (TRUNCATE puis INSERT) et n'ont pas à être recréés.
--
-- Stratégie, issue du benchmark (index_1_btree.sql et index_2_couvrant.sql de la base d'essai chu_bench) :
--  1. Un index B-tree par clé étrangère des faits. Ceux sur id_etablissement servent la politique RLS
--     de la direction, qui ne garde que les lignes de ses établissements. Les autres servent les requêtes
--     d'exploration très sélectives (un diagnostic, un patient), que le benchmark n'a pas mesurées : sur les
--     requêtes B1 à B8, qui retiennent une année entière, ils n'apportent rien. Ils ne servent pas
--     la vérification des clés étrangères, qui passe par la clé primaire de la dimension, et J31 vide
--     les tables par TRUNCATE, sans DELETE ni UPDATE de dimension qui les solliciterait.
--     Au volume réel, l'ensemble se construit en moins de 10 secondes (6,6 s pour les B-tree, 8,4 s pour
--     les couvrants, mesuré sur chu_bench).
--  2. Des index couvrants, construits à partir des requêtes du tableau de bord. Ils commencent par la colonne
--     filtrée (la date) et contiennent (INCLUDE) les colonnes regroupées, si bien que PostgreSQL répond
--     en lisant l'index seul (« Index Only Scan »). Au volume réel (environ 1 million de consultations), leur
--     effet est imperceptible. À 10 et 50 millions de lignes, ils divisent les temps de B1, B2 et B6 par 3 à 5.

DO $$
DECLARE
    s TEXT;
BEGIN
    FOREACH s IN ARRAY ARRAY['datamart_praticiens', 'datamart_direction'] LOOP
        -- 1. Clés étrangères des faits.
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_consult_etablissement ON %I.fait_consultation (id_etablissement)', s);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_consult_diagnostic ON %I.fait_consultation (id_diagnostic)', s);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_consult_professionnel ON %I.fait_consultation (id_professionnel)', s);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_consult_patient ON %I.fait_consultation (id_patient)', s);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_consult_tranche_age ON %I.fait_consultation (id_tranche_age)', s);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_hosp_etablissement ON %I.fait_hospitalisation (id_etablissement)', s);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_hosp_diagnostic ON %I.fait_hospitalisation (id_diagnostic)', s);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_hosp_patient ON %I.fait_hospitalisation (id_patient)', s);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_hosp_tranche_age ON %I.fait_hospitalisation (id_tranche_age)', s);

        -- 2. Index couvrants.
        -- B1, B2, B6 : consultations d'une année par établissement, diagnostic ou professionnel.
        EXECUTE format('CREATE INDEX IF NOT EXISTS cv_consult_temps ON %I.fait_consultation (id_temps) '
                       'INCLUDE (id_etablissement, id_diagnostic, id_professionnel)', s);
        -- B3, B4 : séjours d'une année par diagnostic, patients hospitalisés d'une année.
        EXECUTE format('CREATE INDEX IF NOT EXISTS cv_hosp_temps ON %I.fait_hospitalisation (id_temps_admission) '
                       'INCLUDE (id_diagnostic, id_patient)', s);
    END LOOP;
END $$;

-- Les statistiques à jour permettent au planificateur de choisir ces index.
ANALYZE datamart_praticiens.fait_consultation;
ANALYZE datamart_praticiens.fait_hospitalisation;
ANALYZE datamart_direction.fait_consultation;
ANALYZE datamart_direction.fait_hospitalisation;
