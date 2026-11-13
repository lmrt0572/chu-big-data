"""Generates the Power BI template (.pbit) of the CHU dashboard: one report read from the Gold layer through Impala.

Usage: python generer_pbit.py <source> <sortie.pbit> [dossier_tsv] [page_active] [dossier_ref]
  source       : directquery (reads the bi_ views of vues_powerbi.sql live: facts and large dimensions in
                 DirectQuery, small dimensions in Dual)
                 | import (reads the Gold tables once and keeps a copy, the backup version)
                 | tsv (reads test copies of the Gold tables, without parameters, for local checks)
  dossier_ref  : unzipped .pbix made by Power BI Desktop 2.115, whose base theme is copied
Next to this script: regions_france.json (map made by prep_carte.py) and population_regions.csv (INSEE).
"""
import csv
import hashlib
import json
import os
import sys
import uuid
import zipfile

SOURCE, SORTIE = sys.argv[1], sys.argv[2]
DOSSIER = sys.argv[3] if len(sys.argv) > 3 else ""
PAGE_ACTIVE = int(sys.argv[4]) if len(sys.argv) > 4 else 0
REF = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else None
IMPALA, DQ = SOURCE in ("directquery", "import"), SOURCE == "directquery"
# In DirectQuery, the small dimensions are in Dual mode: Power BI keeps a copy for the slicer lists,
# and still joins them to the facts inside the SQL sent to Impala.
DUAL = {"dim_temps", "dim_tranche_age", "dim_region"}
# Columns added to the Gold tables: by the bi_ views in DirectQuery, by Power Query or DAX otherwise.
AJOUTS = {"dim_temps": [("debut_mois", "d")], "dim_patient": [("libelle_sexe", "s")],
          "dim_etablissement": [("libelle_region", "s")]}
ICI = os.path.dirname(os.path.abspath(__file__))
CARTE_FICHIER = "regions_france.json"

# Marine palette chosen by the group: page, cards, borders, text, accent, secondary, context grey, alert.
FOND, CARTE, TRAIT, GRILLE = "#F2F4F8", "#FFFFFF", "#DDE2EA", "#E6E9EF"
TEXTE, TEXTE2, DISCRET = "#1B2430", "#3D4757", "#5F6878"
ACCENT, SECOND, GRIS, ALERTE, CLAIR = "#1F3864", "#4F81BD", "#C3CAD6", "#C0504D", "#DCE6F2"
NS = uuid.UUID("6f1c2b1e-3c55-4b7e-9a51-0c4d2a1e7b10")


def tag(*parts):
    return str(uuid.uuid5(NS, "|".join(("chu",) + parts)))


def u16(obj):
    return (obj if isinstance(obj, str) else json.dumps(obj, ensure_ascii=False)).encode("utf-16-le")


# ---------------------------------------------------------------- model

M_TYPES = {"i": "Int64.Type", "s": "type text", "d": "type date", "n": "type number"}
# Tables of the Gold layer read as they are (only the useful columns).
TABLES = [
    ("dim_temps", [("id_temps", "i"), ("date_jour", "d"), ("jour", "i"), ("mois", "i"), ("nom_mois", "s"),
                   ("trimestre", "i"), ("semaine_iso", "i"), ("annee", "i")]),
    ("dim_tranche_age", [("id_tranche_age", "i"), ("age_min", "i"), ("age_max", "i"), ("libelle_tranche", "s")]),
    ("dim_region", [("id_region", "i"), ("code_region", "s"), ("libelle_region", "s")]),
    # libelle_region is rebuilt in the model (see table_m): the Gold of 03/11 on the VM does not have it.
    ("dim_etablissement", [("id_etablissement", "i"), ("identifiant_organisation", "s"), ("raison_sociale", "s"),
                           ("code_region", "s")]),
    ("dim_diagnostic", [("id_diagnostic", "i"), ("code_diag", "s"), ("libelle_diagnostic", "s")]),
    ("dim_patient", [("id_patient", "i"), ("sexe", "s")]),
    ("dim_professionnel", [("id_professionnel", "i"), ("code_professionnel", "s"), ("specialite", "s")]),
    ("fait_consultation", [("id_consultation", "i"), ("id_tranche_age", "i"), ("id_diagnostic", "i"),
                           ("id_etablissement", "i"), ("id_professionnel", "i"), ("id_patient", "i"),
                           ("id_temps", "i")]),
    ("fait_hospitalisation", [("id_hospitalisation", "i"), ("id_etablissement", "i"), ("id_tranche_age", "i"),
                              ("id_diagnostic", "i"), ("id_patient", "i"), ("id_temps_admission", "i")]),
]
# Aggregates computed by Impala at load time (GROUP BY), so that Power BI only receives the result.
AGREGATS = [
    ("agg_deces_region", [("annee_deces", "i"), ("id_region", "i"), ("nb_deces", "i")]),
    ("agg_satisfaction_region", [("annee", "i"), ("id_region", "i"), ("nb_etablissements", "i"), ("nb_avis", "i"),
                                 ("nb_avis_notes", "i"), ("somme_notes_ponderees", "n")]),
    ("agg_consultation_jour", [("id_temps", "i"), ("nb_consultations", "i")]),
]

RELATIONS = [
    ("fait_consultation", "id_temps", "dim_temps", "id_temps"),
    ("fait_consultation", "id_tranche_age", "dim_tranche_age", "id_tranche_age"),
    ("fait_consultation", "id_diagnostic", "dim_diagnostic", "id_diagnostic"),
    ("fait_consultation", "id_etablissement", "dim_etablissement", "id_etablissement"),
    ("fait_consultation", "id_professionnel", "dim_professionnel", "id_professionnel"),
    ("fait_consultation", "id_patient", "dim_patient", "id_patient"),
    ("fait_hospitalisation", "id_temps_admission", "dim_temps", "id_temps"),
    ("fait_hospitalisation", "id_tranche_age", "dim_tranche_age", "id_tranche_age"),
    ("fait_hospitalisation", "id_diagnostic", "dim_diagnostic", "id_diagnostic"),
    ("fait_hospitalisation", "id_etablissement", "dim_etablissement", "id_etablissement"),
    ("fait_hospitalisation", "id_patient", "dim_patient", "id_patient"),
    ("agg_deces_region", "id_region", "dim_region", "id_region"),
    ("agg_satisfaction_region", "id_region", "dim_region", "id_region"),
    ("agg_consultation_jour", "id_temps", "dim_temps", "id_temps"),
    # The region of an establishment points to the region dimension, so that one region filter acts on every page.
    ("dim_etablissement", "code_region", "dim_region", "code_region"),
    ("population", "code_region", "dim_region", "code_region"),
]

SORT_BY = {("dim_temps", "nom_mois"): "mois", ("dim_tranche_age", "libelle_tranche"): "id_tranche_age"}

# Labels of the source written without accents, corrected for the most frequent ones.
CORRECTIONS = {
    "specialite": {"Medecine Generale": "Médecine générale", "Anesthesie-reanimation": "Anesthésie-réanimation",
                   "Radio-diagnostic": "Radiodiagnostic", "Pediatrie": "Pédiatrie",
                   "Medecine du travail": "Médecine du travail", "Gynecologie-obstetrique": "Gynécologie-obstétrique",
                   "Chirurgie generale": "Chirurgie générale",
                   "Dermatologie et venereologie": "Dermatologie et vénéréologie",
                   "Gastro-enterologie et hepatologie": "Gastro-entérologie et hépatologie",
                   "Chirurgie orthopedique et traumatologie": "Chirurgie orthopédique et traumatologie",
                   "Gynecologie medicale et obstetrique": "Gynécologie médicale et obstétrique",
                   "Biologie medicale": "Biologie médicale", "Medecine interne": "Médecine interne"},
    "libelle_tranche": {"inconnu": "Âge inconnu"},
}


def source(table):
    """First steps of a query: read a table of the Gold database through Impala (or its test copy)."""
    if DQ:
        return ["    // Lit la vue bi_%s de la couche Gold, interrogée par Impala à chaque visuel" % table,
                '    Source = Impala.Database(Serveur){[Name = Base]}[Data]{[Name = "bi_%s"]}[Data],' % table]
    if IMPALA:
        return ["    // Lit la table de la couche Gold par Impala",
                '    Source = Impala.Database(Serveur){[Name = Base]}[Data]{[Name = "%s"]}[Data],' % table]
    return ["    // Lit la copie de test de la table",
            '    Source = Table.PromoteHeaders(Csv.Document(File.Contents("%s\\%s.tsv"), [Delimiter = "#(tab)", '
            'Encoding = 65001, QuoteStyle = QuoteStyle.None]), [PromoteAllScalars = true]),' % (DOSSIER, table)]


def m_types(etape, cols):
    types = ", ".join('{"%s", %s}' % (c, M_TYPES[t]) for c, t in cols)
    return ["    // Fixe le type de chaque colonne",
            '    Types = Table.TransformColumnTypes(%s, {%s}, "en-US")' % (etape, types)]


def m_vue(table, cols):
    """DirectQuery: the bi_ view already holds the final columns, Power Query only chooses them."""
    names = ", ".join('"%s"' % c for c, _ in cols)
    return (["let"] + source(table)
            + ["    // Garde seulement les colonnes utiles aux indicateurs", "    Colonnes = Table.SelectColumns(Source, {%s})"
               % names, "in", "    Colonnes"])


