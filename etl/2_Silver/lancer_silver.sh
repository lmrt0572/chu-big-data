#!/bin/bash
# Construit la couche Silver à partir d'une partition du Bronze (voir README_Silver.md).
# Usage : bash lancer_silver.sh [load_date] [job ...]
#   bash lancer_silver.sh                         tous les jobs, sur la partition 2026-10-30
#   bash lancer_silver.sh 2026-10-30 J16_deces    un seul job
# Variable facultative : SEUIL_REJET (0.05 par défaut, règle R18).
# Le script s'arrête au premier job en échec, les jobs suivants ne sont pas lancés.

set -e
cd "$(dirname "$0")"

LOAD_DATE=${1:-2026-10-30}
shift || true
JOBS=${@:-J11_referentiels J12_patients J13_professionnels J14_consultations J15_hospitalisations J16_deces J17_satisfaction}
ID_EXECUTION=$(date +%Y%m%d_%H%M%S)
SEUIL_REJET=${SEUIL_REJET:-0.05}

hdfs dfs -mkdir -p /chu/silver
hdfs dfs -chmod 750 /chu/silver
hive -S -f silver_tables.hql

for JOB in $JOBS; do
    echo "$(date '+%F %T') debut $JOB (execution $ID_EXECUTION, partition $LOAD_DATE)"
    if ! hive -S \
        -hiveconf load_date="$LOAD_DATE" \
        -hiveconf id_execution="$ID_EXECUTION" \
        -hiveconf debut="$(date '+%F %T')" \
        -hiveconf seuil_rejet="$SEUIL_REJET" \
        -f "$JOB.hql"; then
        echo "$(date '+%F %T') ECHEC $JOB, voir silver.audit et silver.rejet"
        exit 1
    fi
    echo "$(date '+%F %T') fin $JOB"
done

hive -S -e "SELECT job, table_cible, statut, lignes_lues, lignes_ecrites, lignes_rejetees, lignes_doublons
            FROM silver.audit WHERE id_execution = '$ID_EXECUTION' ORDER BY job, table_cible"
