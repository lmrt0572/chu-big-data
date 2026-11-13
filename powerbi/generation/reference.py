"""Expected values of the dashboard measures, computed with pandas on the test copies."""
import sys, pandas as pd
D = sys.argv[1]
rd = lambda n: pd.read_csv(f"{D}/{n}.tsv", sep="\t", keep_default_na=False, dtype=str)
c, h, e = rd("fait_consultation"), rd("fait_hospitalisation"), rd("dim_etablissement")
d, s = rd("agg_deces_region"), rd("agg_satisfaction_region")
c["an"] = c.id_temps.str[:4]; c["mo"] = c.id_temps.str[4:6].astype(int)
h["an"] = h.id_temps_admission.str[:4]; h["mo"] = h.id_temps_admission.str[4:6].astype(int)
bret = set(e[e.code_region == "53"].id_etablissement)

def bloc(nom, cc, hh, an="2019"):
    c1, h1 = cc[cc.an == an], hh[hh.an == an]
    actifs = len(set(c1.id_patient) | set(h1.id_patient)); hosp = h1.id_patient.nunique()
    print(f"{nom} {an}: consultations={len(c1)} sejours={len(h1)} patients_actifs={actifs} "
          f"patients_hosp={hosp} B3={hosp / actifs:.6f}")
    return c1, h1

c19, h19 = bloc("TOUS", c, h)
grp = len(c19)
print("consultations groupe 2019 =", grp, " non rattachees =", (c19.id_etablissement == "-1").sum(),
      f"part={(c19.id_etablissement == '-1').sum() / grp:.6f}")
cb, hb = bloc("BRETAGNE", c[c.id_etablissement.isin(bret)], h[h.id_etablissement.isin(bret)])
print(f"B1 Bretagne 2019 = {len(cb) / grp:.6f}")
m3 = c[(c.an == "2019") & (c.mo == 3)]; hm3 = h[(h.an == "2019") & (h.mo == 3)]
a3 = len(set(m3.id_patient) | set(hm3.id_patient)); print(f"groupe mars 2019: actifs={a3} hosp={hm3.id_patient.nunique()} B3={hm3.id_patient.nunique() / a3:.6f}")
d["n"] = d.nb_deces.astype(int); print("B7 2019 =", d[d.annee_deces == "2019"].n.sum())
for an in ("2019", "2020"):
    x = s[s.annee == an]; print(f"score {an} =", round(x.somme_notes_ponderees.astype(float).sum() / x.nb_avis_notes.astype(int).sum(), 4))
dg = rd("dim_diagnostic").set_index("id_diagnostic").libelle_diagnostic
top = c19.id_diagnostic.value_counts().head(3)
for k, v in top.items(): print(f"top diag 2019: {dg[k][:50]} {v} part={v / grp:.6f}")