def m_table(table, cols):
    if DQ:
        return m_vue(table, cols + AJOUTS.get(table, []))
    names = ", ".join('"%s"' % c for c, _ in cols)
    lines = ["let"] + source(table) + [
        "    // Garde seulement les colonnes utiles aux indicateurs (jamais le pseudonyme du patient)",
        "    Colonnes = Table.SelectColumns(Source, {%s})," % names]
    last = "Colonnes"
    dates = [c for c, t in cols if t == "d"]
    if dates:
        lines.append("    // Remplace les dates vides par null avant de les typer")
        lines.append("    Vides = Table.TransformColumns(Colonnes, {%s}),"
                     % ", ".join('{"%s", each if _ = "" then null else _}' % c for c in dates))
        last = "Vides"
    lines += m_types(last, cols)
    last = "Types"
    for col, table_corr in CORRECTIONS.items():
        if col in [c for c, _ in cols]:
            rec = ", ".join('#"%s" = "%s"' % (a, b) for a, b in table_corr.items())
            lines[-1] += ","
            lines += ["    // Rétablit les accents des libellés les plus fréquents",
                      "    Corrections = [%s]," % rec,
                      '    Libelles = Table.TransformColumns(Types, {{"%s", each if _ = null then null '
                      'else Record.FieldOrDefault(Corrections, _, _), type text}})' % col]
            last = "Libelles"
    if table == "dim_temps":
        lines[-1] += ","
        lines += ["    // Ajoute le premier jour du mois, pour un axe des mois qui enchaîne les années",
                  '    Mois = Table.AddColumn(%s, "debut_mois", each if [date_jour] = null then null '
                  'else Date.StartOfMonth([date_jour]), type date)' % last]
        last = "Mois"
    if table == "dim_patient":
        lines[-1] += ","
        lines += ["    // Ajoute un libellé lisible du sexe",
                  '    Sexe = Table.AddColumn(%s, "libelle_sexe", each if [sexe] = "M" then "Homme" '
                  'else if [sexe] = "F" then "Femme" else "Inconnu", type text)' % last]
        last = "Sexe"
    return lines + ["in", "    " + last]


def m_agregat(table, cols):
    if DQ:
        return m_vue(table, cols)
    if not IMPALA:
        names = ", ".join('"%s"' % c for c, _ in cols)
        return (["let"] + source(table) + ["    Colonnes = Table.SelectColumns(Source, {%s})," % names]
                + m_types("Colonnes", cols) + ["in", "    Types"])
    if table == "agg_deces_region":
        corps = source("fait_deces") + [
            '    Colonnes = Table.SelectColumns(Source, {"annee_deces", "id_region", "nb_deces"}),',
            "    // Impala fait la somme par année et par région : un millier de lignes au lieu de plusieurs millions",
            '    Regroupe = Table.Group(Colonnes, {"annee_deces", "id_region"}, '
            '{{"nb_deces", each List.Sum([nb_deces]), type number}}),']
        last = "Regroupe"
    elif table == "agg_satisfaction_region":
        corps = source("fait_satisfaction") + [
            '    Colonnes = Table.SelectColumns(Source, {"id_temps", "id_region", "nb_avis", "note_globale"}),',
            "    // L'année se lit dans la clé du jour (AAAAMMJJ)",
            '    Annee = Table.AddColumn(Colonnes, "annee", each Number.IntegerDivide([id_temps], 10000), Int64.Type),',
            "    // Ne compte que les avis qui ont une note, et pondère chaque note par son nombre d'avis",
            '    Notes = Table.AddColumn(Annee, "avis_notes", each if [note_globale] = null then 0 else [nb_avis], '
            'Int64.Type),',
            '    Ponderees = Table.AddColumn(Notes, "notes_ponderees", each if [note_globale] = null then 0 '
            'else [note_globale] * [nb_avis], type number),',
            "    // Impala regroupe par année et par région",
            '    Regroupe = Table.Group(Ponderees, {"annee", "id_region"}, {'
            '{"nb_etablissements", each Table.RowCount(_), Int64.Type}, '
            '{"nb_avis", each List.Sum([nb_avis]), Int64.Type}, '
            '{"nb_avis_notes", each List.Sum([avis_notes]), Int64.Type}, '
            '{"somme_notes_ponderees", each List.Sum([notes_ponderees]), type number}}),']
        last = "Regroupe"
    else:
        corps = source("fait_consultation") + [
            '    Colonnes = Table.SelectColumns(Source, {"id_temps"}),',
            "    // Impala compte les consultations de chaque jour : c'est le total du groupe, que la sécurité ne filtre pas",
            '    Regroupe = Table.Group(Colonnes, {"id_temps"}, {{"nb_consultations", each Table.RowCount(_), Int64.Type}}),']
        last = "Regroupe"
    return ["let"] + corps + m_types(last, cols) + ["in", "    Types"]


def m_population():
    lignes = list(csv.DictReader(open(os.path.join(ICI, "population_regions.csv"), encoding="utf-8"), delimiter=";"))
    valeurs = ", ".join('{%s, "%s", %s}' % (l["annee"], l["code_region"], l["population"]) for l in lignes)
    return ["let",
            "    // Population au 1er janvier de chaque région, de 2010 à 2020",
            "    // Source : Insee, estimations de population (fichier estim-pop-nreg-sexe-gca-1975-2023), Licence ouverte",
            "    Source = #table(type table [annee = Int64.Type, code_region = text, population = Int64.Type], {%s})"
            % valeurs,
            "in", "    Source"]


def column(table, name, t):
    col = {"name": name,
           "dataType": {"i": "int64", "s": "string", "d": "dateTime", "n": "double"}[t],
           "sourceColumn": name, "lineageTag": tag(table, name), "summarizeBy": "none",
           "annotations": [{"name": "SummarizationSetBy", "value": "User"}]}
    if t == "d":
        col["formatString"] = "Short Date"
        col["annotations"].append({"name": "UnderlyingDateTimeDataType", "value": "Date"})
    elif t == "i":
        col["formatString"] = "0"
    elif t == "n":
        col["annotations"].append({"name": "PBI_FormatHint", "value": '{"isGeneralNumber":true}'})
    if name.startswith("id_"):
        col["isHidden"] = True
    if (table, name) in SORT_BY:
        col["sortByColumn"] = SORT_BY[(table, name)]
    return col


def mode(table):
    """Storage mode: everything read from Impala stays in the lake in DirectQuery, except the small dimensions."""
    if not DQ or table == "population":
        return "import"
    return "dual" if table in DUAL else "directQuery"


def table_m(table, cols, lignes, description=None, hidden=False):
    columns = [column(table, c, t) for c, t in cols]
    if table == "dim_temps":
        mois = column(table, "debut_mois", "d")
        mois["formatString"] = "MMM yyyy"
        columns.append(mois)
    if table == "dim_patient":
        columns.append(column(table, "libelle_sexe", "s"))
    if table == "dim_etablissement":
        region = column(table, "libelle_region", "s")
        if not DQ:
            # Without the views, the region label comes from dim_region through the relationship.
            del region["sourceColumn"]
            region.update({"type": "calculated", "isDataTypeInferred": True,
                           "expression": 'VAR r = RELATED(dim_region[libelle_region]) '
                                         'RETURN IF(ISBLANK(r), "Inconnu", r)'})
        columns.append(region)
    t = {"name": table, "lineageTag": tag(table), "columns": columns,
         "partitions": [{"name": "%s-%s" % (table, tag(table, "p")), "mode": mode(table),
                         "source": {"type": "m", "expression": lignes}}],
         "annotations": [{"name": "PBI_NavigationStepName", "value": "Navigation"},
                         {"name": "PBI_ResultType", "value": "Table"}]}
    if description:
        t["description"] = description
    if hidden:
        t["isHidden"] = True
    return t


def calc_table(name, expression, cols, hidden=True):
    return {"name": name, "lineageTag": tag(name), "isHidden": hidden,
            "columns": [{"type": "calculatedTableColumn", "name": c, "dataType": "int64",
                         "isNameInferred": True, "isDataTypeInferred": True, "sourceColumn": src,
                         "formatString": "0", "lineageTag": tag(name, c), "summarizeBy": "none",
                         "isHidden": hidden or c == "Colonne",
                         "annotations": [{"name": "SummarizationSetBy", "value": "User"}]} for c, src in cols],
            "partitions": [{"name": name, "mode": "import", "source": {"type": "calculated", "expression": expression}}],
            "annotations": [{"name": "PBI_Id", "value": tag(name, "id").replace("-", "")}]}


PCT, PART, INT, DEC, ECART, TXT = ("0.00 %;-0.00 %;0.00 %", "0.0 %;-0.0 %;0.0 %", "#,0", "0.00",
                                   "+0.00;-0.00;0.00", None)


def premier(colonne, mesure):
    """Share of the first value of a column (the most frequent diagnosis, for example)."""
    return "DIVIDE(MAXX(VALUES(%s), %s), %s)" % (colonne, mesure, mesure)


GROUPE = ("\nVAR an = SELECTEDVALUE(dim_temps[annee])\nVAR mo = SELECTEDVALUE(dim_temps[mois])\n"
          "VAR actifs = IF(NOT ISBLANK(mo),\n"
          "    LOOKUPVALUE(b3_groupe_mois[patients_actifs], b3_groupe_mois[annee], an, b3_groupe_mois[mois], mo),\n"
          "    LOOKUPVALUE(b3_groupe_annee[patients_actifs], b3_groupe_annee[annee], an))\n"
          "VAR hospitalises = IF(NOT ISBLANK(mo),\n"
          "    LOOKUPVALUE(b3_groupe_mois[patients_hospitalises], b3_groupe_mois[annee], an, b3_groupe_mois[mois], mo),\n"
          "    LOOKUPVALUE(b3_groupe_annee[patients_hospitalises], b3_groupe_annee[annee], an))\n"
          "RETURN DIVIDE(hospitalises, actifs)")
B3, B5 = "[B3 Taux d'hospitalisation]", "[B5 Taux d'hospitalisation (secret statistique)]"
# Stays have no professional: when a specialty or a professional is chosen, the stay figures are left empty.
SANS_PRO = "ISFILTERED(dim_professionnel)"
# In a table, 0 rather than an empty cell when the row has consultations or stays but none of the counted ones.
ZERO = "IF(NOT ISBLANK([Consultations]) || NOT ISBLANK([Séjours]), %s + 0)"
PREMIER_ETAB = ("FILTER(VALUES(fait_consultation[id_etablissement]), fait_consultation[id_etablissement] <> -1)")

