#!/bin/bash
# F2 : index du datamart PostgreSQL, lancé sur le PC (Git Bash), pas sur la VM.
# Chaque requête B1 à B8 est lancée 4 fois dans chaque état d'index, comme dans lancer_benchmark.sh.
#
# Prérequis (une seule fois, voir README.md) :
#   base chu_bench créée, 01_creer_datamart.sql passé, 02_volume.sql passé pour chaque palier voulu.
# Connexion : variables PGHOST, PGPORT, PGUSER (postgres par défaut), et le mot de passe dans
# %APPDATA%\postgresql\pgpass.conf ou PGPASSWORD. Le mot de passe n'est jamais écrit dans ce dossier.
#
# Usage, depuis Benchmark/postgres :
#   bash lancer_postgres.sh            -> paliers v1 et v10
#   bash lancer_postgres.sh v1 v10 v50 -> avec le palier de 50 millions
# Le script peut être relancé : les essais réussis sont sautés.

cd "$(dirname "$0")"
PSQL="${PSQL:-/c/Program Files/PostgreSQL/14/bin/psql.exe}"
export PGHOST="${PGHOST:-localhost}" PGUSER="${PGUSER:-postgres}" PGDATABASE="${PGDATABASE:-chu_bench}"
export PGCLIENTENCODING=UTF8 LC_ALL=C

ESSAIS=4
RESULTATS=../resultats/resultats_postgres.csv
TAILLES=../resultats/logs/postgres_index.csv
REQUETES=../requetes/F2_postgres
mkdir -p ../resultats/logs ../resultats/plans_postgres
[ -f "$RESULTATS" ] || echo "horodatage;famille;test;groupe;moteur;essai;secondes_moteur;secondes_total;lignes;octets_lus_hdfs;empreinte;statut" > "$RESULTATS"
[ -f "$TAILLES" ] || echo "horodatage;volume;etat;secondes_creation;taille_index_mo;taille_consultations_mo" > "$TAILLES"

VOLUMES=("$@")
[ ${#VOLUMES[@]} -eq 0 ] && VOLUMES=(v1 v10)
# ETATS="couvrant" bash lancer_postgres.sh v10 : ne mesurer que certains états d'index.
read -r -a ETATS <<< "${ETATS:-sans_index btree couvrant}"
# WORK_MEM=64MB : mémoire de travail par opération de tri ou de regroupement (4 Mo à l'installation).
# Les tests prennent alors le suffixe _wm64MB, pour ne pas se mélanger avec ceux du réglage d'origine.
SUFFIXE=""
[ -n "$WORK_MEM" ] && SUFFIXE="_wm$WORK_MEM"

psql_() { "$PSQL" -X -q -v ON_ERROR_STOP=1 "$@"; }

# Même empreinte que sur la VM : nombres arrondis à 2 décimales, lignes triées.
empreinte() {
    awk -F'\t' 'BEGIN {OFS = "\t"} {for (i = 1; i <= NF; i++) if ($i ~ /^-?[0-9]+(\.[0-9]+)?$/) $i = sprintf("%.2f", $i); print}' sortie.txt \
        | sort | md5sum | cut -c1-12
}

# Libellé du palier pour les noms de tests : v1 -> 1M, v10 -> 10M.
palier() { echo "${1#v}M"; }

# Seules B1, B2 et B6 lisent les consultations : les autres questions ne changent pas avec le palier.
questions() {
    if [ "$1" = v1 ]; then ls "$REQUETES"/B*.sql; else ls "$REQUETES"/B1_*.sql "$REQUETES"/B2_*.sql "$REQUETES"/B6_*.sql; fi
}

etat_complet() {
    local volume=$1 etat=$2 fichier q
    for fichier in $(questions "$volume"); do
        q=$(basename "$fichier" | cut -d_ -f1)
        [ "$(grep -c ";F2;${q}_$(palier "$volume")_$etat$SUFFIXE;.*;OK$" "$RESULTATS")" -ge "$ESSAIS" ] || return 1
    done
}

appliquer_etat() {
    local volume=$1 etat=$2 debut fin
    psql_ -f index_0_aucun.sql || return 1
    debut=$(date +%s.%N)
    case "$etat" in
        btree) psql_ -v schema=v1 -f index_1_btree.sql && { [ "$volume" = v1 ] || psql_ -v schema="$volume" -f index_1_btree.sql; } || return 1 ;;
        couvrant) psql_ -v schema=v1 -f index_2_couvrant.sql && { [ "$volume" = v1 ] || psql_ -v schema="$volume" -f index_2_couvrant.sql; } || return 1 ;;
    esac
    fin=$(date +%s.%N)
    # Place prise par les index et par la table des consultations du palier, pour le rapport coût / gain.
    psql_ -A -t -F';' -c "SELECT ROUND(COALESCE(SUM(pg_relation_size(indexrelid)), 0) / 1e6, 1),
                                 ROUND(pg_table_size('$volume.fait_consultation') / 1e6, 1)
                          FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid JOIN pg_namespace n ON n.oid = c.relnamespace
                          WHERE n.nspname IN ('dm', 'v1', '$volume')" \
        | awk -v h="$(date '+%F %T')" -v v="$volume" -v e="$etat" -v s="$(awk -v d="$debut" -v f="$fin" 'BEGIN {printf "%.1f", f - d}')" \
              -F';' 'NF == 2 {print h ";" v ";" e ";" s ";" $1 ";" $2}' >> "$TAILLES"
}

