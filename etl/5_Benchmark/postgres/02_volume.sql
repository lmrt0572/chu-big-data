-- F2 et volume : recopie les consultations du Gold pour obtenir 10 ou 50 millions de lignes.
-- Lancement depuis Benchmark/postgres, après 01_creer_datamart.sql :
--   psql -d chu_bench -v ON_ERROR_STOP=1 -v schema=v10 -v copies=10 -f 02_volume.sql
--   psql -d chu_bench -v ON_ERROR_STOP=1 -v schema=v50 -v copies=50 -f 02_volume.sql
--
-- Pourquoi pas de simples copies : dans l'ancien F7, chaque consultation était recopiée à l'identique,
-- ce qui donnait des données trop régulières (Parquet les compressait au point que 100 M de lignes
-- se lisaient en 12 Mo). Ici, la copie k (k = 0 à copies - 1) garde la ligne d'origine pour k = 0,
-- et pour k > 0 déplace chaque clé vers une autre valeur réelle, de façon déterministe :
--
--   rang      = position de la valeur parmi les valeurs distinctes connues (0, 1, 2...), triées par identifiant
--   nouveau   = valeur dont le rang vaut (rang + k * pas) modulo nombre de valeurs
--   pas       = 7919 (professionnel), 4547 (établissement), 2003 (diagnostic), 3001 (patient), 31 (date)
--   id_consultation = id_consultation + k * 2 000 000
--
-- Les clés inconnues (-1) restent à -1, pour garder le même taux de rattachement qu'en Gold (R15).
-- Les dates restent parmi les dates réelles des consultations (2015 à 2023), donc les filtres sur
-- 2019 gardent environ la même sélectivité. La tranche d'âge n'est pas déplacée.
--
-- La même formule s'écrit dans Hive avec ROW_NUMBER() et pmod() : les tables obtenues dans Hive et
-- dans PostgreSQL sont alors identiques, ce qui permet de comparer leurs résultats par l'empreinte.

\if :{?schema}
\else
    \echo 'Il manque -v schema=v10 (ou v50).'
    \quit
\endif
\if :{?copies}
\else
    \echo 'Il manque -v copies=10 (ou 50).'
    \quit
\endif

DROP SCHEMA IF EXISTS :"schema" CASCADE;
CREATE SCHEMA :"schema";

-- Rangs des valeurs connues, une table par clé déplacée.
CREATE TEMP TABLE rang_pro AS
SELECT id, (ROW_NUMBER() OVER (ORDER BY id) - 1)::INTEGER AS rang
FROM (SELECT DISTINCT id_professionnel AS id FROM v1.fait_consultation WHERE id_professionnel <> -1) s;
CREATE TEMP TABLE rang_etab AS
SELECT id, (ROW_NUMBER() OVER (ORDER BY id) - 1)::INTEGER AS rang
FROM (SELECT DISTINCT id_etablissement AS id FROM v1.fait_consultation WHERE id_etablissement <> -1) s;
CREATE TEMP TABLE rang_diag AS
SELECT id, (ROW_NUMBER() OVER (ORDER BY id) - 1)::INTEGER AS rang
FROM (SELECT DISTINCT id_diagnostic AS id FROM v1.fait_consultation WHERE id_diagnostic <> -1) s;
CREATE TEMP TABLE rang_pat AS
SELECT id, (ROW_NUMBER() OVER (ORDER BY id) - 1)::INTEGER AS rang
FROM (SELECT DISTINCT id_patient AS id FROM v1.fait_consultation WHERE id_patient <> -1) s;
CREATE TEMP TABLE rang_date AS
SELECT id, (ROW_NUMBER() OVER (ORDER BY id) - 1)::INTEGER AS rang
FROM (SELECT DISTINCT id_temps AS id FROM v1.fait_consultation WHERE id_temps <> -1) s;
CREATE UNIQUE INDEX ON rang_pro (rang);
CREATE UNIQUE INDEX ON rang_etab (rang);
CREATE UNIQUE INDEX ON rang_diag (rang);
CREATE UNIQUE INDEX ON rang_pat (rang);
CREATE UNIQUE INDEX ON rang_date (rang);
ANALYZE rang_pro; ANALYZE rang_etab; ANALYZE rang_diag; ANALYZE rang_pat; ANALYZE rang_date;

SELECT (SELECT COUNT(*) FROM rang_pro) AS n_pro,
       (SELECT COUNT(*) FROM rang_etab) AS n_etab,
       (SELECT COUNT(*) FROM rang_diag) AS n_diag,
       (SELECT COUNT(*) FROM rang_pat) AS n_pat,
       (SELECT COUNT(*) FROM rang_date) AS n_date
\gset
\echo 'valeurs distinctes : professionnels' :n_pro ', établissements' :n_etab ', diagnostics' :n_diag ', patients' :n_pat ', dates' :n_date

CREATE TABLE :"schema".fait_consultation (LIKE v1.fait_consultation);

INSERT INTO :"schema".fait_consultation
SELECT c.id_consultation + k * 2000000,
       c.id_tranche_age,
       COALESCE(d2.id, c.id_diagnostic),
       COALESCE(e2.id, c.id_etablissement),
       COALESCE(p2.id, c.id_professionnel),
       COALESCE(pa2.id, c.id_patient),
       COALESCE(t2.id, c.id_temps)
FROM v1.fait_consultation c
CROSS JOIN generate_series(0, :copies - 1) AS k
LEFT JOIN rang_pro p1 ON p1.id = c.id_professionnel
LEFT JOIN rang_pro p2 ON p2.rang = (p1.rang + k * 7919) % :n_pro
LEFT JOIN rang_etab e1 ON e1.id = c.id_etablissement
LEFT JOIN rang_etab e2 ON e2.rang = (e1.rang + k * 4547) % :n_etab
LEFT JOIN rang_diag d1 ON d1.id = c.id_diagnostic
LEFT JOIN rang_diag d2 ON d2.rang = (d1.rang + k * 2003) % :n_diag
LEFT JOIN rang_pat pa1 ON pa1.id = c.id_patient
LEFT JOIN rang_pat pa2 ON pa2.rang = (pa1.rang + k * 3001) % :n_pat
LEFT JOIN rang_date t1 ON t1.id = c.id_temps
LEFT JOIN rang_date t2 ON t2.rang = (t1.rang + k * 31) % :n_date;

VACUUM ANALYZE :"schema".fait_consultation;

-- Contrôles : le nombre de lignes, et des valeurs distinctes qui augmentent bien avec les copies.
SELECT COUNT(*) AS lignes,
       COUNT(DISTINCT (id_etablissement, id_temps)) AS couples_etab_date,
       COUNT(DISTINCT id_professionnel) AS professionnels,
       ROUND(100.0 * SUM(CASE WHEN id_etablissement <> -1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_rattachees,
       ROUND(100.0 * SUM(CASE WHEN id_temps BETWEEN 20190101 AND 20191231 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_2019,
       pg_size_pretty(pg_total_relation_size(:'schema' || '.fait_consultation')) AS taille
FROM :"schema".fait_consultation;
