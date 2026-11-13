#!/bin/bash
# Benchmark du livrable 2 : chaque test de plan.txt est lancé plusieurs fois dans Hive puis dans Impala.
# Lancement sur la VM, depuis le dossier ~/bench :
#   nohup bash lancer_benchmark.sh > run.log 2>&1 &
# Un autre plan peut être donné en argument : nohup bash lancer_benchmark.sh plan_suite.txt > run_suite.log 2>&1 &
# Le script peut être relancé après une panne : les préparations faites et les essais réussis sont sautés.
# Il n'écrit que dans la base bench, jamais dans bronze, silver ou gold.

cd "$(dirname "$0")"
PLAN=${1:-plan.txt}
echo $$ > PID
sed -i 's/\r$//' "$PLAN" reglages_hive.sql ./*.hql ./*.sql ./*.sh requetes/*/*.sql 2>/dev/null

# Le premier essai est fait à froid, on garde ensuite la médiane des suivants.
ESSAIS=4
RESULTATS=resultats.csv
# Les map joins chargent la petite table dans Hive lui-même, et les 128 Mo prévus par défaut n'y suffisent pas.
export HADOOP_CLIENT_OPTS="$HADOOP_CLIENT_OPTS -Xmx768m"
mkdir -p logs plans
if [ ! -f "$RESULTATS" ]; then
    echo "horodatage;famille;test;groupe;moteur;essai;secondes_moteur;secondes_total;lignes;octets_lus_hdfs;empreinte;statut" > "$RESULTATS"
fi

etat() {
    echo "$*" > ETAT
    echo "$(date '+%F %T') $*"
}

# Empreinte du résultat, comparable d'un moteur à l'autre : nombres arrondis à 2 décimales, lignes triées.
empreinte() {
    awk -F'\t' 'BEGIN {OFS = "\t"} {for (i = 1; i <= NF; i++) if ($i ~ /^-?[0-9]+(\.[0-9]+)?$/) $i = sprintf("%.2f", $i); print}' sortie.txt \
        | sort | md5sum | cut -c1-12
}