MEASURES = [
    # 1. Consultations (B1, B2, B6)
    ("1 Consultations", "Consultations", "COUNTROWS(fait_consultation)", INT),
    ("1 Consultations", "Consultations non rattachées",
     "CALCULATE([Consultations], dim_etablissement[id_etablissement] = -1)", INT),
    ("1 Consultations", "Consultations rattachées", "[Consultations] - [Consultations non rattachées]", INT),
    ("1 Consultations", "Consultations du groupe", "SUM(agg_consultation_jour[nb_consultations])", INT),
    ("1 Consultations", "B1 Part de l'établissement", "DIVIDE([Consultations], [Consultations du groupe])", PCT),
    ("1 Consultations", "Part du 1er établissement",
     "DIVIDE(MAXX(%s, CALCULATE(COUNTROWS(fait_consultation))), [Consultations du groupe])" % PREMIER_ETAB, PCT),
    ("1 Consultations", "B1 Part affichée",
     "VAR b = [B1 Part de l'établissement]\nRETURN IF(b < 0.9999, b, [Part du 1er établissement])", PCT),
    ("1 Consultations", "Part non rattachée", "DIVIDE([Consultations non rattachées], [Consultations du groupe])",
     PCT),
    ("1 Consultations", "Consultations par an",
     "CALCULATE([Consultations], REMOVEFILTERS(dim_temps), TREATAS(VALUES('Années'[annee]), dim_temps[annee]))",
     INT),
    ("1 Consultations", "B2 Part du diagnostic",
     "DIVIDE([Consultations], CALCULATE([Consultations], ALL(dim_diagnostic)))", PCT),
    ("1 Consultations", "B6 Part du professionnel",
     "DIVIDE([Consultations], CALCULATE([Consultations], ALL(dim_professionnel)))", PCT),
    ("1 Consultations", "Diagnostics différents", "DISTINCTCOUNT(fait_consultation[id_diagnostic])", INT),
    ("1 Consultations", "Part du 1er diagnostic", premier("dim_diagnostic[libelle_diagnostic]", "[Consultations]"),
     PCT),
    ("1 Consultations", "Part de la 1re spécialité", premier("dim_professionnel[specialite]", "[Consultations]"),
     PART),
    ("1 Consultations", "Spécialité en tête",
     "MAXX(TOPN(1, VALUES(dim_professionnel[specialite]), [Consultations]), dim_professionnel[specialite])", TXT),
    # 2. Hospitalisations (B3, B4, B5), empty when a professional is chosen, rates hidden under 10 patients
    ("2 Hospitalisations", "Séjours", "IF(%s, BLANK(), COUNTROWS(fait_hospitalisation))" % SANS_PRO, INT),
    ("2 Hospitalisations", "Patients actifs",
     "COUNTROWS(DISTINCT(UNION(VALUES(fait_consultation[id_patient]), VALUES(fait_hospitalisation[id_patient]))))",
     INT),
    ("2 Hospitalisations", "Patients hospitalisés",
     "IF(%s, BLANK(), DISTINCTCOUNT(fait_hospitalisation[id_patient]))" % SANS_PRO, INT),
    ("2 Hospitalisations", "B3 Taux d'hospitalisation",
     "VAR h = [Patients hospitalisés]\nRETURN IF(%s || h < 10, BLANK(), DIVIDE(h, [Patients actifs]))" % SANS_PRO, PCT),
    ("2 Hospitalisations", "B3 Taux du groupe", GROUPE, PCT),
    ("2 Hospitalisations", "B4 Part du diagnostic (séjours)",
     "DIVIDE([Séjours], CALCULATE([Séjours], ALL(dim_diagnostic)))", PCT),
    ("2 Hospitalisations", "Part du 1er diagnostic de séjour",
     premier("dim_diagnostic[libelle_diagnostic]", "[Séjours]"), PCT),
    ("2 Hospitalisations", "B5 Taux d'hospitalisation (secret statistique)", B3, PCT),
    ("2 Hospitalisations", "Taux des hommes", 'CALCULATE(%s, dim_patient[sexe] = "M")' % B3, PCT),
    ("2 Hospitalisations", "Taux des femmes", 'CALCULATE(%s, dim_patient[sexe] = "F")' % B3, PCT),
    # 3. Décès (B7): the year comes from the "Année des décès" list, 2010 at the earliest
    ("3 Décès", "B7 Décès",
     "CALCULATE(SUM(agg_deces_region[nb_deces]), KEEPFILTERS(agg_deces_region[annee_deces] >= 2010))", INT),
    ("3 Décès", "Décès en 2010",
     "CALCULATE(SUM(agg_deces_region[nb_deces]), agg_deces_region[annee_deces] = 2010)", INT),
    ("3 Décès", "Décès par an",
     "CALCULATE(SUM(agg_deces_region[nb_deces]), REMOVEFILTERS(agg_deces_region[annee_deces]),\n"
     "    TREATAS(VALUES('Années'[annee]), agg_deces_region[annee_deces]), agg_deces_region[annee_deces] <= 2019)",
     INT),
    ("3 Décès", "Population",
     "CALCULATE(SUM(population[population]), TREATAS(VALUES(agg_deces_region[annee_deces]), population[annee]),\n"
     "    KEEPFILTERS(population[annee] >= 2010))", INT),
    ("3 Décès", "Décès pour 100 000 habitants",
     'DIVIDE(CALCULATE([B7 Décès], NOT dim_region[code_region] IN {"INC", "COM", "ETR"}), [Population]) * 100000',
     "#,0.0"),
    # 4. Satisfaction (B8): the year comes from the "Année de la satisfaction" list (2019 or 2020)
    ("4 Satisfaction", "B8 Satisfaction",
     "DIVIDE(SUM(agg_satisfaction_region[somme_notes_ponderees]), SUM(agg_satisfaction_region[nb_avis_notes]))",
     DEC),
    ("4 Satisfaction", "Score par année",
     "CALCULATE([B8 Satisfaction], REMOVEFILTERS(agg_satisfaction_region[annee]),\n"
     "    TREATAS(VALUES('Années'[annee]), agg_satisfaction_region[annee]))", DEC),
    ("4 Satisfaction", "Évolution du score",
     "VAR an = SELECTEDVALUE(agg_satisfaction_region[annee])\n"
     "VAR avant = CALCULATE([B8 Satisfaction], agg_satisfaction_region[annee] = an - 1)\n"
     "RETURN IF(NOT ISBLANK(an) && NOT ISBLANK(avant) && NOT ISBLANK([B8 Satisfaction]), [B8 Satisfaction] - avant)",
     ECART),
    ("4 Satisfaction", "Écart au national",
     "IF(NOT ISBLANK([B8 Satisfaction]), [B8 Satisfaction] - CALCULATE([B8 Satisfaction], ALL(dim_region)))", ECART),
    ("4 Satisfaction", "Écart au national (extrêmes)",
     "VAR t = FILTER(ALL(dim_region[libelle_region]), NOT ISBLANK([Écart au national]))\n"
     "VAR r = RANKX(t, [Écart au national], , DESC)\n"
     "RETURN IF(NOT ISBLANK([Écart au national]) && (r <= 3 || r > COUNTROWS(t) - 3), [Écart au national])", ECART),
    # 5. Texts shown under the figures
    ("5 Textes", "Texte B1",
     "VAR b = [B1 Part de l'établissement]\n"
     "VAR premier = MAXX(TOPN(1, %s, CALCULATE(COUNTROWS(fait_consultation))), fait_consultation[id_etablissement])\n"
     'RETURN IF(b < 0.9999, FORMAT([Consultations], "#,0") & " consultations sur " '
     '& FORMAT([Consultations du groupe], "#,0"),\n'
     '    "Le plus actif : " & LOOKUPVALUE(dim_etablissement[raison_sociale], dim_etablissement[id_etablissement], premier))'
     % PREMIER_ETAB, TXT),
    ("5 Textes", "Texte B2", '"Sur " & FORMAT([Diagnostics différents], "#,0") & " diagnostics"', TXT),
    ("5 Textes", "Texte B3",
     "VAR h = [Patients hospitalisés]\n"
     'RETURN IF(%s, "Les séjours ne sont pas liés à un professionnel",\n'
     '    IF(ISBLANK([Séjours]) && NOT ISBLANK([Consultations]), "Aucun séjour dans les données pour cette période",\n'
     '    IF(h < 10, "Masqué : moins de 10 patients hospitalisés",\n'
     '    FORMAT(h, "#,0") & " patients sur " & FORMAT([Patients actifs], "#,0"))))' % SANS_PRO, TXT),
    ("5 Textes", "Texte B4",
     'IF(%s, "Les séjours ne sont pas liés à un professionnel", "Sur " & FORMAT([Séjours], "#,0") & " séjours")'
     % SANS_PRO, TXT),
    ("5 Textes", "Texte B5",
     'IF(ISBLANK([Taux des hommes]), "Hommes masqués : moins de 10 patients hospitalisés",\n'
     '    IF(ISBLANK([Taux des femmes]), "Hommes. Femmes masquées : moins de 10 patients",\n'
     '    "Hommes, contre " & FORMAT([Taux des femmes], "0.00 %") & " pour les femmes"))', TXT),
    ("5 Textes", "Texte B6", '"Spécialité : " & [Spécialité en tête]', TXT),
    ("5 Textes", "Texte séjours",
     'IF(%s, "Les séjours ne sont pas liés à un professionnel",\n'
     '    IF(ISBLANK([Séjours]) && NOT ISBLANK([Consultations]), "Aucun séjour dans les données pour cette période",\n'
     '    "Hospitalisations de la période"))' % SANS_PRO, TXT),
    ("5 Textes", "Texte année d'activité",
     "VAR partielle = ISFILTERED(dim_temps[annee]) && NOT ISEMPTY(FILTER(VALUES(dim_temps[annee]), "
     "dim_temps[annee] IN {2015, 2023}))\n"
     'RETURN IF(partielle, "Année partielle : données de juin 2015 à mars 2023", "Consultations de la période")',
     TXT),
    ("5 Textes", "Texte décès",
     "VAR n = COUNTROWS(FILTER(VALUES(agg_deces_region[annee_deces]), agg_deces_region[annee_deces] >= 2010))\n"
     "VAR an = MAX(agg_deces_region[annee_deces])\n"
     "VAR e = DIVIDE([B7 Décès], [Décès en 2010]) - 1\n"
     'RETURN IF(n > 1, "Total de " & n & " années",\n'
     '    IF(an = 2020, "Année incomplète : le fichier s\'arrête début 2020",\n'
     '    IF(an = 2010, "Année de référence",\n'
     '    IF(e >= 0, "▲ ", "▼ ") & FORMAT(ABS(e), "0.0 %") & " depuis 2010")))', TXT),
    ("5 Textes", "Texte taux de décès",
     'FORMAT([Décès pour 100 000 habitants], "#,0") & " décès pour 100 000 habitants"', TXT),
    ("5 Textes", "Texte satisfaction",
     "VAR an = SELECTEDVALUE(agg_satisfaction_region[annee])\n"
     "VAR e = [Évolution du score]\n"
     'RETURN IF(ISBLANK([B8 Satisfaction]), "Pas de score pour cette sélection",\n'
     '    IF(ISBLANK(an), "Score de 2019 et 2020 réunis",\n'
     '    IF(ISBLANK(e), "Première année des données",\n'
     '    IF(e >= 0, "▲ ", "▼ ") & FORMAT(ABS(e), "0.00") & " point depuis " & (an - 1))))', TXT),
    ("5 Textes", "Texte taux", 'IF(ISBLANK([B3 Taux du groupe]), "Taux du groupe : choisir une seule année", '
                               '"Groupe : " & FORMAT([B3 Taux du groupe], "0.00 %"))', TXT),
    # 6. Colours read by the charts and the tables
    ("6 Couleurs", "Couleur écart", 'IF([Écart au national] >= 0, "%s", "%s")' % (SECOND, ALERTE), TXT),
    ("6 Couleurs", "Couleur sans établissement",
     'IF(SELECTEDVALUE(dim_etablissement[libelle_region]) = "Inconnu", "%s", "%s")' % (ALERTE, GRIS), TXT),
    # 7. Table columns: 0 rather than an empty cell
    ("7 Tableaux", "Séjours (tableau)", "IF(%s, BLANK(), %s)" % (SANS_PRO, ZERO % "[Séjours]"), INT),
    ("7 Tableaux", "Part des séjours (tableau)",
     "IF(%s, BLANK(), %s)" % (SANS_PRO, ZERO % "[B4 Part du diagnostic (séjours)]"), PCT),
    ("7 Tableaux", "Patients hospitalisés (tableau)",
     "IF(%s, BLANK(), %s)" % (SANS_PRO, ZERO % "[Patients hospitalisés]"), INT),
]

