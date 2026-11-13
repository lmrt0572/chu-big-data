"""Graphiques et résumé de F2 (index et réglage du datamart PostgreSQL).

Usage : python graphiques_f2.py
Lit resultats/resultats_postgres.csv et resultats/logs/postgres_index.csv, écrit
resultats/graphiques/F2_index.png, F2_work_mem.png et resultats/resultats_postgres.md.
Reprend les couleurs et les fonctions de graphiques.py, sans le modifier.
"""
import pandas as pd
import matplotlib.pyplot as plt

from graphiques import (BLEU, BLEU_FONCE, DOSSIER, GRIS, habiller, lire_mesures, nombre, resumer,
                        verifier_resultats)

GRIS_CLAIR = "#A6A6A6"
ETATS = {"sans_index": ("Sans index", GRIS_CLAIR), "btree": ("B-tree par clé", BLEU),
         "couvrant": ("Index couvrant", BLEU_FONCE)}
PALIERS = {"1M": "1 million", "10M": "10 millions", "50M": "50 millions"}
QUESTIONS = {"B1": "B1 établissements", "B2": "B2 diagnostics", "B6": "B6 professionnels"}


def secondes(v: float) -> str:
    """Les requêtes du datamart durent souvent moins d'une seconde : deux décimales sous 1 s."""
    if v < 0.01:
        return "< 0,01"
    return f"{v:.2f}".replace(".", ",") if v < 1 else nombre(v)


def decouper(resume: pd.DataFrame) -> pd.DataFrame:
    """Lire la question, le palier, l'état d'index et le réglage dans le nom du test (B1_10M_couvrant_wm64MB)."""
    parties = resume["test"].str.extract(r"^(B\d)_(\d+M)_(sans_index|btree|couvrant)(?:_wm(\w+))?$")
    parties.columns = ["question", "palier", "etat", "work_mem"]
    parties["work_mem"] = parties["work_mem"].fillna("4MB")
    return pd.concat([resume, parties], axis=1)


def barres_groupees(ax, partie, series, cle_serie, titre):
    """Une grappe de barres par question, une barre par série (état d'index ou réglage)."""
    questions = [q for q in QUESTIONS if (partie["question"] == q).any()]
    largeur = 0.8 / len(series)
    maximum = 0
    for i, (valeur, (libelle, couleur)) in enumerate(series.items()):
        lignes = partie[partie[cle_serie] == valeur].set_index("question")["mediane"]
        hauteurs = [lignes.get(q, float("nan")) for q in questions]
        positions = [x + (i - (len(series) - 1) / 2) * largeur for x in range(len(questions))]
        ax.bar(positions, [0 if pd.isna(h) else h for h in hauteurs], width=largeur * 0.95,
               color=couleur, label=libelle)
        for x, h in zip(positions, hauteurs):
            if not pd.isna(h):
                maximum = max(maximum, h)
                ax.annotate(secondes(h), (x, h), xytext=(0, 2), textcoords="offset points",
                            ha="center", va="bottom", fontsize=7, color=GRIS)
    ax.set_xticks(range(len(questions)))
    ax.set_xticklabels([QUESTIONS[q] for q in questions], fontsize=9)
    ax.set_title(titre, fontsize=11, color=BLEU_FONCE, loc="left")
    habiller(ax, maximum)


def meme_echelle(axes):
    """Tous les panneaux d'une figure gardent la même échelle, pour que les hauteurs se comparent d'un coup d'œil."""
    haut = max(ax.get_ylim()[1] for ax in axes)
    for ax in axes:
        ax.set_ylim(0, haut)