preparer() {
    local fichier=$1
    [ -f "logs/$fichier.ok" ] && return 0
    etat "preparation $fichier"
    # Une préparation *_impala.sql est lancée dans Impala, les autres dans Hive.
    if [[ "$fichier" == *_impala.sql ]]; then
        impala-shell -f "$fichier" > "logs/$fichier.log" 2>&1 < /dev/null
    else
        hive -i reglages_hive.sql -f "$fichier" > "logs/$fichier.log" 2>&1 < /dev/null
    fi
    if [ $? -ne 0 ]; then
        echo "$(date '+%F %T') ECHEC preparation $fichier, voir logs/$fichier.log"
        return 1
    fi
    # Impala ne voit les tables créées par Hive qu'après un rafraîchissement de son catalogue.
    # Les tables *sans_stats* gardent volontairement l'absence de statistiques (famille F8).
    for table in $(grep -oE 'CREATE TABLE bench\.[a-z0-9_]+' "$fichier" | cut -d' ' -f3 | sort -u); do
        if [[ "$table" == *sans_stats* ]]; then
            impala-shell -q "INVALIDATE METADATA $table" >> "logs/$fichier.log" 2>&1 < /dev/null
        else
            impala-shell -q "INVALIDATE METADATA $table; COMPUTE STATS $table" >> "logs/$fichier.log" 2>&1 < /dev/null
        fi
        # dossiers, fichiers et octets de la table : utile pour les partitions et la compression
        echo "$table $(hdfs dfs -count "/user/hive/warehouse/bench.db/${table#bench.}" 2>/dev/null)" >> "logs/fichiers_tables.txt"
    done
    hdfs dfs -du -s /user/hive/warehouse/bench.db/* >> "logs/tailles_tables.txt" 2>/dev/null
    touch "logs/$fichier.ok"
    echo "$(date '+%F %T') fin preparation $fichier"
}

# Plan d'exécution de Hive, gardé une fois par test pour expliquer les temps (partitions lues, type de jointure).
plan_hive() {
    local cible="plans/$1_$2.txt"
    [ -f "$cible" ] && return 0
    awk '!fait && /^SELECT/ {print "EXPLAIN"; fait = 1} {print}' "$3" > explain.sql
    hive -S -i reglages_hive.sql -f explain.sql > "$cible" 2>&1 < /dev/null
}

# Plan d'exécution d'Impala, gardé une fois par test (type de jointure, ordre des tables, partitions lues).
plan_impala() {
    local cible="plans/$1_$2_impala.txt"
    [ -f "$cible" ] && return 0
    awk '!fait && /^SELECT/ {print "EXPLAIN"; fait = 1} {print}' "$3" > explain.sql
    impala-shell -B -f explain.sql > "$cible" 2>&1 < /dev/null
}

mesurer() {
    local famille=$1 test=$2 groupe=$3 fichier=$4 moteur=$5
    [ "$moteur" = hive ] && plan_hive "$famille" "$test" "$fichier"
    [ "$moteur" = impala ] && plan_impala "$famille" "$test" "$fichier"
    for essai in $(seq 1 "$ESSAIS"); do
        grep -q ";$famille;$test;$groupe;$moteur;$essai;.*;OK$" "$RESULTATS" && continue
        etat "$famille $test $moteur essai $essai/$ESSAIS"
        debut=$(date +%s.%N)
        if [ "$moteur" = hive ]; then
            hive -i reglages_hive.sql -f "$fichier" > sortie.txt 2> erreurs.txt < /dev/null
            code=$?
            # Hive écrit des messages de journalisation au milieu des résultats : on les retire.
            # Les lignes datées viennent du lecteur Parquet, quand un map join lit la petite table dans Hive.
            sed -i -E '/^WARN: /d; /^[A-Z][a-z]{2} [0-9]{1,2}, [0-9]{4} [0-9:]+ [AP]M (INFO|WARNING|SEVERE): /d' sortie.txt
            secondes=$(grep -o 'Time taken: [0-9.]*' erreurs.txt | tail -1 | awk '{print $3}')
            octets=$(grep -o 'HDFS Read: [0-9]*' erreurs.txt | awk '{s += $3} END {print s + 0}')
        else
            impala-shell -B -f "$fichier" > sortie.txt 2> erreurs.txt < /dev/null
            code=$?
            secondes=$(sed -n 's/.*row(s) in \([0-9.]*\)s.*/\1/p' erreurs.txt | tail -1)
            octets=
        fi
        fin=$(date +%s.%N)
        total=$(awk -v d="$debut" -v f="$fin" 'BEGIN {printf "%.2f", f - d}')
        statut=OK
        if [ "$code" -ne 0 ] || [ -z "$secondes" ]; then statut=ECHEC; fi
        echo "$(date '+%F %T');$famille;$test;$groupe;$moteur;$essai;$secondes;$total;$(wc -l < sortie.txt);$octets;$(empreinte);$statut" >> "$RESULTATS"
        cp sortie.txt "logs/sortie_${famille}_${test}_${moteur}.txt"
        if [ "$statut" = ECHEC ]; then
            cp erreurs.txt "logs/ECHEC_${famille}_${test}_${moteur}.txt"
            echo "$(date '+%F %T') ECHEC $famille $test $moteur, voir logs/ECHEC_${famille}_${test}_${moteur}.txt"
            return 1
        fi
    done
}

etat "debut du benchmark"
sauter=0
while IFS='|' read -r famille test groupe fichier moteurs; do
    case "$famille" in ''|'#'*) continue ;; esac
    if [ "$famille" = PREPARER ]; then
        sauter=0
        preparer "$test" || sauter=1
        continue
    fi
    [ "$sauter" = 1 ] && continue
    for moteur in $moteurs; do
        mesurer "$famille" "$test" "$groupe" "$fichier" "$moteur"
    done
done < "$PLAN"

if [ "$PLAN" = plan.txt ]; then
    etat "export pour PostgreSQL"
    bash exporter_postgres.sh || echo "$(date '+%F %T') ECHEC export pour PostgreSQL"
fi

etat TERMINE