DESCRIPTIONS = {
    "B3 Taux d'hospitalisation": "Parmi les patients venus sur la période (consultation ou séjour), part de ceux "
                                 "qui ont été hospitalisés. Vide sous 10 patients hospitalisés (secret statistique) "
                                 "et quand une spécialité est choisie, car les séjours n'ont pas de professionnel.",
    "B3 Taux du groupe": "Taux du groupe entier, lu dans les tables b3_groupe_mois et b3_groupe_annee, "
                         + ("vues Impala qu'aucun rôle ne filtre." if DQ else
                            "calculées à l'actualisation, donc avant la RLS.") + " Disponible pour un mois ou une année.",
    "B1 Part de l'établissement": "Consultations visibles divisées par les consultations de tout le groupe "
                                  "(agg_consultation_jour, que la RLS ne filtre pas).",
    "Décès pour 100 000 habitants": "Décès des 18 régions divisés par leur population INSEE au 1er janvier, "
                                    "pour les mêmes années.",
}


def build_model():
    tables = [table_m(t, c, m_table(t, c)) for t, c in TABLES]
    tables += [table_m(t, c, m_agregat(t, c),
                       "Vue Impala bi_%s : regroupement recalculé par Impala à chaque requête." % t if DQ
                       else "Agrégat calculé par Impala au chargement (regroupement sur le Gold).")
               for t, c in AGREGATS]
    tables.append(table_m("population", [("annee", "i"), ("code_region", "s"), ("population", "i")], m_population(),
                          "Population INSEE au 1er janvier, par région, de 2010 à 2020."))
    mesures = calc_table("Mesures", 'ROW("Colonne", 0)', [("Colonne", "[Colonne]")], hidden=False)
    mesures["measures"] = [dict({"name": n, "expression": e, "displayFolder": folder, "lineageTag": tag("m", n)},
                                **({"formatString": f} if f else {}),
                                **({"description": DESCRIPTIONS[n]} if n in DESCRIPTIONS else {}))
                           for folder, n, e, f in MEASURES]
    tables.append(mesures)
    b3 = [("b3_groupe_mois", [("annee", "i"), ("mois", "i"), ("patients_actifs", "i"), ("patients_hospitalises", "i")]),
          ("b3_groupe_annee", [("annee", "i"), ("patients_actifs", "i"), ("patients_hospitalises", "i")])]
    if DQ:
        # Group rate computed by Impala in the bi_b3_ views, which no security role filters.
        tables += [table_m(t, c, m_vue(t, c), "Vue Impala bi_%s : taux du groupe, que la RLS ne filtre pas." % t,
                           hidden=True) for t, c in b3]
    else:
        # Group rate computed at refresh, before the security role applies (the stays count without the guard).
        base = ('ADDCOLUMNS(%s, "patients_actifs", [Patients actifs], '
                '"patients_hospitalises", CALCULATE(DISTINCTCOUNT(fait_hospitalisation[id_patient])))')
        tables.append(calc_table("b3_groupe_mois",
                                 "FILTER(" + base % "SUMMARIZE(dim_temps, dim_temps[annee], dim_temps[mois])"
                                 + ", [patients_actifs] > 0)",
                                 [("annee", "dim_temps[annee]"), ("mois", "dim_temps[mois]"),
                                  ("patients_actifs", "[patients_actifs]"),
                                  ("patients_hospitalises", "[patients_hospitalises]")]))
        tables.append(calc_table("b3_groupe_annee",
                                 "FILTER(" + base % "VALUES(dim_temps[annee])" + ", [patients_actifs] > 0)",
                                 [("annee", "dim_temps[annee]"), ("patients_actifs", "[patients_actifs]"),
                                  ("patients_hospitalises", "[patients_hospitalises]")]))
    tables.append(calc_table("Années", 'SELECTCOLUMNS(GENERATESERIES(2010, 2023, 1), "annee", [Value])',
                             [("annee", "[annee]")]))
    requetes = ([t for t, _ in TABLES] + [t for t, _ in AGREGATS] + ["population"]
                + ([t for t, _ in b3] if DQ else []))
    model = {
        "culture": "fr-FR",
        "dataAccessOptions": {"legacyRedirects": True, "returnErrorValuesAsNull": True},
        "defaultPowerBIDataSourceVersion": "powerBI_V3",
        "sourceQueryCulture": "fr-FR",
        "tables": tables,
        "relationships": [{"name": tag("r", f, fc), "fromTable": f, "fromColumn": fc, "toTable": t, "toColumn": tc}
                          for f, fc, t, tc in RELATIONS],
        "annotations": [
            {"name": "PBI_QueryOrder", "value": json.dumps(
                (["Serveur", "Base"] if IMPALA else []) + requetes)},
            {"name": "__PBI_TimeIntelligenceEnabled", "value": "0"},
            {"name": "PBIDesktopVersion", "value": "2.115.663.0 (23.03)"},
        ],
        "roles": [{"name": "Direction démo Bretagne", "modelPermission": "read",
                   "description": "Démonstration de la RLS : une direction qui ne voit que les "
                                  "établissements de Bretagne (code région 53).",
                   "tablePermissions": [{"name": "dim_etablissement", "filterExpression": '[code_region] = "53"'}]}],
    }
    if DQ:
        # At most 4 queries at a time to Impala: the single-node VM times out when a page sends 10 at once.
        model["dataSourceDefaultMaxConnections"] = 4
    if IMPALA:
        model["expressions"] = [
            {"name": n, "kind": "m", "lineageTag": tag("param", n),
             "expression": '"%s" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]' % v,
             "annotations": [{"name": "PBI_NavigationStepName", "value": "Navigation"},
                             {"name": "PBI_ResultType", "value": "Text"}]}
            for n, v in (("Serveur", "quickstart.cloudera:21050"), ("Base", "gold"))]
    return {"name": tag("database"), "compatibilityLevel": 1550, "model": model}


# ---------------------------------------------------------------- report helpers

def lit(v):
    return {"expr": {"Literal": {"Value": v}}}


def txt(s):
    return lit("'" + s.replace("'", "''") + "'")


def color(c):
    return {"solid": {"color": lit("'" + c + "'")}}


def C(table, prop):
    return ("Column", table, prop)


def Mz(prop):
    return ("Measure", "Mesures", prop)


def qref(f):
    return "%s.%s" % (f[1], f[2])


def query(fields, order=None, desc=True):
    aliases, frm = {}, []
    for f in fields + ([order] if order else []):
        if f[1] not in aliases:
            a = f[1][0].lower() + str(len(aliases))
            aliases[f[1]] = a
            frm.append({"Name": a, "Entity": f[1], "Type": 0})

    def expr(f):
        return {f[0]: {"Expression": {"SourceRef": {"Source": aliases[f[1]]}}, "Property": f[2]}}

    q = {"Version": 2, "From": frm, "Select": [dict(expr(f), Name=qref(f)) for f in fields]}
    if order:
        q["OrderBy"] = [{"Direction": 2 if desc else 1, "Expression": expr(order)}]
    return q


def entity_expr(f):
    return {f[0]: {"Expression": {"SourceRef": {"Entity": f[1]}}, "Property": f[2]}}


def habillage(fond=None, bord=None, titre=None):
    """Container formatting: background, border with rounded corners and title, all optional."""
    off = [{"properties": {"show": lit("false")}}]
    vc = {"background": [{"properties": {"show": lit("true"), "color": color(fond), "transparency": lit("0D")}}]
          if fond else off,
          "border": [{"properties": {"show": lit("true"), "color": color(bord), "radius": lit("8D")}}] if bord else off,
          "title": [{"properties": {"show": lit("true"), "text": txt(titre), "fontColor": color(TEXTE),
                                    "fontSize": lit("11D")}}] if titre else off}
    if not titre:
        vc["visualHeader"] = off
    return vc


