#!/bin/bash
# N3, dernière marche de l'escalier : la question « consultations par région » dans le datamart PostgreSQL,
# sur les mêmes tables en étoile que les marches 1 et 2 de la VM (bench.fait_consult_etab et bench.dim_etab_region,
# exportées dans export_postgres/n3_*.tsv). Sans index, puis avec un index couvrant sur la clé de jointure.
# Les essais s'ajoutent à resultats/resultats_postgres.csv (famille N3, groupe REGION, comme sur la VM).
# Usage, depuis Benchmark/postgres : PGPASSWORD=... bash n3_escalier.sh
# Ne pas lancer pendant une mesure sur la VM : elle tourne sur le même PC.

cd "$(dirname "$0")"
PSQL="${PSQL:-/c/Program Files/PostgreSQL/14/bin/psql.exe}"
export PGHOST="${PGHOST:-localhost}" PGUSER="${PGUSER:-postgres}" PGDATABASE="${PGDATABASE:-chu_bench}"
export PGCLIENTENCODING=UTF8 LC_ALL=C
RESULTATS=../resultats/resultats_postgres.csv
ESSAIS=${ESSAIS:-4}
psql_() { "$PSQL" -X -q -v ON_ERROR_STOP=1 "$@"; }

psql_ <<'EOF' || exit 1
DROP SCHEMA IF EXISTS n3 CASCADE;
CREATE SCHEMA n3;
CREATE TABLE n3.fait_consult_etab (num_consultation VARCHAR(50), identifiant_organisation VARCHAR(50));
CREATE TABLE n3.dim_etab_region (identifiant_organisation VARCHAR(50), region VARCHAR(100));
\copy n3.fait_consult_etab FROM '../export_postgres/n3_fait_consult_etab.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
\copy n3.dim_etab_region FROM '../export_postgres/n3_dim_etab_region.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, NULL 'NULL', QUOTE '"', ENCODING 'UTF8')
VACUUM ANALYZE n3.fait_consult_etab;
VACUUM ANALYZE n3.dim_etab_region;
EOF

REQUETE="SELECT d.region, COUNT(*) AS nb_consultations
FROM n3.fait_consult_etab f
JOIN n3.dim_etab_region d ON f.identifiant_organisation = d.identifiant_organisation
GROUP BY d.region;"

mesurer() {
    local test=$1 essai secondes code
    "$PSQL" -X -q -c "EXPLAIN (ANALYZE, BUFFERS) $REQUETE" > "../resultats/plans_postgres/N3_$test.txt" 2>&1
    for essai in $(seq 1 "$ESSAIS"); do
        "$PSQL" -X -q -A -t -F $'\t' -c '\timing on' -c "$REQUETE" -o sortie.txt > temps.txt 2>&1
        code=$?
        secondes=$(grep -oE '[0-9]+[.,][0-9]+ ms' temps.txt | tail -1 | tr ',' '.' | awk '{printf "%.3f", $1 / 1000}')
        sed -i 's/\r$//' sortie.txt
        empreinte=$(awk -F'\t' 'BEGIN {OFS = "\t"} {for (i = 1; i <= NF; i++) if ($i ~ /^-?[0-9]+(\.[0-9]+)?$/) $i = sprintf("%.2f", $i); print}' sortie.txt | sort | md5sum | cut -c1-12)
        statut=OK; { [ "$code" -ne 0 ] || [ -z "$secondes" ]; } && statut=ECHEC
        echo "$(date '+%F %T');N3;$test;REGION;postgres;$essai;$secondes;$secondes;$(wc -l < sortie.txt);;$empreinte;$statut" >> "$RESULTATS"
        echo "N3 $test essai $essai : $secondes s ($statut)"
    done
    cp sortie.txt "../resultats/logs/sortie_N3_${test}_postgres.txt"
}

mesurer s3_datamart_sans_index
# Une commande par -c : VACUUM refuse de tourner dans le bloc de transaction d'un -c à plusieurs requêtes.
psql_ -c "CREATE INDEX ON n3.dim_etab_region (identifiant_organisation) INCLUDE (region)" \
      -c "CREATE INDEX ON n3.fait_consult_etab (identifiant_organisation)" \
      -c "VACUUM ANALYZE n3.fait_consult_etab" -c "VACUUM ANALYZE n3.dim_etab_region" || exit 1
mesurer s3_datamart_index
rm -f sortie.txt temps.txt
