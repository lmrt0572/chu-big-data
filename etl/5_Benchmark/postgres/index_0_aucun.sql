-- F2, état 0 : supprime tous les index du datamart de test (schémas dm, v1, v10, v50).
-- Il n'y a pas de clé primaire : les index uniques de index_1_btree.sql en tiennent lieu.
DO $$
DECLARE
    i RECORD;
BEGIN
    FOR i IN SELECT schemaname, indexname FROM pg_indexes WHERE schemaname IN ('dm', 'v1', 'v10', 'v50') LOOP
        EXECUTE format('DROP INDEX %I.%I', i.schemaname, i.indexname);
    END LOOP;
END
$$;
ANALYZE;