def couleur_mesure(nom, propriete="fill"):
    """Colour read from a measure that returns a hex code (conditional formatting by field value)."""
    return {propriete: {"solid": {"color": {"expr": entity_expr(Mz(nom))}}}}


def gradient(measure):
    return [{"properties": {"fill": {"solid": {"color": {"expr": {"FillRule": {
        "Input": entity_expr(measure),
        "FillRule": {"linearGradient2": {"min": {"color": {"Literal": {"Value": "'%s'" % CLAIR}}},
                                         "max": {"color": {"Literal": {"Value": "'%s'" % ACCENT}}},
                                         "nullColoringStrategy": {"strategy": {"Literal": {"Value": "'asZero'"}}}}}}}}}}},
             "selector": {"data": [{"dataViewWildcard": {"matchingOption": 1}}]}}]


def divergent(measure):
    """Colours centred on zero: red for negative gaps, light grey at zero, blue for positive gaps."""
    def lit_c(c):
        return {"color": {"Literal": {"Value": "'%s'" % c}}}
    return [{"properties": {"fill": {"solid": {"color": {"expr": {"FillRule": {
        "Input": entity_expr(measure),
        "FillRule": {"linearGradient3": {"min": lit_c(ALERTE),
                                         "mid": dict(lit_c("#E9ECF1"), value={"Literal": {"Value": "0D"}}),
                                         "max": lit_c(SECOND),
                                         "nullColoringStrategy": {"strategy": {"Literal": {"Value": "'asZero'"}}}}}}}}}}},
             "selector": {"data": [{"dataViewWildcard": {"matchingOption": 1}}]}}]


def topn_filter(cat, measure, n):
    a, s = cat[1][0].lower(), "subquery"
    return {"name": "Filtre" + hashlib.md5(qref(cat).encode()).hexdigest()[:12],
            "expression": entity_expr(cat),
            "filter": {"Version": 2, "From": [
                {"Name": s, "Expression": {"Subquery": {"Query": {
                    "Version": 2,
                    "From": [{"Name": a, "Entity": cat[1], "Type": 0}, {"Name": "m", "Entity": "Mesures", "Type": 0}],
                    "Select": [{"Column": {"Expression": {"SourceRef": {"Source": a}}, "Property": cat[2]},
                                "Name": "field"}],
                    "OrderBy": [{"Direction": 2, "Expression": {"Measure": {
                        "Expression": {"SourceRef": {"Source": "m"}}, "Property": measure[2]}}}],
                    "Top": n}}}, "Type": 2},
                {"Name": a, "Entity": cat[1], "Type": 0}],
                "Where": [{"Condition": {"In": {
                    "Expressions": [{"Column": {"Expression": {"SourceRef": {"Source": a}}, "Property": cat[2]}}],
                    "Table": {"SourceRef": {"Source": s}}}}}]},
            "type": "TopN", "howCreated": 1}


def year_min_filter(year, f):
    return {"name": "FiltreAnnees", "expression": entity_expr(f),
            "filter": {"Version": 2, "From": [{"Name": "d", "Entity": f[1], "Type": 0}],
                       "Where": [{"Condition": {"Comparison": {
                           "ComparisonKind": 2,
                           "Left": {"Column": {"Expression": {"SourceRef": {"Source": "d"}}, "Property": f[2]}},
                           "Right": {"Literal": {"Value": "%dL" % year}}}}}]},
            "type": "Advanced", "howCreated": 1}


def section_id(page):
    return "ReportSection" + hashlib.md5(("chu" + page).encode()).hexdigest()[:20]


SANS = [{"properties": {"show": lit("false")}}]
MULTI = [{"properties": {"singleSelect": lit("false"), "strictSingleSelect": lit("false"),
                         "selectAllCheckboxEnabled": lit("true")}}]


