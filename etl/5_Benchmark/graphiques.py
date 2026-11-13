"""Tracer les graphiques du benchmark et résumer les mesures de resultats.csv.

Usage : python graphiques.py [chemin de resultats.csv]
Par défaut, le fichier est lu dans resultats/. Les graphiques sont écrits dans
resultats/graphiques et le résumé dans resultats/resultats_benchmark.md.
"""
import hashlib
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.ticker import FuncFormatter

DOSSIER = Path(__file__).parent / "resultats"
BLEU_FONCE = "#1F3864"
BLEU = "#4F81BD"
GRIS = "#595959"
GRILLE = "#D9D9D9"
SEUIL_SECONDES = 120

LIBELLES = {
    "sans_partition": "Sans partition",
    "avec_partition": "Avec partition",
    "mauvais_filtre": "Partition, filtre\nsur dim_temps",
    "texte": "Texte",
    "parquet": "Parquet",
    "B7_agregat": "B7 agrégat",
    "B1_agregat": "B1 agrégat",
    "B2_agregat": "B2 agrégat",
    "source_4_jointures": "Tables d'origine\n4 jointures",
    "etoile_1_jointure": "Modèle en étoile\n1 jointure",
    "shuffle_join": "Shuffle join",
    "map_join": "Map join",
    "bucket_map_join": "Map join sur\ntables en buckets",
    "bucket_map_join_indice": "Bucket map join",
    "sort_merge_bucket": "Sort-merge\nbucket join",
}

TITRES = {
    "F1": "Partitionnement : décès de 2019 par région (B7)",
    "F3": "Format de stockage : décès de 2019 par département",
    "F4": "Moteur : les 8 questions métier sur le Gold",
    "F5": "Précalcul : calcul sur le détail ou lecture d'une table d'agrégat",
    "F6a": "Nombre de jointures : consultations par région",
    "F6b": "Façon de joindre : consultations par spécialité",
    "F7": "Volume : consultations recopiées 1, 10 et 100 fois",
}


def nombre(valeur: float) -> str:
    """Écrire un nombre à la française, avec une décimale sous 10."""
    texte = f"{valeur:.1f}" if valeur < 10 else f"{valeur:.0f}"
    return texte.replace(".", ",")


def lire_mesures(chemin: Path) -> pd.DataFrame:
    mesures = pd.read_csv(chemin, sep=";", dtype={"empreinte": str})
    mesures["ordre"] = range(len(mesures))
    # un essai relancé après un échec remplace la ligne en échec, à la place du test dans le plan
    mesures["ordre"] = mesures.groupby(["famille", "test", "moteur"], sort=False)["ordre"].transform("min")
    return mesures.drop_duplicates(["famille", "test", "moteur", "essai"], keep="last")


def resumer(mesures: pd.DataFrame) -> pd.DataFrame:
    """Donner, par test et par moteur, le premier essai, la médiane des suivants et l'empreinte."""
    lignes = []
    for (famille, test, moteur), essais in mesures.groupby(["famille", "test", "moteur"], sort=False):
        reussis = essais[essais["statut"] == "OK"]
        froid = reussis[reussis["essai"] == 1]["secondes_moteur"]
        suivants = reussis[reussis["essai"] > 1]["secondes_moteur"]
        lignes.append({
            "famille": famille,
            "test": test,
            "groupe": essais["groupe"].iloc[0],
            "moteur": moteur,
            "ordre": essais["ordre"].min(),
            "statut": "OK" if len(reussis) == len(essais) else "ECHEC",
            "essais": len(reussis),
            "froid": froid.iloc[0] if len(froid) else None,
            # sans essai suivant, le premier essai sert de valeur
            "mediane": suivants.median() if len(suivants) else (froid.iloc[0] if len(froid) else None),
            "lignes": reussis["lignes"].iloc[-1] if len(reussis) else None,
            "mo_lus": reussis["octets_lus_hdfs"].iloc[-1] / 1e6 if len(reussis) else None,
            "empreinte": reussis["empreinte"].iloc[-1] if len(reussis) else None,
        })
    return pd.DataFrame(lignes).sort_values("ordre")


def tracer_barres(ax, libelles, valeurs, titre):
    positions = range(len(libelles))
    hauteurs = [0 if pd.isna(v) else v for v in valeurs]
    ax.bar(positions, hauteurs, width=0.6, color=BLEU_FONCE)
    for x, v in zip(positions, valeurs):
        texte = "échec" if pd.isna(v) else f"{nombre(v)} s"
        ax.annotate(texte, (x, hauteurs[x]), xytext=(0, 3), textcoords="offset points",
                    ha="center", va="bottom", fontsize=9, color=GRIS)
    ax.set_xticks(list(positions))
    ax.set_xticklabels(libelles, fontsize=9)
    # au moins trois emplacements, pour qu'une barre seule ne remplisse pas tout le panneau
    ax.set_xlim(-0.6, max(len(libelles), 3) - 0.4)
    ax.set_title(titre, fontsize=11, color=BLEU_FONCE, loc="left")
    habiller(ax, max(hauteurs, default=0))


