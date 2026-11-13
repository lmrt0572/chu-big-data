#!/bin/bash
# Construit la couche Gold (modèle en étoile) à partir du Silver (voir README_Gold.md).
# Usage : bash lancer_gold.sh [date_chargement]
#   nohup bash lancer_gold.sh 2026-10-30 > run.log 2>&1 &
#   tail -f run.log
# Le script s'arrête au premier job en échec, les jobs suivants ne sont pas lancés.

set -euo pipefail
cd "$(dirname "$0")"

DATE_CHARGEMENT=${1:-2026-10-30}
ID_EXECUTION=GOLD_$(date +%Y%m%d_%H%M%S)

# Les fichiers copiés depuis Windows peuvent garder des fins de ligne CRLF, que Hive lit mal.
sed -i 's/\r$//' ./*.hql

echo "$(date '+%F %T') debut Gold (execution $ID_EXECUTION, date de chargement $DATE_CHARGEMENT)"
hdfs dfs -mkdir -p /chu/gold
hdfs dfs -chmod 775 /chu/gold
hive -S -f gold_tables.hql

for JOB in J21_dimensions J22_faits; do
    echo "$(date '+%F %T') debut $JOB"
    if ! hive -S \
        -hivevar date_chargement="$DATE_CHARGEMENT" \
        -hivevar id_execution="$ID_EXECUTION" \
        -hivevar debut="$(date '+%F %T')" \
        -f "$JOB.hql"; then
        echo "$(date '+%F %T') ECHEC $JOB, voir gold.audit"
        exit 1
    fi
    echo "$(date '+%F %T') fin $JOB"
done

echo "$(date '+%F %T') debut controles"
hive -S -hivevar id_execution="$ID_EXECUTION" -f verifier_gold.hql | tee resultats_verification_gold.txt

# Impala ne voit les tables écrites par Hive qu'après un rafraîchissement de son catalogue.
# Les statistiques l'aident ensuite à choisir l'ordre des jointures.
if command -v impala-shell >/dev/null 2>&1; then
    echo "$(date '+%F %T') rafraichissement Impala"
    impala-shell -q "
        INVALIDATE METADATA gold.dim_temps; INVALIDATE METADATA gold.dim_tranche_age;
        INVALIDATE METADATA gold.dim_region; INVALIDATE METADATA gold.dim_etablissement;
        INVALIDATE METADATA gold.dim_diagnostic; INVALIDATE METADATA gold.dim_patient;
        INVALIDATE METADATA gold.dim_professionnel; INVALIDATE METADATA gold.fait_consultation;
        INVALIDATE METADATA gold.fait_hospitalisation; INVALIDATE METADATA gold.fait_deces;
        INVALIDATE METADATA gold.fait_satisfaction; INVALIDATE METADATA gold.audit;
        COMPUTE STATS gold.dim_temps; COMPUTE STATS gold.dim_tranche_age;
        COMPUTE STATS gold.dim_region; COMPUTE STATS gold.dim_etablissement;
        COMPUTE STATS gold.dim_diagnostic; COMPUTE STATS gold.dim_patient;
        COMPUTE STATS gold.dim_professionnel; COMPUTE STATS gold.fait_consultation;
        COMPUTE STATS gold.fait_hospitalisation; COMPUTE STATS gold.fait_deces;
        COMPUTE STATS gold.fait_satisfaction;
    " || echo "$(date '+%F %T') Impala arrete, catalogue non rafraichi (les tables restent lisibles dans Hive)"
fi

echo "$(date '+%F %T') fin Gold, resultats dans resultats_verification_gold.txt"