class Page:
    def __init__(self, name, ordinal, titre, sous_titre):
        self.name, self.ordinal, self.items = name, ordinal, []
        self.text(16, 6, 1000, 46, [(titre, 18, TEXTE, True)])
        self.text(16, 40, 1248, 38, [(sous_titre, 10, DISCRET, False)])

    def add(self, x, y, w, h, sv, filters=None):
        n = hashlib.md5(("%s|%d" % (self.name, len(self.items))).encode()).hexdigest()[:20]
        z = len(self.items) * 1000
        cfg = {"name": n, "layouts": [{"id": 0, "position": {"x": x, "y": y, "z": z, "width": w, "height": h}}],
               "singleVisual": sv}
        self.items.append({"x": x, "y": y, "z": z, "width": w, "height": h,
                           "config": json.dumps(cfg, ensure_ascii=False),
                           "filters": json.dumps(filters or [], ensure_ascii=False)})

    def section(self):
        return {"id": self.ordinal, "name": section_id(self.name), "displayName": self.name, "filters": "[]",
                "ordinal": self.ordinal, "visualContainers": self.items, "config": "{}", "displayOption": 1,
                "width": 1280, "height": 720}

    # ---- text and figures
    def text(self, x, y, w, h, paragraphs, fond=None, bord=None):
        """paragraphs: list of (text, size_pt, color, bold)."""
        ps = [{"textRuns": [{"value": t, "textStyle": {"fontFamily": "Segoe UI Semibold" if b else "Segoe UI",
                                                       "fontSize": "%dpt" % s, "color": c}}]}
              for t, s, c, b in paragraphs]
        self.add(x, y, w, h, {"visualType": "textbox", "drillFilterOtherVisuals": True,
                              "objects": {"general": [{"properties": {"paragraphs": ps}}]},
                              "vcObjects": habillage(fond, bord)})

    def cadre(self, x, y, w, h):
        """Empty white card used as the background of a group of visuals."""
        self.text(x, y, w, h, [("", 10, TEXTE, False)], fond=CARTE, bord=TRAIT)

    def valeur(self, x, y, w, h, measure, size, col):
        """A figure or a text measure, left aligned (multi-row card without its side bar)."""
        self.add(x, y, w, h, {
            "visualType": "multiRowCard", "projections": {"Values": [{"queryRef": qref(measure)}]},
            "prototypeQuery": query([measure]), "drillFilterOtherVisuals": True,
            "objects": {"dataLabels": [{"properties": {"color": color(col), "fontSize": lit("%dD" % size),
                                                       "fontFamily": txt("Segoe UI Semibold" if size > 14 else "Segoe UI")}}],
                        "categoryLabels": SANS,
                        "card": [{"properties": {"barShow": lit("false"), "outline": txt("None"),
                                                 "cardPadding": lit("0D")}}]},
            "vcObjects": habillage()})

    def chiffre(self, x, y, w, h, libelle, measure, contexte=None):
        """Key figure card: label, value and an optional line of context (text or text measure)."""
        self.cadre(x, y, w, h)
        self.text(x + 6, y + 2, w - 12, 30, [(libelle, 10, DISCRET, False)])
        self.valeur(x + 10, y + 24, w - 20, 50, measure, 20, TEXTE)
        if isinstance(contexte, str):
            self.text(x + 6, y + 62, w - 12, 32, [(contexte, 9, DISCRET, False)])
        elif contexte:
            self.valeur(x + 10, y + 63, w - 20, 32, contexte, 9, DISCRET)

    # ---- filters and navigation
    def filtre(self, x, y, w, col, titre, recherche=False, synchro=None):
        """Drop-down slicer accepting several values, with a search box for long lists,
        synchronised across pages when synchro is set."""
        sv = {"visualType": "slicer", "projections": {"Values": [{"queryRef": qref(col), "active": True}]},
              "prototypeQuery": query([col], order=col, desc=False), "drillFilterOtherVisuals": True,
              "columnProperties": {qref(col): {"displayName": titre}},
              "objects": {"data": [{"properties": {"mode": txt("Dropdown")}}], "selection": MULTI,
                          "header": [{"properties": {"fontColor": color(DISCRET), "textSize": lit("9D")}}],
                          "items": [{"properties": {"fontColor": color(TEXTE), "textSize": lit("10D")}}]},
              "vcObjects": habillage(CARTE, TRAIT)}
        if recherche:
            sv["objects"]["general"] = [{"properties": {"selfFilterEnabled": lit("true")}}]
        if synchro:
            sv["syncGroup"] = {"groupName": synchro, "fieldChanges": True, "filterChanges": True}
        self.add(x, y, w, 56, sv)

    def filtre_annee(self, x, y, w, f=C("dim_temps", "annee"), titre="Année", defaut=2019, minimum=2015,
                     synchro="annee", cache=False):
        """Year slicer: one or several years, a default year at start, years before `minimum` hidden,
        same years on every page. Used for the activity, the deaths and the satisfaction.
        cache=True keeps the slicer invisible: it still filters the page and follows the visible one."""
        selection = {"Version": 2, "From": [{"Name": "d", "Entity": f[1], "Type": 0}],
                     "Where": [{"Condition": {"In": {
                         "Expressions": [{"Column": {"Expression": {"SourceRef": {"Source": "d"}}, "Property": f[2]}}],
                         "Values": [[{"Literal": {"Value": "%dL" % defaut}}]]}}}]}
        self.add(x, y, w, 56, dict({
            "visualType": "slicer", "projections": {"Values": [{"queryRef": qref(f), "active": True}]},
            "prototypeQuery": query([f], order=f, desc=False), "drillFilterOtherVisuals": True,
            "columnProperties": {qref(f): {"displayName": titre}},
            "syncGroup": {"groupName": synchro, "fieldChanges": True, "filterChanges": True},
            "objects": {"data": [{"properties": {"mode": txt("Dropdown")}}], "selection": MULTI,
                        "general": [{"properties": {"filter": {"filter": selection}}}],
                        "header": [{"properties": {"fontColor": color(DISCRET), "textSize": lit("9D")}}],
                        "items": [{"properties": {"fontColor": color(TEXTE), "textSize": lit("10D")}}]},
            "vcObjects": habillage(CARTE, TRAIT)}, **({"display": {"mode": "hidden"}} if cache else {})),
            filters=[year_min_filter(minimum, f)] if minimum else None)

    def bouton(self, x, y, w, h, texte, page):
        """Text link, right aligned, that opens another page (« Voir le détail »)."""
        d = {"id": "default"}
        style = {"text": txt(texte), "fontColor": color(ACCENT), "fontSize": lit("10D"),
                 "fontFamily": txt("Segoe UI Semibold"), "horizontalAlignment": txt("right")}
        objets = {"icon": SANS,
                  "text": [{"properties": {"show": lit("true")}}, {"properties": style, "selector": d}],
                  "fill": [{"properties": {"show": lit("false")}},
                           {"properties": {"fillColor": color(ACCENT), "transparency": lit("0D")}, "selector": d}],
                  "outline": [{"properties": {"show": lit("false")}},
                              {"properties": {"lineColor": color(ACCENT), "weight": lit("1D"), "roundEdge": lit("14D")},
                               "selector": d}]}
        vc = habillage()
        vc["visualLink"] = [{"properties": {"show": lit("true"), "type": txt("PageNavigation"),
                                            "navigationSection": txt(section_id(page))}}]
        self.add(x, y, w, h, {"visualType": "actionButton", "drillFilterOtherVisuals": True, "objects": objets,
                              "vcObjects": vc})

    # ---- charts
    def ligne(self, x, y, w, h, cat, measures, titre=None, noms=None, mini=False, marqueurs=False, zero=True,
              pointilles=None):
        """Line chart starting at zero; zero=False gives a tighter axis with the value written on each point;
        mini=True gives a sparkline without axes; pointilles = a measure drawn as a dashed grey line."""
        axe = SANS if mini else [{"properties": {"showAxisTitle": lit("false")}}]
        valeurs = {"showAxisTitle": lit("false"), "labelDisplayUnits": lit("1D")}
        if zero:
            valeurs["start"] = lit("0D")
        styles = [{"properties": {"strokeWidth": lit("2D" if mini else "3D"),
                                  "showMarker": lit("true" if marqueurs else "false")}}]
        points = []
        if pointilles:
            styles.append({"properties": {"lineStyle": txt("dashed"), "strokeWidth": lit("2D")},
                           "selector": {"metadata": qref(pointilles)}})
            points.append({"properties": {"fill": color(DISCRET)}, "selector": {"metadata": qref(pointilles)}})
        sv = {"visualType": "lineChart",
              "projections": {"Category": [{"queryRef": qref(cat), "active": True}],
                              "Y": [{"queryRef": qref(m)} for m in measures]},
              "prototypeQuery": query([cat] + measures, order=cat, desc=False), "drillFilterOtherVisuals": True,
              "objects": {"categoryAxis": axe,
                          "valueAxis": [{"properties": {"show": lit("false"), "gridlineShow": lit("false")}}] if mini
                          else [{"properties": valeurs}],
                          "labels": [{"properties": {"show": lit("true" if not zero and not mini else "false"),
                                                     "labelDisplayUnits": lit("1D"), "fontSize": lit("8D")}}],
                          "legend": [{"properties": {"show": lit("true" if len(measures) > 1 else "false")}}],
                          "lineStyles": styles},
              "vcObjects": habillage(None if mini else CARTE, None if mini else TRAIT, titre)}
        if points:
            sv["objects"]["dataPoint"] = points
        if noms:
            sv["columnProperties"] = {qref(m): {"displayName": n} for m, n in zip(measures, noms)}
        self.add(x, y, w, h, sv)

    def barres(self, x, y, w, h, cat, measure, titre=None, couleur=None, top=None, infobulles=(), ordre=None,
               nom=None, colonnes=False):
        """Bars sorted by value (or by `ordre`), optionally coloured by a measure; colonnes=True for vertical bars."""
        champs = [cat, measure] + list(infobulles)
        proj = {"Category": [{"queryRef": qref(cat), "active": True}], "Y": [{"queryRef": qref(measure)}]}
        if infobulles:
            proj["Tooltips"] = [{"queryRef": qref(m)} for m in infobulles]
        objets = {"labels": [{"properties": {"show": lit("true"), "labelDisplayUnits": lit("1D"),
                                             "labelPosition": txt("OutsideEnd"), "fontSize": lit("9D")}}],
                  "valueAxis": [{"properties": {"show": lit("false"), "gridlineShow": lit("false")}}],
                  "categoryAxis": [{"properties": {"showAxisTitle": lit("false"), "fontSize": lit("9D"),
                                                   "maxMarginFactor": lit("45L")}}]}
        if couleur:
            objets["dataPoint"] = [{"properties": couleur_mesure(couleur),
                                    "selector": {"data": [{"dataViewWildcard": {"matchingOption": 1}}]}}]
        sv = {"visualType": "clusteredColumnChart" if colonnes else "clusteredBarChart", "projections": proj,
              "prototypeQuery": query(champs, order=ordre or measure, desc=not ordre),
              "drillFilterOtherVisuals": True, "objects": objets,
              "vcObjects": habillage(CARTE if titre else None, TRAIT if titre else None, titre)}
        if nom:
            sv["columnProperties"] = {qref(measure): {"displayName": nom}}
        self.add(x, y, w, h, sv, filters=[topn_filter(cat, measure, top)] if top else None)

    def colonnes_series(self, x, y, w, h, cat, series, measure, titre, nom, infobulles=()):
        proj = {"Category": [{"queryRef": qref(cat), "active": True}],
                "Series": [{"queryRef": qref(series)}], "Y": [{"queryRef": qref(measure)}]}
        if infobulles:
            proj["Tooltips"] = [{"queryRef": qref(m)} for m in infobulles]
        self.add(x, y, w, h, {
            "visualType": "clusteredColumnChart", "projections": proj,
            "prototypeQuery": query([cat, series, measure] + list(infobulles), order=cat, desc=False),
            "drillFilterOtherVisuals": True,
            "columnProperties": {qref(measure): {"displayName": nom}},
            "objects": {"labels": [{"properties": {"show": lit("true"), "fontSize": lit("8D")}}],
                        "categoryAxis": [{"properties": {"showAxisTitle": lit("false")}}],
                        "valueAxis": [{"properties": {"show": lit("false"), "gridlineShow": lit("false")}}],
                        "legend": [{"properties": {"showTitle": lit("false"), "position": txt("Top")}}]},
            "vcObjects": habillage(CARTE, TRAIT, titre)})

    def tableau(self, x, y, w, h, fields, noms, order, titre, largeurs, couleurs=None, top=None):
        """Clean table: horizontal lines only, light header, fixed column widths (px);
        couleurs maps a measure column to a colour measure; top keeps the first rows by the order measure."""
        objets = {"grid": [{"properties": {"gridVertical": lit("false"), "gridHorizontal": lit("true"),
                                           "gridHorizontalColor": color(GRILLE), "rowPadding": lit("4D")}}],
                  "columnHeaders": [{"properties": {"fontColor": color(DISCRET), "backColor": color(CARTE),
                                                    "fontSize": lit("9D")}}],
                  "values": [{"properties": {"fontColorPrimary": color(TEXTE), "backColorPrimary": color(CARTE),
                                             "fontColorSecondary": color(TEXTE), "backColorSecondary": color(CARTE),
                                             "fontSize": lit("9D")}}]}
        objets["columnWidth"] = [{"properties": {"value": lit("%dD" % l)}, "selector": {"metadata": qref(f)}}
                                 for f, l in zip(fields, largeurs)]
        if top:
            # The total of a table limited to its first rows would only add up those rows: it is hidden.
            objets["total"] = [{"properties": {"totals": lit("false")}}]
        for colonne, mesure in (couleurs or {}).items():
            objets["values"].append({"properties": couleur_mesure(mesure, "fontColor"),
                                     "selector": {"data": [{"dataViewWildcard": {"matchingOption": 1}}],
                                                  "metadata": qref(colonne)}})
        self.add(x, y, w, h, {
            "visualType": "tableEx", "projections": {"Values": [{"queryRef": qref(f)} for f in fields]},
            "prototypeQuery": query(fields, order=order), "drillFilterOtherVisuals": True,
            "columnProperties": {qref(f): {"displayName": n} for f, n in zip(fields, noms)},
            "objects": objets, "vcObjects": habillage(CARTE, TRAIT, titre)},
            filters=[topn_filter(fields[0], order, top)] if top else None)

    def carte(self, x, y, w, h, measure, titre, infobulles=(), ecart=None):
        """Shape map of the 18 regions (overseas regions in boxes), coloured from light blue to navy,
        or, when ecart is given, from red (below the national score) to blue (above) through grey."""
        loc = C("dim_region", "libelle_region")
        proj = {"Category": [{"queryRef": qref(loc), "active": True}], "Y": [{"queryRef": qref(measure)}]}
        if infobulles:
            proj["Tooltips"] = [{"queryRef": qref(m)} for m in infobulles]
        self.add(x, y, w, h, {
            "visualType": "shapeMap", "projections": proj,
            "prototypeQuery": query([loc, measure] + list(infobulles)), "drillFilterOtherVisuals": True,
            "columnProperties": {qref(loc): {"displayName": "Région"}},
            "objects": {"shape": [{"properties": {
                "map": {"geoJson": {"type": txt("packaged"), "name": txt("Régions de France"),
                                    "content": {"expr": {"ResourcePackageItem": {
                                        "PackageName": "RegisteredResources", "PackageType": 1,
                                        "ItemName": CARTE_FICHIER}}}}},
                "projectionEnum": txt("mercator")}}],
                        "dataPoint": divergent(ecart) if ecart else gradient(measure),
                        "legend": SANS},
            "vcObjects": habillage(CARTE, TRAIT, titre)})


# ---------------------------------------------------------------- pages

