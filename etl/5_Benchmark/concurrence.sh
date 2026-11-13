#!/bin/bash
# Plusieurs utilisateurs en même temps : chaque « utilisateur » ouvre le tableau de bord, c'est-à-dire
# lance les 8 questions B1 à B8 à la suite dans une seule session. On mesure le temps d'ouverture
# quand 1, 5 puis 10 utilisateurs le font en même temps, 3 fois chacun.
#
# Usage :
#   sur la VM, depuis le dossier du benchmark : bash concurrence.sh impala
#   sur le PC (Git Bash), depuis Benchmark :    PGPASSWORD=... bash concurrence.sh postgres
# Résultat : resultats/concurrence_<moteur>.csv, une ligne par utilisateur et par tour.
# Attention : la VM tourne sur le PC. Ne pas lancer les deux moteurs en même temps.

cd "$(dirname "$0")"
MOTEUR=${1:?usage : bash concurrence.sh impala|postgres}
NIVEAUX=${NIVEAUX:-"1 5 10"}
TOURS=${TOURS:-3}
SORTIE=resultats/concurrence_$MOTEUR.csv
TRAVAIL=$(mktemp -d)
mkdir -p resultats
[ -f "$SORTIE" ] || echo "horodatage;moteur;utilisateurs;tour;utilisateur;secondes_ouverture;secondes_moteur;statut" > "$SORTIE"

case "$MOTEUR" in
    impala)
        sed 's/\r$//' requetes/F4_moteur/B*.sql > "$TRAVAIL/tableau_de_bord.sql"
        ;;
    postgres)
        PSQL="${PSQL:-/c/Program Files/PostgreSQL/14/bin/psql.exe}"
        export PGHOST="${PGHOST:-localhost}" PGUSER="${PGUSER:-postgres}" PGDATABASE="${PGDATABASE:-chu_bench}"
        # volume réel, avec les index en place à ce moment-là (voir le README de postgres/)
        export PGOPTIONS="-c search_path=v1,dm" PGCLIENTENCODING=UTF8
        { echo '\timing on'; cat requetes/F2_postgres/B*.sql; } > "$TRAVAIL/tableau_de_bord.sql"
        ;;
    *) echo "moteur inconnu : $MOTEUR"; exit 1 ;;
esac

# Un utilisateur : une session qui lance les 8 requêtes, temps total vu de l'utilisateur et somme des temps du moteur.
utilisateur() {
    local n=$1 tour=$2 u=$3 debut fin code moteur
    debut=$(date +%s.%N)
    if [ "$MOTEUR" = impala ]; then
        impala-shell -B -f "$TRAVAIL/tableau_de_bord.sql" > /dev/null 2> "$TRAVAIL/err_$u.txt" < /dev/null
        code=$?
        moteur=$(sed -n 's/.*row(s) in \([0-9.]*\)s.*/\1/p' "$TRAVAIL/err_$u.txt" | awk '{s += $1} END {printf "%.3f", s}')
    else
        "$PSQL" -X -q -A -t -v ON_ERROR_STOP=1 -f "$TRAVAIL/tableau_de_bord.sql" -o /dev/null > "$TRAVAIL/err_$u.txt" 2>&1
        code=$?
        moteur=$(grep -oE '[0-9]+[.,][0-9]+ ms' "$TRAVAIL/err_$u.txt" | tr ',' '.' | awk '{s += $1} END {printf "%.3f", s / 1000}')
    fi
    fin=$(date +%s.%N)
    echo "$(date '+%F %T');$MOTEUR;$n;$tour;$u;$(awk -v d="$debut" -v f="$fin" 'BEGIN {printf "%.2f", f - d}');$moteur;$([ $code -eq 0 ] && echo OK || echo ECHEC)" >> "$TRAVAIL/lignes_${n}_${tour}.csv"
}

for n in $NIVEAUX; do
    for tour in $(seq 1 "$TOURS"); do
        echo "$(date '+%F %T') $MOTEUR : $n utilisateur(s), tour $tour/$TOURS"
        : > "$TRAVAIL/lignes_${n}_${tour}.csv"
        for u in $(seq 1 "$n"); do
            utilisateur "$n" "$tour" "$u" &
        done
        wait
        cat "$TRAVAIL/lignes_${n}_${tour}.csv" >> "$SORTIE"
    done
done
rm -rf "$TRAVAIL"
echo "$(date '+%F %T') fin, résultats dans $SORTIE"