mesurer() {
    local volume=$1 etat=$2 fichier=$3 q test groupe essai debut fin total secondes statut code
    q=$(basename "$fichier" | cut -d_ -f1)
    test="${q}_$(palier "$volume")_$etat$SUFFIXE"
    # le résultat ne dépend ni de l'index ni du réglage : les tests d'un palier forment un groupe
    groupe="$q"; [ "$volume" = v1 ] || groupe="${q}_$(palier "$volume")_varie"
    export PGOPTIONS="-c search_path=$volume,v1,dm"
    [ -n "$WORK_MEM" ] && PGOPTIONS="$PGOPTIONS -c work_mem=$WORK_MEM"
    # Plan d'exécution réel, gardé une fois par test (lecture de la table, de l'index, ou de l'index seul).
    if [ ! -f "../resultats/plans_postgres/F2_$test.txt" ]; then
        { echo "EXPLAIN (ANALYZE, BUFFERS)"; grep -v '^--' "$fichier"; } > explain.sql
        psql_ -f explain.sql > "../resultats/plans_postgres/F2_$test.txt" 2>&1
    fi
    for essai in $(seq 1 "$ESSAIS"); do
        grep -q ";F2;$test;$groupe;postgres;$essai;.*;OK$" "$RESULTATS" && continue
        echo "$(date '+%F %T') F2 $test essai $essai/$ESSAIS"
        debut=$(date +%s.%N)
        psql_ -A -t -F $'\t' -c '\timing on' -f "$fichier" -o sortie.txt > temps.txt 2> erreurs.txt
        code=$?
        fin=$(date +%s.%N)
        # \timing écrit « Time: 123.456 ms » (ou « Temps : 123,456 ms ») ; on le passe en secondes.
        secondes=$(grep -oE '[0-9]+[.,][0-9]+ ms' temps.txt | tail -1 | tr ',' '.' | awk '{printf "%.3f", $1 / 1000}')
        sed -i 's/\r$//' sortie.txt
        total=$(awk -v d="$debut" -v f="$fin" 'BEGIN {printf "%.2f", f - d}')
        statut=OK
        if [ "$code" -ne 0 ] || [ -z "$secondes" ]; then statut=ECHEC; fi
        echo "$(date '+%F %T');F2;$test;$groupe;postgres;$essai;$secondes;$total;$(wc -l < sortie.txt);;$(empreinte);$statut" >> "$RESULTATS"
        cp sortie.txt "../resultats/logs/sortie_F2_${test}_postgres.txt"
        if [ "$statut" = ECHEC ]; then
            cp erreurs.txt "../resultats/logs/ECHEC_F2_${test}_postgres.txt"
            echo "$(date '+%F %T') ECHEC F2 $test, voir resultats/logs/ECHEC_F2_${test}_postgres.txt"
            return 1
        fi
    done
}

psql_ -c 'SELECT 1' > /dev/null || { echo "Connexion à PostgreSQL impossible ($PGUSER@$PGHOST/$PGDATABASE)."; exit 1; }
for volume in "${VOLUMES[@]}"; do
    psql_ -A -t -c "SELECT 1 FROM pg_namespace WHERE nspname = '$volume'" | grep -q 1 \
        || { echo "Le schéma $volume n'existe pas : lancer d'abord 02_volume.sql (ou 01 pour v1)."; continue; }
    for etat in "${ETATS[@]}"; do
        etat_complet "$volume" "$etat" && continue
        echo "$(date '+%F %T') palier $volume, état $etat : pose des index"
        appliquer_etat "$volume" "$etat" || { echo "ECHEC pose des index $volume $etat"; exit 1; }
        for fichier in $(questions "$volume"); do
            mesurer "$volume" "$etat" "$fichier"
        done
    done
done
rm -f sortie.txt temps.txt erreurs.txt explain.sql
echo "$(date '+%F %T') fin F2"