REGION = C("dim_region", "libelle_region")
REGION_ETAB = C("dim_etablissement", "libelle_region")
MOIS = C("dim_temps", "debut_mois")
ANNEE = C("Années", "annee")
DIAGNOSTIC = C("dim_diagnostic", "libelle_diagnostic")
SPECIALITE = C("dim_professionnel", "specialite")
SEXE = C("dim_patient", "libelle_sexe")
TRANCHE = C("dim_tranche_age", "libelle_tranche")
# In DirectQuery, the long tables keep their first 100 rows: Impala then computes the stays and patients
# for 100 rows instead of tens of thousands.
TOP = 100 if DQ else None


def titre_liste(objets, ordre, premiers):
    """Title of a long table: the full list in Import, the first 100 rows in DirectQuery."""
    return ("Les %d %s %s" % (TOP, objets, premiers)) if TOP else "%s, %s" % (objets.capitalize(), ordre)


PAGES = ["Synthèse", "Activité médicale", "Établissements", "Territoires"]


def tuile(p, x, y, w, h, code, nom, measure, contexte, mini, page):
    """Summary tile: indicator code and name, value, context, a small chart and a link to the detailed page."""
    p.cadre(x, y, w, h)
    p.text(x + 6, y + 4, w - 12, 32, [("%s  %s" % (code, nom), 10, ACCENT, True)])
    p.valeur(x + 10, y + 30, w - 20, 56, measure, 22, TEXTE)
    p.valeur(x + 10, y + 84, w - 20, 32, contexte, 9, DISCRET)
    if mini:
        mini(x + 8, y + 116, w - 16, h - 156)
    p.bouton(x + w - 176, y + h - 40, 168, 34, "Voir le détail  →", page)


def rangee_tuiles(p, tuiles, y=142, h=250):
    w = (1248 - 3 * 12) / 4
    for i, (code, nom, measure, contexte, mini, page) in enumerate(tuiles):
        tuile(p, 16 + i * (w + 12), y, w, h, code, nom, measure, contexte, mini, page)


def annees_deces_satisfaction(p, x, cache=False):
    """Year lists of the deaths (2010 to 2020) and of the satisfaction (2019 and 2020), shown on Territoires only.
    On the summary page they are hidden: tiles B7 and B8 follow the years chosen on Territoires."""
    p.filtre_annee(x, 78, 180, C("agg_deces_region", "annee_deces"), "Année des décès", 2019, 2010, "annee_deces",
                   cache)
    p.filtre_annee(x + 188, 78, 190, C("agg_satisfaction_region", "annee"), "Année de la satisfaction", 2020, None,
                   "annee_satisfaction", cache)
    return x + 386


def bandeau(p, chiffres, y=142):
    """Row of four key figure cards."""
    w = (1248 - 3 * 12) / 4
    for i, (libelle, measure, contexte) in enumerate(chiffres):
        p.chiffre(16 + i * (w + 12), y, w, 96, libelle, measure, contexte)


def tuiles_praticien(p):
    """Tiles B2, B4, B5 and B6, each linked to the Activité médicale page."""
    return [
        ("B2", "Pathologies", Mz("Part du 1er diagnostic"), Mz("Texte B2"),
         lambda x, y, w, h: p.barres(x, y, w, h, DIAGNOSTIC, Mz("Consultations"), top=3), PAGES[1]),
        ("B4", "Séjours", Mz("Part du 1er diagnostic de séjour"), Mz("Texte B4"),
         lambda x, y, w, h: p.barres(x, y, w, h, DIAGNOSTIC, Mz("Séjours"), top=3), PAGES[1]),
        ("B5", "Hospitalisation par sexe", Mz("Taux des hommes"), Mz("Texte B5"),
         lambda x, y, w, h: p.barres(x, y, w, h, SEXE, Mz(B5[1:-1])), PAGES[1]),
        ("B6", "Professionnels", Mz("Part de la 1re spécialité"), Mz("Texte B6"),
         lambda x, y, w, h: p.barres(x, y, w, h, SPECIALITE, Mz("B6 Part du professionnel"), top=3), PAGES[1])]


def tuiles_direction(p):
    """Tiles B1 and B3 (linked to Établissements), B7 and B8 (linked to Territoires)."""
    return [
        ("B1", "Part du groupe", Mz("B1 Part affichée"), Mz("Texte B1"),
         lambda x, y, w, h: p.ligne(x, y, w, h, MOIS, [Mz("Consultations")], mini=True), PAGES[2]),
        ("B3", "Hospitalisation", Mz(B3[1:-1]), Mz("Texte B3"),
         lambda x, y, w, h: p.ligne(x, y, w, h, MOIS, [Mz(B3[1:-1])], mini=True), PAGES[2]),
        ("B7", "Décès", Mz("B7 Décès"), Mz("Texte décès"),
         lambda x, y, w, h: p.ligne(x, y, w, h, ANNEE, [Mz("Décès par an")], mini=True), PAGES[3]),
        ("B8", "Satisfaction", Mz("B8 Satisfaction"), Mz("Texte satisfaction"),
         lambda x, y, w, h: p.ligne(x, y, w, h, ANNEE, [Mz("Score par année")], mini=True, marqueurs=True), PAGES[3])]


def page_synthese():
    """Summary page: the eight tiles, those of the practitioners on top and those of the management below."""
    p = Page(PAGES[0], 0, "Synthèse des indicateurs",
             "Les huit indicateurs du livrable 1, ceux des praticiens en haut (B2, B4, B5, B6) et ceux de la direction "
             "en bas (B1, B3, B7, B8). Les années des décès et de la satisfaction se choisissent sur la page Territoires.")
    p.filtre_annee(16, 78, 180, titre="Année de l'activité")
    p.filtre(204, 78, 240, REGION, "Région", recherche=True, synchro="region")
    annees_deces_satisfaction(p, 452, cache=True)
    p.text(16, 134, 400, 32, [("Pour les praticiens", 10, ACCENT, True)])
    rangee_tuiles(p, tuiles_praticien(p), y=166, h=250)
    p.text(16, 416, 400, 32, [("Pour la direction", 10, ACCENT, True)])
    rangee_tuiles(p, tuiles_direction(p), y=448, h=250)
    return p


def page_activite():
    p = Page(PAGES[1], 1, "Activité médicale",
             "Consultations et hospitalisations par pathologie, profil de patient et spécialité (indicateurs B2, B4, "
             "B5 et B6). Tous les visuels et les tableaux suivent les filtres.")
    largeur = (1248 - 5 * 8) / 6
    for i, (col, titre, rech) in enumerate([
            (None, "Année de l'activité", False), (REGION, "Région", True), (SEXE, "Sexe", False),
            (TRANCHE, "Âge", False), (SPECIALITE, "Spécialité", True), (DIAGNOSTIC, "Diagnostic", True)]):
        x = 16 + i * (largeur + 8)
        if col is None:
            p.filtre_annee(x, 78, largeur, titre=titre)
        else:
            p.filtre(x, 78, largeur, col, titre, recherche=rech, synchro="region" if col == REGION else None)
    bandeau(p, [("Consultations", Mz("Consultations"), Mz("Texte année d'activité")),
                ("Séjours", Mz("Séjours"), Mz("Texte séjours")),
                ("Taux d'hospitalisation (B3)", Mz(B3[1:-1]), Mz("Texte B3")),
                ("Patients venus", Mz("Patients actifs"), "Au moins une consultation ou un séjour")])
    p.colonnes_series(16, 250, 618, 222, TRANCHE, SEXE, Mz(B5[1:-1]),
                      "Taux d'hospitalisation par âge et par sexe (B5), masqué sous 10 patients",
                      "Taux d'hospitalisation", infobulles=(Mz("Patients hospitalisés"),))
    p.barres(646, 250, 618, 222, SPECIALITE, Mz("B6 Part du professionnel"),
             "Part des consultations par spécialité (B6), les 8 premières", top=8, nom="Part des consultations",
             infobulles=(Mz("Consultations"),))
    p.tableau(16, 480, 618, 224, [DIAGNOSTIC, Mz("Consultations"), Mz("B2 Part du diagnostic"), Mz("Séjours (tableau)"),
                                  Mz("Part des séjours (tableau)")],
              ["Diagnostic", "Consultations", "Part (B2)", "Séjours", "Part des séjours (B4)"], Mz("Consultations"),
              titre_liste("diagnostics", "du plus fréquent au moins fréquent", "les plus fréquents"),
              [250, 85, 70, 55, 115], top=TOP)
    p.tableau(646, 480, 618, 224, [C("dim_professionnel", "code_professionnel"), SPECIALITE, Mz("Consultations"),
                                   Mz("B6 Part du professionnel")],
              ["Professionnel", "Spécialité", "Consultations", "Part (B6)"], Mz("Consultations"),
              titre_liste("professionnels", "du plus actif au moins actif", "les plus actifs"), [110, 270, 95, 75],
              top=TOP)
    return p


def page_etablissements():
    p = Page(PAGES[2], 2, "Pilotage des établissements",
             "Activité et taux d'hospitalisation des établissements, comparés à l'ensemble du groupe (indicateurs B1 "
             "et B3). Avec le rôle Bretagne, la page ne montre que les établissements de cette région.")
    p.filtre_annee(16, 78, 180, titre="Année de l'activité")
    p.filtre(204, 78, 240, REGION, "Région", recherche=True, synchro="region")
    p.filtre(452, 78, 420, C("dim_etablissement", "raison_sociale"), "Établissement", recherche=True)
    bandeau(p, [("Consultations visibles", Mz("Consultations"), Mz("Texte année d'activité")),
                ("Part du groupe (B1)", Mz("B1 Part de l'établissement"), "Consultations visibles sur celles du groupe"),
                ("Taux d'hospitalisation (B3)", Mz(B3[1:-1]), Mz("Texte taux")),
                ("Sans établissement", Mz("Part non rattachée"), "Consultations du groupe sans établissement")])
    p.ligne(16, 250, 618, 222, MOIS, [Mz(B3[1:-1]), Mz("B3 Taux du groupe")],
            "Taux d'hospitalisation par mois (B3), établissements visibles et groupe (pointillés)",
            ["Établissements", "Groupe"], pointilles=Mz("B3 Taux du groupe"))
    p.barres(646, 250, 618, 222, REGION_ETAB, Mz("Consultations"),
             "Consultations par région de l'établissement (B1), « Inconnu » : sans établissement",
             couleur="Couleur sans établissement", top=8, infobulles=(Mz("B1 Part de l'établissement"),))
    p.tableau(16, 480, 1248, 224,
              [C("dim_etablissement", "raison_sociale"), REGION_ETAB, Mz("Consultations"),
               Mz("B1 Part de l'établissement"), Mz("Séjours (tableau)"), Mz("Patients hospitalisés (tableau)")],
              ["Établissement", "Région", "Consultations", "Part du groupe (B1)", "Séjours", "Patients hospitalisés"],
              Mz("Consultations"), titre_liste("établissements", "du plus actif au moins actif", "les plus actifs"),
              [430, 220, 120, 150, 90, 160], top=TOP)
    return p