def habiller(ax, maximum):
    ax.set_ylabel("Temps médian (s)", fontsize=9, color=GRIS)
    ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:g}".replace(".", ",")))
    ax.set_ylim(0, max(maximum, 1) * 1.18)
    ax.grid(axis="y", color=GRILLE, linewidth=0.8)
    ax.set_axisbelow(True)
    for cote in ("top", "right"):
        ax.spines[cote].set_visible(False)
    ax.tick_params(colors=GRIS, labelsize=9)
    # la ligne des 2 minutes n'est utile que si une barre s'en approche
    if maximum > SEUIL_SECONDES / 2:
        ax.axhline(SEUIL_SECONDES, color=GRIS, linestyle="--", linewidth=1, label="seuil de 2 minutes")
        ax.set_ylim(0, max(maximum, SEUIL_SECONDES) * 1.25)
    # la légende reprend les séries et le seuil, sans recouvrir les valeurs écrites sur les barres
    if ax.get_legend_handles_labels()[0]:
        ax.legend(frameon=False, fontsize=8, loc="upper left", ncol=3)


def figure_par_moteur(resume, cle, moteurs=("hive", "impala")):
    """Tracer une figure avec un panneau par moteur, chaque panneau ayant sa propre échelle."""
    presents = [m for m in moteurs if (resume["moteur"] == m).any()]
    largeur = max(4.5, 1.3 * resume["test"].nunique())
    fig, axes = plt.subplots(1, len(presents), figsize=(largeur * len(presents), 4.2), squeeze=False)
    for ax, moteur in zip(axes[0], presents):
        partie = resume[resume["moteur"] == moteur]
        libelles = [LIBELLES.get(t, t) for t in partie["test"]]
        tracer_barres(ax, libelles, list(partie["mediane"]), moteur.capitalize())
    fig.suptitle(TITRES[cle], fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.tight_layout()
    fig.savefig(DOSSIER / "graphiques" / f"{cle}.png", dpi=200)
    plt.close(fig)


def figure_volume(resume):
    partie = resume[resume["famille"] == "F7"].copy()
    partie["question"] = partie["test"].str.split("_").str[0]
    partie["volume"] = partie["test"].str.split("_").str[1]
    volumes = ["1M", "10M", "100M"]
    moteurs = [m for m in ("hive", "impala") if (partie["moteur"] == m).any()]
    fig, axes = plt.subplots(1, len(moteurs), figsize=(6 * len(moteurs), 4.2), squeeze=False)
    for ax, moteur in zip(axes[0], moteurs):
        maximum = 0
        for decalage, (question, couleur) in zip((-0.2, 0.2), (("B1", BLEU_FONCE), ("B6", BLEU))):
            lignes = partie[(partie["moteur"] == moteur) & (partie["question"] == question)].set_index("volume")
            valeurs = [lignes["mediane"].get(v) for v in volumes]
            hauteurs = [0 if pd.isna(v) else v for v in valeurs]
            maximum = max([maximum] + hauteurs)
            positions = [i + decalage for i in range(len(volumes))]
            ax.bar(positions, hauteurs, width=0.38, color=couleur, label=question)
            for x, v, h in zip(positions, valeurs, hauteurs):
                texte = "–" if pd.isna(v) else f"{nombre(v)} s"
                ax.annotate(texte, (x, h), xytext=(0, 3), textcoords="offset points",
                            ha="center", va="bottom", fontsize=8, color=GRIS)
        ax.set_xticks(range(len(volumes)))
        ax.set_xticklabels(["1 million", "10 millions", "100 millions"], fontsize=9)
        ax.set_title(moteur.capitalize(), fontsize=11, color=BLEU_FONCE, loc="left")
        habiller(ax, maximum)
    fig.suptitle(TITRES["F7"], fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.tight_layout()
    fig.savefig(DOSSIER / "graphiques" / "F7.png", dpi=200)
    plt.close(fig)


def reference(ligne) -> tuple[str, str] | None:
    """Donner le test et le moteur auxquels comparer une ligne du tableau."""
    famille, test, moteur = ligne["famille"], ligne["test"], ligne["moteur"]
    if famille == "F5" or test.endswith("_detail"):
        return test[:2] + "_detail", moteur
    if famille == "F4":
        return (test, "hive") if moteur == "impala" else None
    if famille == "F6":
        return ("source_4_jointures" if ligne["groupe"] == "REGION" else "shuffle_join"), moteur
    if famille == "F7":
        return test.split("_")[0] + "_1M", moteur
    return {"F1": "sans_partition", "F3": "texte"}[famille], moteur


def comparer(temps: float, temps_reference: float) -> str:
    rapport = temps_reference / temps
    if 0.95 <= rapport < 1.05:
        return "aussi rapide"
    if rapport >= 1:
        return f"{nombre(rapport)} fois plus rapide"
    return f"{nombre(1 / rapport)} fois plus lent"


def tableau_markdown(partie: pd.DataFrame) -> str:
    entete = ("| Test | Moteur | 1er essai, à froid (s) | Médiane des suivants (s) | Comparaison "
              "| Lignes | Mo lus (Hive) | Même résultat que le groupe |\n|---|---|---|---|---|---|---|---|\n")
    medianes = partie.set_index(["test", "moteur"])["mediane"]
    corps = []
    for _, l in partie.iterrows():
        cible = reference(l)
        if cible is None or cible == (l["test"], l["moteur"]):
            comparaison = "référence" if cible else ""
        elif pd.isna(l["mediane"]) or pd.isna(medianes.get(cible)):
            comparaison = ""
        else:
            comparaison = comparer(l["mediane"], medianes[cible])
        mo_lus = "" if pd.isna(l["mo_lus"]) else ("< 0,1" if l["mo_lus"] < 0.05 else nombre(l["mo_lus"]))
        corps.append(
            f"| {LIBELLES.get(l['test'], l['test']).replace(chr(10), ' ')} | {l['moteur'].capitalize()} "
            f"| {'échec' if pd.isna(l['froid']) else nombre(l['froid'])} "
            f"| {'échec' if pd.isna(l['mediane']) else nombre(l['mediane'])} | {comparaison} "
            f"| {'' if pd.isna(l['lignes']) else f'{int(l['lignes']):,}'.replace(',', ' ')} "
            f"| {mo_lus} | {l['coherent']} |"
        )
    return entete + "\n".join(corps) + "\n"


def empreinte_sortie(famille: str, test: str, moteur: str) -> str | None:
    """Recalculer l'empreinte d'une sortie gardée, sans les guillemets qu'impala-shell ajoute aux libellés."""
    chemin = DOSSIER / "logs" / f"sortie_{famille}_{test}_{moteur}.txt"
    if not chemin.exists():
        return None
    lignes = []
    for ligne in chemin.read_text(encoding="utf-8").replace('"', "").splitlines():
        champs = [f"{float(c):.2f}" if re.fullmatch(r"-?\d+(\.\d+)?", c) else c for c in ligne.split("\t")]
        lignes.append("\t".join(champs))
    return hashlib.md5("\n".join(sorted(lignes)).encode("utf-8")).hexdigest()[:12]


def verifier_resultats(resume: pd.DataFrame) -> pd.DataFrame:
    """Marquer les tests dont le résultat diffère des autres tests de leur groupe, dans le même moteur."""
    resume = resume.copy()
    reference = (resume[resume["statut"] == "OK"].groupby(["groupe", "moteur"])["empreinte"]
                 .agg(lambda e: e.mode().iloc[0]))
    resume["coherent"] = [
        "échec" if r["statut"] != "OK"
        else ("oui" if r["empreinte"] == reference.get((r["groupe"], r["moteur"])) else "NON")
        for _, r in resume.iterrows()
    ]
    return resume


COMPARAISONS = {
    "F1": "Chaque test est comparé au test sans partition, dans le même moteur.",
    "F4": "Impala est comparé à Hive, pour la même question.",
    "F3": "Parquet est comparé au format texte, dans le même moteur.",
    "F5": "Chaque agrégat est comparé au calcul sur le détail (mesuré dans F4), dans le même moteur.",
    "F6": "Les jointures sont comparées aux tables d'origine pour la région, et au shuffle join pour la spécialité.",
    "F7": "Chaque palier est comparé au palier de 1 million, pour la même question et le même moteur.",
}


def comparer_moteurs(resume: pd.DataFrame) -> str:
    """Comparer Hive et Impala test par test, sur les sorties gardées dans logs."""
    deux_moteurs = resume[resume["statut"] == "OK"].groupby(["famille", "test"]).filter(
        lambda t: set(t["moteur"]) == {"hive", "impala"})
    ecarts, total = [], 0
    for (famille, test), _ in deux_moteurs.groupby(["famille", "test"], sort=False):
        hive, impala = (empreinte_sortie(famille, test, m) for m in ("hive", "impala"))
        if hive and impala:
            total += 1
            if hive != impala:
                ecarts.append(f"{famille} {test}")
    texte = (f"Les sorties sont comparées après retrait des guillemets qu'impala-shell ajoute aux libellés, "
             f"avec les nombres arrondis à 2 décimales. ")
    if not ecarts:
        return texte + f"Hive et Impala donnent le même résultat pour les {total} tests mesurés dans les deux moteurs.\n"
    return texte + (f"Hive et Impala donnent le même résultat pour {total - len(ecarts)} tests sur {total}. "
                    f"Les résultats diffèrent pour {', '.join(ecarts)}.\n")


def ecrire_resume(tableaux: dict[str, pd.DataFrame], resume: pd.DataFrame, mesures: pd.DataFrame):
    sections = ["# Résultats du benchmark\n\n",
                f"{len(mesures)} essais lus dans resultats.csv, du {mesures['horodatage'].min()} "
                f"au {mesures['horodatage'].max()} (heure de la VM). "
                "La médiane est prise sur les essais 2 à 4. Le premier essai, à froid, est donné à part.\n"]
    for famille, partie in tableaux.items():
        if len(partie):
            sections.append(f"\n## {famille}. {TITRES.get(famille, 'Jointures')}\n\n"
                            f"{COMPARAISONS[famille]}\n\n" + tableau_markdown(partie))
    sections.append("\n## Hive et Impala donnent-ils le même résultat ?\n\n" + comparer_moteurs(resume))
    (DOSSIER / "resultats_benchmark.md").write_text("".join(sections), encoding="utf-8")


def main():
    chemin = Path(sys.argv[1]) if len(sys.argv) > 1 else DOSSIER / "resultats.csv"
    (DOSSIER / "graphiques").mkdir(parents=True, exist_ok=True)
    mesures = lire_mesures(chemin)
    resume = verifier_resultats(resumer(mesures))

    for famille in ("F1", "F3", "F4"):
        if (resume["famille"] == famille).any():
            figure_par_moteur(resume[resume["famille"] == famille], famille)

    # le détail de B7, B1 et B2 a été mesuré dans F4, l'agrégat dans F5
    detail = resume[(resume["famille"] == "F4") & resume["test"].isin(["B7", "B1", "B2"])].copy()
    detail["test"] = detail["test"] + "_detail"
    for question in ("B7", "B1", "B2"):
        LIBELLES[f"{question}_detail"] = f"{question} détail"
    precalcul = pd.concat([detail, resume[resume["famille"] == "F5"]])
    precalcul["rang"] = precalcul["test"].str[:2].map({"B7": 0, "B1": 1, "B2": 2})
    if (precalcul["famille"] == "F5").any():
        figure_par_moteur(precalcul.sort_values(["rang", "famille"]), "F5")

    # le bucket map join avec indice a été mesuré après coup, il reprend sa place avant le sort-merge
    ordre_jointures = ["source_4_jointures", "etoile_1_jointure", "shuffle_join", "map_join",
                       "bucket_map_join", "bucket_map_join_indice", "sort_merge_bucket"]
    jointures = resume[resume["famille"] == "F6"]
    jointures = jointures.assign(rang=jointures["test"].map(ordre_jointures.index)).sort_values("rang")
    if len(jointures):
        figure_par_moteur(jointures[jointures["groupe"] == "REGION"], "F6a", moteurs=("hive",))
        figure_par_moteur(jointures[jointures["groupe"] == "SPECIALITE"], "F6b", moteurs=("hive",))
    volume = resume[resume["famille"] == "F7"].copy()
    if len(volume):
        figure_volume(resume)
    volume["rang"] = volume["test"].map(lambda t: (t.split("_")[0], int(t.split("_")[1].rstrip("M"))))

    # dans les tableaux, Hive passe avant Impala et le détail avant son agrégat
    tableaux = {f: resume[resume["famille"] == f].sort_values("moteur", kind="stable") for f in ("F1", "F3")}
    tableaux["F4"] = resume[resume["famille"] == "F4"]
    tableaux["F5"] = precalcul.sort_values(["moteur", "rang", "famille"])
    tableaux["F6"] = jointures.sort_values("moteur", kind="stable")
    tableaux["F7"] = volume.sort_values(["moteur", "rang"])
    ecrire_resume(tableaux, resume, mesures)
    print(f"{len(mesures)} essais, graphiques et résumé écrits dans {DOSSIER}")


if __name__ == "__main__":
    main()
