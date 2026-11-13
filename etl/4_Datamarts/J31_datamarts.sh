#!/bin/bash
# J31 Datamarts : copie texte du Gold (Hive), export Sqoop vers PostgreSQL, publication contrôlée dans les deux datamarts.
# Voir README.md à la racine du dossier etl. Dépend de J22 (le Gold doit être à jour).
#
# Usage, sur la VM, depuis le dossier du script :
#   bash J31_datamarts.sh [date_chargement]
# Variables facultatives :
#   PG_HOTE (localhost), PG_PORT (15432), PG_BASE (chu_decisionnel), PG_COMPTE (chu_etl)
#   PG_MDP_FICHIER (/home/cloudera/.chu_etl_pg) : fichier qui contient le seul mot de passe, sans retour à la ligne,
#   lisible par cloudera seulement (chmod 400). Il n'est jamais livré.
#   PG_JDBC : pilote JDBC PostgreSQL (celui livré avec la VM par défaut)
# En maquette, PostgreSQL tourne sur le PC et le pare-feu Windows bloque la VM. Le script est donc lancé
# à travers une connexion SSH ouverte depuis le PC, qui transporte un tunnel vers PostgreSQL :
#   ssh -R 15432:localhost:5432 cloudera@quickstart.cloudera "cd /home/cloudera/datamarts && bash J31_datamarts.sh"
# Sur un vrai serveur, il suffit de donner PG_HOTE et PG_PORT.

set -euo pipefail
cd "$(dirname "$0")"

DATE_CHARGEMENT=${1:-2026-10-30}
ID_EXECUTION=DM_$(date +%Y%m%d_%H%M%S)
DEBUT=$(date '+%F %T')
PG_HOTE=${PG_HOTE:-localhost}
PG_PORT=${PG_PORT:-15432}
PG_BASE=${PG_BASE:-chu_decisionnel}
PG_COMPTE=${PG_COMPTE:-chu_etl}
PG_MDP_FICHIER=${PG_MDP_FICHIER:-/home/cloudera/.chu_etl_pg}
PG_JDBC=${PG_JDBC:-/var/lib/sqoop2/postgresql-9.1-901.jdbc4.jar}
[ -f "$PG_JDBC" ] || PG_JDBC=/var/lib/sqoop2/tomcat-deployment/webapps/sqoop/WEB-INF/lib/postgresql-9.1-901.jdbc4.jar
CONNEXION="jdbc:postgresql://$PG_HOTE:$PG_PORT/$PG_BASE"
TABLES="dim_temps dim_tranche_age dim_region dim_etablissement dim_diagnostic dim_patient dim_professionnel
        fait_consultation fait_hospitalisation agg_deces_region agg_satisfaction_region"

# Sqoop cherche le pilote JDBC dans son classpath (client) et dans -libjars (tâches MapReduce).
export HADOOP_CLASSPATH="$PG_JDBC${HADOOP_CLASSPATH:+:$HADOOP_CLASSPATH}"
SQOOP_COMMUN=(--connect "$CONNEXION" --username "$PG_COMPTE" --password-file "file://$PG_MDP_FICHIER")

log() { echo "$(date '+%F %T') $*"; }

# R17, R18 : une ligne par table dans gold.audit, que le job réussisse ou non.
auditer() {
    local statut=$1 valeurs="" t
    for t in $TABLES; do
        valeurs+="${valeurs:+,}('$ID_EXECUTION','J31_datamarts','$t','$DEBUT','$(date '+%F %T')','$statut',${LUES[$t]:-0},${ECRITES[$t]:-0},'$DATE_CHARGEMENT')"
    done
    hive -S -e "SET mapreduce.map.memory.mb=1024; SET mapreduce.map.java.opts=-Xmx820m;
                INSERT INTO TABLE gold.audit VALUES $valeurs" || log "audit non ecrit"
}
declare -A LUES ECRITES
trap 'log "ECHEC J31, datamarts inchanges"; auditer ECHEC; exit 1' ERR

[ -r "$PG_MDP_FICHIER" ] || { log "fichier du mot de passe absent : $PG_MDP_FICHIER"; exit 1; }
sed -i 's/\r$//' ./*.hql

log "debut J31 (execution $ID_EXECUTION, vers $CONNEXION)"

# 1. Copie texte du Gold.
hive -S -f J31_datamarts.hql

# 2. Volumes écrits par Hive : une ligne de fichier texte par ligne de table.
ATTENDUS=""
for t in $TABLES; do
    LUES[$t]=$(hdfs dfs -cat "/chu/datamart_export/$t/*" | wc -l)
    ATTENDUS+="${ATTENDUS:+,}$t=${LUES[$t]}"
    log "$t : ${LUES[$t]} lignes a exporter"
done

# 3. Export Sqoop vers les tables d'arrivée (schéma chargement), vidées d'abord.
sqoop eval -libjars "$PG_JDBC" "${SQOOP_COMMUN[@]}" --query "SELECT chargement.vider()" > /dev/null
for t in $TABLES; do
    log "export $t"
    sqoop export -libjars "$PG_JDBC" "${SQOOP_COMMUN[@]}" \
        --table "$t" --export-dir "/chu/datamart_export/$t" \
        --input-fields-terminated-by '\t' --input-lines-terminated-by '\n' \
        --input-null-string '\\N' --input-null-non-string '\\N' \
        --batch -m 1 \
        -- --schema chargement 2> "export_$t.log" || { tail -20 "export_$t.log"; false; }
done

# 4. Publication : contrôle des volumes puis copie dans les deux datamarts, en une seule transaction.
log "publication"
sqoop eval -libjars "$PG_JDBC" "${SQOOP_COMMUN[@]}" \
    --query "SELECT * FROM chargement.publier('$ID_EXECUTION', '$ATTENDUS')" | tee publication.txt
grep -q "datamart_direction.fait_consultation" publication.txt || { log "publication refusee, voir ci-dessus"; false; }

for t in $TABLES; do
    ECRITES[$t]=$(awk -F'|' -v t="datamart_direction.$t" '{gsub(/ /, "", $2)} $2 == t {gsub(/ /, "", $3); print $3}' publication.txt)
    [ -n "${ECRITES[$t]}" ] || ECRITES[$t]=$(awk -F'|' -v t="datamart_praticiens.$t" '{gsub(/ /, "", $2)} $2 == t {gsub(/ /, "", $3); print $3}' publication.txt)
done
trap - ERR
auditer OK
rm -f export_*.log
log "fin J31, datamarts publies (detail dans publication.txt et chargement.journal)"
