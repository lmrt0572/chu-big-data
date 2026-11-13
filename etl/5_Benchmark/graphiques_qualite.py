"""Graphique de complétude par attribut du Gold, pour le rapport du livrable 2.

Usage : python graphiques_qualite.py
Écrit resultats/graphiques/qualite_completude.png.
Les taux ont été calculés le 05/11/2026 sur la copie du Gold chargée dans PostgreSQL (base chu_bench),
après l'exécution GOLD_20261030_152336. Ils sont recopiés ici, à mettre à jour si le Gold est rechargé.
"""
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

from graphiques import BLEU, BLEU_FONCE, DOSSIER, GRILLE, GRIS

GRIS_CLAIR = "#A6A6A6"
ORANGE = "#C55A11"

# (table, attribut, taux de valeurs connues en %)
COMPLETUDE = [
    ("Consultations", "patient, professionnel, diagnostic, date", 100.0),
    ("Consultations", "tranche d'âge", 97.65),
    ("Consultations", "établissement", 63.87),
    ("Hospitalisations", "patient, établissement, diagnostic, date", 100.0),
    ("Hospitalisations", "tranche d'âge", 97.50),
    ("Satisfaction e-Satis", "région", 100.0),
    ("Satisfaction e-Satis", "établissement (FINESS)", 99.30),
    ("Satisfaction e-Satis", "note globale", 73.63),
    ("Patients", "sexe", 100.0),
    ("Professionnels", "spécialité", 100.0),
]


def couleur(taux):
    if taux >= 99:
        return BLEU_FONCE
    if taux >= 95:
        return BLEU
    return ORANGE


def main():
    lignes = list(reversed(COMPLETUDE))
    fig, ax = plt.subplots(figsize=(10, 5))
    positions = range(len(lignes))
    ax.barh(positions, [t for *_, t in lignes], height=0.62, color=[couleur(t) for *_, t in lignes])
    for y, (_, _, t) in zip(positions, lignes):
        texte = f"{t:.2f}".replace(".", ",").replace(",00", "") + " %"
        ax.annotate(texte, (t, y), xytext=(4, 0), textcoords="offset points", va="center", fontsize=9, color=GRIS)
    ax.set_yticks(list(positions))
    ax.set_yticklabels([f"{table}, {attribut}" for table, attribut, _ in lignes], fontsize=9)
    ax.set_xlim(0, 110)
    ax.set_xticks(range(0, 101, 20))
    ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:g} %"))
    ax.set_xlabel("Part des lignes dont la valeur est connue", fontsize=9, color=GRIS)
    ax.grid(axis="x", color=GRILLE, linewidth=0.8)
    ax.set_axisbelow(True)
    for cote in ("top", "right"):
        ax.spines[cote].set_visible(False)
    ax.tick_params(colors=GRIS, labelsize=9)
    fig.suptitle("Complétude des attributs du Gold",
                 fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.text(0.01, 0.01, "En orange, les attributs incomplets à cause des sources (anomalies A06 et A15). "
             "Une valeur inconnue est rattachée au membre -1 de sa dimension, la ligne n'est pas perdue.",
             fontsize=7.5, color=GRIS)
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    fig.savefig(DOSSIER / "graphiques" / "qualite_completude.png", dpi=200)
    plt.close(fig)
    print("qualite_completude.png écrit")


if __name__ == "__main__":
    main()
