"""Builds TSV test copies of the tables read by the report (Gold tables and aggregates) from the Gold TSV exports."""
import sys, pandas as pd
src, dst = sys.argv[1], sys.argv[2]
rd = lambda n: pd.read_csv(f"{src}/{n}.tsv", sep="\t", dtype=str, keep_default_na=False)
def wr(df, n): df.to_csv(f"{dst}/{n}.tsv", sep="\t", index=False, encoding="utf-8", lineterminator="\n")

MOIS = ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"]
t = rd("dim_temps")
d = pd.to_datetime(t.date_jour, errors="coerce")
t["nom_mois"] = [MOIS[int(m) - 1] if m != "-1" else "inconnu" for m in t.mois]
t["semaine_iso"] = [str(x.isocalendar()[1]) if pd.notna(x) else "-1" for x in d]
t.loc[t.id_temps == "-1", "date_jour"] = ""
wr(t[["id_temps", "date_jour", "jour", "mois", "nom_mois", "trimestre", "semaine_iso", "annee"]], "dim_temps")
for n in ("dim_tranche_age", "dim_region", "dim_diagnostic"):
    wr(rd(n), n)
r = rd("dim_region")
e = rd("dim_etablissement").merge(r[["code_region", "libelle_region"]], on="code_region", how="left")
e["libelle_region"] = e.libelle_region.fillna("Inconnu")
wr(e[["id_etablissement", "identifiant_organisation", "raison_sociale", "code_region", "libelle_region"]], "dim_etablissement")
p = rd("dim_patient"); p["patient_pseudo"] = ""
wr(p[["id_patient", "patient_pseudo", "sexe"]], "dim_patient")
wr(rd("dim_professionnel"), "dim_professionnel")
c = rd("fait_consultation"); c["num_consultation"] = c.id_consultation; c["nb_consultation"] = "1"
wr(c[["id_consultation", "num_consultation", "nb_consultation", "id_tranche_age", "id_diagnostic", "id_etablissement",
      "id_professionnel", "id_patient", "id_temps"]], "fait_consultation")
h = rd("fait_hospitalisation"); h["num_hospitalisation"] = h.id_hospitalisation; h["nb_hospitalisation"] = "1"
wr(h[["id_hospitalisation", "num_hospitalisation", "nb_hospitalisation", "id_etablissement", "id_tranche_age",
      "id_diagnostic", "id_patient", "id_temps_admission"]], "fait_hospitalisation")
wr(rd("agg_deces_region"), "agg_deces_region")
s = rd("fait_satisfaction")
s["annee"] = s.id_temps.str[:4]
s["nb"] = s.nb_avis.astype(int)
s["note"] = pd.to_numeric(s.note_globale.replace({"NULL": None, "": None}), errors="coerce")
s["nb_notes"] = s.nb.where(s.note.notna(), 0)
s["pond"] = (s.note * s.nb).where(s.note.notna(), 0)
a = s.groupby(["annee", "id_region"]).agg(nb_etablissements=("nb", "size"), nb_avis=("nb", "sum"),
                                          nb_avis_notes=("nb_notes", "sum"), somme_notes_ponderees=("pond", "sum")).reset_index()
a["somme_notes_ponderees"] = a.somme_notes_ponderees.round(2)
wr(a, "agg_satisfaction_region")
j = c.groupby("id_temps").size().rename("nb_consultations").reset_index()
wr(j, "agg_consultation_jour")
print("ok", {n: len(x) for n, x in [("temps", t), ("etab", e), ("consult", c), ("hosp", h), ("satisf", a), ("jour", j)]})
print("notes absentes:", s.note.isna().sum(), "valeurs note_globale exemples:", s.note_globale.unique()[:5])