def page_territoires():
    p = Page(PAGES[3], 3, "Mortalité et satisfaction par région",
             "Décès rapportés à la population INSEE et satisfaction par région, comparés à la moyenne nationale "
             "(indicateurs B7 et B8). Le livrable 1 retient 2019 pour les décès et 2020 pour la satisfaction.")
    x = annees_deces_satisfaction(p, 16)
    p.filtre(x + 8, 78, 240, REGION, "Région", recherche=True, synchro="region")
    p.carte(16, 142, 308, 330, Mz("Décès pour 100 000 habitants"), "Décès pour 100 000 habitants (B7)",
            infobulles=(Mz("B7 Décès"), Mz("Décès pour 100 000 habitants")))
    p.carte(332, 142, 308, 330, Mz("B8 Satisfaction"), "Satisfaction, écart au score national (B8)",
            infobulles=(Mz("B8 Satisfaction"), Mz("Écart au national")), ecart=Mz("Écart au national"))
    p.tableau(648, 142, 616, 330, [REGION, Mz("B7 Décès"), Mz("Décès pour 100 000 habitants"), Mz("B8 Satisfaction"),
                                   Mz("Écart au national"), Mz("Évolution du score")],
              ["Région", "Décès", "Pour 100 000 hab.", "Satisfaction", "Écart au national", "Évolution"],
              Mz("Décès pour 100 000 habitants"), "Régions", [150, 75, 105, 85, 100, 75],
              couleurs={Mz("Écart au national"): "Couleur écart"})
    p.ligne(16, 480, 624, 224, ANNEE, [Mz("Décès par an")],
            "Décès par an, de 2010 à 2019 (B7), pour la ou les régions choisies. Axe resserré, sans zéro",
            marqueurs=True, zero=False)
    p.barres(648, 480, 616, 224, REGION, Mz("Écart au national (extrêmes)"),
             "Satisfaction : les trois régions les plus et les moins bien notées, écart au national",
             couleur="Couleur écart", infobulles=(Mz("B8 Satisfaction"),), nom="Écart au national")
    return p


# ---------------------------------------------------------------- package

def solid(c):
    return {"solid": {"color": c}}


# Marine theme: white cards with a thin border on a light grey page, one accent colour, grey for context.
THEME = {"name": "Theme CHU Marine",
         "dataColors": [ACCENT, SECOND, GRIS, ALERTE, "#8EA9DB", DISCRET, "#9DC3E6", "#203864"],
         "foreground": TEXTE, "foregroundNeutralSecondary": DISCRET, "foregroundNeutralTertiary": GRIS,
         "background": CARTE, "backgroundLight": FOND, "backgroundNeutral": TRAIT, "tableAccent": ACCENT,
         "good": SECOND, "neutral": GRIS, "bad": ALERTE,
         "textClasses": {"callout": {"fontSize": 22, "fontFace": "Segoe UI Semibold", "color": TEXTE},
                         "title": {"fontSize": 11, "fontFace": "Segoe UI Semibold", "color": TEXTE},
                         "header": {"fontSize": 10, "fontFace": "Segoe UI Semibold", "color": TEXTE},
                         "label": {"fontSize": 9, "fontFace": "Segoe UI", "color": DISCRET}},
         "visualStyles": {
             "*": {"*": {"background": [{"show": True, "color": solid(CARTE), "transparency": 0}],
                         "border": [{"show": True, "color": solid(TRAIT), "radius": 8}],
                         "dropShadow": [{"show": False}],
                         "title": [{"show": True, "fontColor": solid(TEXTE), "fontSize": 11,
                                    "fontFamily": "Segoe UI Semibold", "alignment": "left"}],
                         "categoryAxis": [{"showAxisTitle": False, "labelColor": solid(DISCRET), "fontSize": 9,
                                           "gridlineShow": False}],
                         "valueAxis": [{"showAxisTitle": False, "labelColor": solid(DISCRET), "fontSize": 9,
                                        "gridlineColor": solid(GRILLE)}],
                         "labels": [{"color": solid(TEXTE2), "fontSize": 9}],
                         "legend": [{"showTitle": False, "position": "Top", "labelColor": solid(DISCRET)}]}},
             "page": {"*": {"background": [{"color": solid(FOND), "transparency": 0}],
                            "outspace": [{"color": solid(FOND), "transparency": 0}]}},
             "textbox": {"*": {"background": [{"show": False}], "border": [{"show": False}]}},
             "actionButton": {"*": {"background": [{"show": False}], "border": [{"show": False}]}}}}


def build_layout():
    pages = [page_synthese(), page_activite(), page_etablissements(), page_territoires()]
    cfg = {"version": "5.40",
           "themeCollection": {"baseTheme": {"name": "CY22SU11", "version": "5.42", "type": 2},
                               "customTheme": {"name": "Theme_CHU.json", "version": "5.42", "type": 1}},
           "activeSectionIndex": PAGE_ACTIVE, "defaultDrillFilterOtherVisuals": True,
           "settings": {"useNewFilterPaneExperience": True, "allowChangeFilterTypes": True,
                        "useStylableVisualContainerHeader": True, "exportDataMode": 1,
                        "useDefaultAggregateDisplayName": True},
           "objects": {"section": [{"properties": {"verticalAlignment": txt("Top")}}]}}
    return {"id": 0,
            "resourcePackages": [
                {"resourcePackage": {"name": "SharedResources", "type": 2, "disabled": False,
                                     "items": [{"type": 202, "path": "BaseThemes/CY22SU11.json", "name": "CY22SU11"}]}},
                {"resourcePackage": {"name": "RegisteredResources", "type": 1, "disabled": False,
                                     "items": [{"type": 201, "path": "Theme_CHU.json", "name": "Theme_CHU.json"},
                                               {"type": 200, "path": CARTE_FICHIER, "name": CARTE_FICHIER}]}}],
            "sections": [p.section() for p in pages],
            "config": json.dumps(cfg, ensure_ascii=False), "layoutOptimization": 0}


def build_diagram():
    pos = {"fait_consultation": (520, 260), "fait_hospitalisation": (520, 640), "dim_temps": (120, 60),
           "dim_patient": (120, 440), "dim_tranche_age": (120, 820), "dim_etablissement": (920, 60),
           "dim_diagnostic": (920, 440), "dim_professionnel": (920, 820), "agg_consultation_jour": (120, 1180),
           "dim_region": (1320, 440), "agg_deces_region": (1320, 60), "agg_satisfaction_region": (1320, 820),
           "population": (1320, 1180), "Mesures": (1720, 60), "b3_groupe_mois": (1720, 440),
           "b3_groupe_annee": (1720, 820), "Années": (1720, 1180)}
    nodes = [{"location": {"x": x, "y": y}, "nodeIndex": n, "size": {"height": 300, "width": 234}, "zIndex": 0}
             for n, (x, y) in pos.items()]
    return {"version": "1.1.0", "diagrams": [{"ordinal": 0, "scrollPosition": {"x": 0, "y": 0}, "nodes": nodes,
                                               "name": "Toutes les tables", "zoomValue": 70,
                                               "pinKeyFieldsToTop": False, "showExtraHeaderInfo": False,
                                               "hideKeyFieldsWhenCollapsed": False, "tablesLocked": False}],
            "selectedDiagram": "Toutes les tables", "defaultDiagram": "Toutes les tables"}


CONTENT_TYPES = ('<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/'
                 'content-types"><Default Extension="json" ContentType="" /><Override PartName="/Version" '
                 'ContentType="" /><Override PartName="/DiagramLayout" ContentType="" /><Override '
                 'PartName="/Report/Layout" ContentType="" /><Override PartName="/Settings" '
                 'ContentType="application/json" /><Override PartName="/Metadata" ContentType="application/json" />'
                 '<Override PartName="/DataModelSchema" ContentType="" /></Types>')

SETTINGS = {"Version": 3, "ReportSettings": {"IsRelationshipAutodetectionEnabled": False,
                                            "IsParallelQueryLoadingEnabled": False},
            "QueriesSettings": {"TypeDetectionEnabled": False, "RelationshipImportEnabled": False,
                                "RunBackgroundAnalysis": False, "Version": "2.115.663.0"}}
METADATA = {"Version": 5, "AutoCreatedRelationships": [], "CreatedFrom": "Cloud", "CreatedFromRelease": "2023.03"}

with zipfile.ZipFile(SORTIE, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", b"\xef\xbb\xbf" + CONTENT_TYPES.encode("utf-8"))
    z.writestr("Version", u16("1.25"))
    z.writestr("DataModelSchema", u16(build_model()))
    z.writestr("DiagramLayout", u16(build_diagram()))
    z.writestr("Report/Layout", u16(build_layout()))
    z.writestr("Settings", u16(SETTINGS))
    z.writestr("Metadata", u16(METADATA))
    if REF:
        with open(REF + "/Report/StaticResources/SharedResources/BaseThemes/CY22SU11.json", "rb") as f:
            z.writestr("Report/StaticResources/SharedResources/BaseThemes/CY22SU11.json", f.read())
    z.writestr("Report/StaticResources/RegisteredResources/Theme_CHU.json", json.dumps(THEME, ensure_ascii=False))
    with open(os.path.join(ICI, CARTE_FICHIER), "rb") as f:
        z.writestr("Report/StaticResources/RegisteredResources/" + CARTE_FICHIER, f.read())
print("écrit", SORTIE)
