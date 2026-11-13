# Checks the measures of the report against reference values computed with Impala queries.
# The default years of the report are applied by hand: activity 2019, deaths 2019, satisfaction 2020.
$o = "$PSScriptRoot\pbi_outils.ps1"
$defaut = 'dim_temps[annee] = 2019, agg_deces_region[annee_deces] = 2019, agg_satisfaction_region[annee] = 2020'
$tuiles = @"
EVALUATE CALCULATETABLE(ROW(
  "b1", [B1 Part affichée], "t1", [Texte B1], "b2", [Part du 1er diagnostic], "t2", [Texte B2],
  "b3", [B3 Taux d'hospitalisation], "t3", [Texte B3], "b4", [Part du 1er diagnostic de séjour], "t4", [Texte B4],
  "b5", [Taux des hommes], "t5", [Texte B5], "b6", [Part de la 1re spécialité], "t6", [Texte B6],
  "b7", [B7 Décès], "t7", [Texte décès], "taux_deces", [Décès pour 100 000 habitants],
  "b8", [B8 Satisfaction], "t8", [Texte satisfaction], "taux", [Texte taux]), $defaut)
"@
$bretagne = @"
EVALUATE CALCULATETABLE(ROW(
  "consultations", [Consultations], "b1", [B1 Part affichée], "patients", [Patients actifs],
  "hospitalises", [Patients hospitalisés], "b3", [B3 Taux d'hospitalisation], "deces", [B7 Décès],
  "taux_deces", [Décès pour 100 000 habitants], "score", [B8 Satisfaction], "ecart", [Écart au national]),
  $defaut, dim_region[libelle_region] = "Bretagne")
"@
$cas = @'
EVALUATE UNION(
  CALCULATETABLE(ROW("cas", "Psychiatrie 2019", "valeur", [Séjours], "texte", [Texte B3]),
                 dim_temps[annee] = 2019, dim_professionnel[specialite] = "Psychiatrie"),
  CALCULATETABLE(ROW("cas", "Corse 2019 (2 patients)", "valeur", [B3 Taux d'hospitalisation], "texte", [Texte B3]),
                 dim_temps[annee] = 2019, dim_region[libelle_region] = "Corse"),
  CALCULATETABLE(ROW("cas", "2022 (pas de séjour)", "valeur", [Séjours], "texte", [Texte B3]), dim_temps[annee] = 2022),
  CALCULATETABLE(ROW("cas", "2015 (partielle)", "valeur", [Consultations], "texte", [Texte année d'activité]),
                 dim_temps[annee] = 2015),
  CALCULATETABLE(ROW("cas", "décès 2020", "valeur", [B7 Décès], "texte", [Texte décès]), agg_deces_region[annee_deces] = 2020),
  CALCULATETABLE(ROW("cas", "satisfaction 2019", "valeur", [B8 Satisfaction], "texte", [Texte satisfaction]),
                 agg_satisfaction_region[annee] = 2019))
'@
$groupe = @'
EVALUATE CALCULATETABLE(TOPN(3, ADDCOLUMNS(VALUES(dim_temps[debut_mois]), "b3", [B3 Taux d'hospitalisation],
  "groupe", [B3 Taux du groupe]), dim_temps[debut_mois], ASC), dim_temps[annee] = 2019)
'@
$taux = @'
EVALUATE CALCULATETABLE(TOPN(4, ADDCOLUMNS(VALUES(dim_region[libelle_region]), "deces", [B7 Décès],
  "taux", [Décès pour 100 000 habitants]), [taux], DESC), agg_deces_region[annee_deces] = 2019)
'@
"--- tuiles des deux synthèses, années par défaut"; & $o -Action dax -Requete $tuiles
"--- filtre Région = Bretagne"; & $o -Action dax -Requete $bretagne
"--- rôle Direction démo Bretagne"; & $o -Action dax -Requete $tuiles -Role "Direction démo Bretagne"
"--- cas particuliers"; & $o -Action dax -Requete $cas
"--- taux du groupe par mois"; & $o -Action dax -Requete $groupe
"--- décès pour 100 000 habitants, 2019"; & $o -Action dax -Requete $taux