def figure_index(f2):
    partie = f2[(f2["work_mem"] == "4MB") & f2["question"].isin(QUESTIONS)]
    paliers = [p for p in PALIERS if (partie["palier"] == p).any()]
    fig, axes = plt.subplots(1, len(paliers), figsize=(5.2 * len(paliers), 4.2), squeeze=False)
    for ax, palier in zip(axes[0], paliers):
        barres_groupees(ax, partie[partie["palier"] == palier], ETATS, "etat", PALIERS[palier] + " de consultations")
    meme_echelle(axes[0])
    fig.suptitle("Index du datamart PostgreSQL, consultations de 2019 (temps médian en secondes, même échelle)",
                 fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.tight_layout()
    fig.savefig(DOSSIER / "graphiques" / "F2_index.png", dpi=200)
    plt.close(fig)


def figure_work_mem(f2):
    reglages = sorted(f2.loc[f2["work_mem"] != "4MB", "work_mem"].unique())
    if not reglages:
        return
    series = {"4MB": ("work_mem 4 Mo (installation)", GRIS_CLAIR)}
    series.update({r: (f"work_mem {r.replace('MB', ' Mo')}", BLEU_FONCE) for r in reglages})
    cas = (f2[f2["work_mem"].isin(reglages)][["palier", "etat"]].drop_duplicates()
           .sort_values(["palier", "etat"], key=lambda s: s.map(
               lambda v: int(v[:-1]) if v.endswith("M") else list(ETATS).index(v))))
    fig, axes = plt.subplots(1, len(cas), figsize=(4.6 * len(cas), 4.2), squeeze=False)
    for ax, (_, c) in zip(axes[0], cas.iterrows()):
        partie = f2[(f2["palier"] == c["palier"]) & (f2["etat"] == c["etat"])]
        barres_groupees(ax, partie, series, "work_mem", f"{PALIERS[c['palier']]}, {ETATS[c['etat']][0].lower()}")
    meme_echelle(axes[0])
    fig.suptitle("Mémoire de travail de PostgreSQL : même requête, même index (temps médian en secondes)",
                 fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.tight_layout()
    fig.savefig(DOSSIER / "graphiques" / "F2_work_mem.png", dpi=200)
    plt.close(fig)


def tableau(f2, colonnes, cle):
    """Tableau markdown : une ligne par (palier, question), une colonne par état ou réglage."""
    pivot = f2.pivot_table(index=["palier", "question"], columns=cle, values="mediane")
    pivot = pivot.reindex(columns=[c for c in colonnes if c in pivot.columns])
    entete = "| Palier | Question | " + " | ".join(colonnes[c] for c in pivot.columns) + " | Même résultat |\n"
    entete += "|---|---|" + "---|" * (len(pivot.columns) + 1) + "\n"
    lignes = []
    for (palier, question), valeurs in sorted(pivot.iterrows(), key=lambda r: (int(r[0][0][:-1]), r[0][1])):
        coherent = f2[(f2["palier"] == palier) & (f2["question"] == question)]["coherent"]
        cellules = " | ".join("" if pd.isna(v) else secondes(v) for v in valeurs)
        lignes.append(f"| {PALIERS.get(palier, palier)} | {question} | {cellules} | "
                      f"{'oui' if (coherent == 'oui').all() else 'NON'} |")
    return entete + "\n".join(lignes) + "\n"


def main():
    (DOSSIER / "graphiques").mkdir(parents=True, exist_ok=True)
    mesures = lire_mesures(DOSSIER / "resultats_postgres.csv")
    f2 = decouper(verifier_resultats(resumer(mesures)))
    figure_index(f2)
    figure_work_mem(f2)

    index = pd.read_csv(DOSSIER / "logs" / "postgres_index.csv", sep=";")
    index = index.drop_duplicates(["volume", "etat"], keep="first")
    cout = ["| Palier | État | Création (s) | Place des index (Mo) | Table des consultations (Mo) |",
            "|---|---|---|---|---|"]
    for _, l in index.iterrows():
        cout.append(f"| {PALIERS.get(l['volume'][1:] + 'M', l['volume'])} | {ETATS[l['etat']][0]} "
                    f"| {nombre(l["secondes_creation"]) if l["secondes_creation"] else "–"} | {nombre(l["taille_index_mo"]) if l["taille_index_mo"] else "–"} "
                    f"| {nombre(l['taille_consultations_mo'])} |")

    reglage = f2[f2["work_mem"] != "4MB"]
    sections = [
        "# F2 : index et réglage du datamart PostgreSQL\n\n",
        f"{len(mesures)} essais lus dans resultats_postgres.csv, du {mesures['horodatage'].min()} au "
        f"{mesures['horodatage'].max()} (heure du PC). Médiane des essais 2 à 4, en secondes. "
        "Réglage d'installation de PostgreSQL 14 (work_mem 4 Mo, shared_buffers 128 Mo).\n\n",
        "## Effet des index\n\n",
        tableau(f2[f2["work_mem"] == "4MB"], {k: v[0] for k, v in ETATS.items()}, "etat"),
        "\n## Coût des index\n\n", "\n".join(cout) + "\n",
    ]
    if len(reglage):
        for etat in reglage["etat"].unique():
            partie = f2[(f2["etat"] == etat) & f2["palier"].isin(reglage["palier"].unique())]
            colonnes = {"4MB": "work_mem 4 Mo"}
            colonnes.update({r: f"work_mem {r.replace('MB', ' Mo')}" for r in reglage["work_mem"].unique()})
            sections += [f"\n## Mémoire de travail, état « {ETATS[etat][0].lower()} »\n\n",
                         tableau(partie, colonnes, "work_mem")]
    (DOSSIER / "resultats_postgres.md").write_text("".join(sections), encoding="utf-8")
    print(f"{len(mesures)} essais, graphiques et résumé F2 écrits dans {DOSSIER}")


if __name__ == "__main__":
    main()
