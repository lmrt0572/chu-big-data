# Runs the reference DAX queries against the open test model, without and with the demo role.
$o = "$PSScriptRoot\pbi_outils.ps1"
$q2019 = @'
EVALUATE CALCULATETABLE(ROW(
  "consult", [Consultations], "groupe", [Consultations du groupe], "nonratt", [Consultations non rattachées],
  "part_nr", [Part non rattachée], "b1", [B1 Part de l'établissement], "sejours", [Séjours],
  "actifs", [Patients actifs], "hosp", [Patients hospitalisés], "b3", [B3 Taux d'hospitalisation],
  "b3g", [B3 Taux du groupe]), dim_temps[annee] = 2019)
'@
$qmars = @'
EVALUATE CALCULATETABLE(ROW("b3_mars", [B3 Taux d'hospitalisation], "b3g_mars", [B3 Taux du groupe]),
  dim_temps[annee] = 2019, dim_temps[mois] = 3)
'@
$qfixe = @'
EVALUATE ROW("b7", [B7 Décès en 2019], "s19", [Score 2019], "s20", [B8 Score 2020], "evol", [Évolution du score])
'@
"--- 2019, sans rôle"; & $o -Action dax -Requete $q2019
"--- mars 2019"; & $o -Action dax -Requete $qmars
"--- fixes"; & $o -Action dax -Requete $qfixe
"--- 2019, rôle Direction démo Bretagne"; & $o -Action dax -Requete $q2019 -Role "Direction démo Bretagne"
"--- tables calculées"; & $o -Action dax -Requete "EVALUATE TOPN(3, b3_groupe_annee, b3_groupe_annee[annee], 0)"
