"""Graphiques du récit du benchmark (plan du 05/11), à partir de toutes les mesures.

Usage : python graphiques_recit.py
Lit :
  resultats/suite/resultats_suite.csv   mesures de la VM (plan_suite.txt et plan_spark.txt)
  resultats/resultats_postgres.csv      mesures du datamart PostgreSQL (F2 et marche N3)
  resultats/resultats.csv               mesures du 04/11 (F4 : Hive et Impala sur le Gold)
  resultats/concurrence_*.csv           plusieurs utilisateurs en même temps
  resultats/suite/fichiers_tables.txt   nombre de fichiers et taille des tables de la VM
Écrit les graphiques dans resultats/graphiques/recit_*.png et les chiffres dans resultats/resultats_recit.md.
Un graphique n'est tracé que si ses mesures existent.
"""
import math
import os

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.ticker import FuncFormatter

from graphiques import (BLEU, BLEU_FONCE, DOSSIER, GRILLE, GRIS, SEUIL_SECONDES, habiller, lire_mesures,
                        nombre, resumer, verifier_resultats)

GRIS_CLAIR = "#A6A6A6"
ORANGE = "#C55A11"
SUITE = DOSSIER / "suite"
SORTIE = DOSSIER / "graphiques"


def secondes(v: float) -> str:
    if pd.isna(v):
        return "–"
    if v < 0.01:
        return "< 0,01"
    return f"{v:.2f}".replace(".", ",") if v < 1 else nombre(v)


def lire(chemin):
    if not chemin.exists():
        return pd.DataFrame(columns=["famille", "test", "groupe", "moteur", "mediane", "froid", "coherent"])
    return verifier_resultats(resumer(lire_mesures(chemin)))


def mediane(resume, famille, test, moteur):
    ligne = resume[(resume["famille"] == famille) & (resume["test"] == test) & (resume["moteur"] == moteur)]
    return ligne["mediane"].iloc[0] if len(ligne) else float("nan")


def axe_log(ax, valeurs):
    """Échelle logarithmique lisible, de 0,1 s au seuil de 2 minutes au moins."""
    ax.set_yscale("log")
    haut = max([v for v in valeurs if not pd.isna(v)] + [SEUIL_SECONDES])
    ax.set_ylim(0.1, haut * 3)
    ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:g}".replace(".", ",") + " s"))
    ax.axhline(SEUIL_SECONDES, color=GRIS, linestyle="--", linewidth=1, label="seuil de 2 minutes")
    ax.grid(axis="y", color=GRILLE, linewidth=0.8, which="major")
    ax.set_axisbelow(True)
    for cote in ("top", "right"):
        ax.spines[cote].set_visible(False)
    ax.tick_params(colors=GRIS, labelsize=9)


def figure_escalier(vm, pg, lignes_md):
    marches = [
        ("Tables d'origine\ntexte, 4 jointures\nHive", vm, "s0_origine_texte_4_jointures", "hive", GRIS_CLAIR),
        ("Modèle en étoile\ntexte, 1 jointure\nHive", vm, "s1_etoile_texte", "hive", GRIS_CLAIR),
        ("Étoile\nParquet\nHive", vm, "s2_etoile_parquet", "hive", GRIS_CLAIR),
        ("Étoile\nParquet\nImpala", vm, "s2_etoile_parquet", "impala", BLEU),
        ("Datamart\nPostgreSQL\nsans index", pg, "s3_datamart_sans_index", "postgres", BLEU_FONCE),
        ("Datamart\nPostgreSQL\nindexé", pg, "s3_datamart_index", "postgres", BLEU_FONCE),
    ]
    valeurs = [mediane(r, "N3", t, m) for _, r, t, m, _ in marches]
    if all(pd.isna(v) for v in valeurs):
        return
    fig, ax = plt.subplots(figsize=(10, 4.6))
    for x, ((libelle, _, _, _, couleur), v) in enumerate(zip(marches, valeurs)):
        ax.bar(x, 0 if pd.isna(v) else v, width=0.62, color=couleur)
        ax.annotate(secondes(v) + ("" if pd.isna(v) else " s"), (x, v if not pd.isna(v) else 0.1),
                    xytext=(0, 3), textcoords="offset points", ha="center", va="bottom", fontsize=9, color=GRIS)
    axe_log(ax, valeurs)
    ax.set_xticks(range(len(marches)))
    ax.set_xticklabels([m[0] for m in marches], fontsize=8.5)
    ax.legend(frameon=False, fontsize=8, loc="upper right")
    ax.set_ylabel("Temps médian (échelle logarithmique)", fontsize=9, color=GRIS)
    fig.suptitle("Consultations par région, avant et après chaque choix (un seul facteur change par marche)",
                 fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.tight_layout()
    fig.savefig(SORTIE / "recit_escalier.png", dpi=200)
    plt.close(fig)
    lignes_md += ["## Escalier avant/après (consultations par région)\n",
                  "| Marche | Temps médian (s) | Gain par rapport à la marche précédente |", "|---|---|---|"]
    precedent = None
    for (libelle, *_), v in zip(marches, valeurs):
        gain = "" if precedent is None or pd.isna(v) or pd.isna(precedent) else (
            f"{nombre(precedent / v)} fois plus rapide" if precedent >= v else f"{nombre(v / precedent)} fois plus lent")
        lignes_md.append(f"| {libelle.replace(chr(10), ', ')} | {secondes(v)} | {gain} |")
        precedent = v if not pd.isna(v) else precedent
    lignes_md.append("")


def figure_volume(vm, pg, lignes_md):
    paliers = [1, 10, 50, 100]
    questions = {"B1": ("B1 établissements", BLEU_FONCE), "B2": ("B2 diagnostics", BLEU), "B6": ("B6 professionnels", ORANGE)}
    impala = {q: [mediane(vm, "F7b", f"{q}_{p}M", "impala") for p in paliers] for q in questions}
    # PostgreSQL dans sa meilleure configuration mesurée : index couvrant, work_mem 64 Mo à partir de 10 M.
    postgres = {q: [mediane(pg, "F2", f"{q}_1M_couvrant", "postgres")]
                + [mediane(pg, "F2", f"{q}_{p}M_couvrant_wm64MB", "postgres") for p in (10, 50)] + [float("nan")]
                for q in questions}
    if all(pd.isna(v) for q in questions for v in impala[q]):
        return
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.4), sharey=True)
    for ax, (titre, donnees) in zip(axes, (("Impala sur la VM (Gold, Parquet)", impala),
                                           ("PostgreSQL sur le PC (datamart, index couvrant)", postgres))):
        for q, (libelle, couleur) in questions.items():
            points = [(p, v) for p, v in zip(paliers, donnees[q]) if not pd.isna(v)]
            if points:
                ax.plot([p for p, _ in points], [v for _, v in points], marker="o", color=couleur, label=libelle)
                p, v = points[-1]
                ax.annotate(secondes(v) + " s", (p, v), xytext=(4, 0), textcoords="offset points",
                            fontsize=8, color=couleur, va="center")
        ax.set_xscale("log")
        ax.set_xticks(paliers)
        ax.set_xticklabels([f"{p} M" for p in paliers])
        ax.set_xlabel("Consultations (échelle logarithmique)", fontsize=9, color=GRIS)
        ax.set_title(titre, fontsize=10, color=BLEU_FONCE, loc="left")
        ax.set_ylim(0, 8)
        ax.grid(axis="y", color=GRILLE, linewidth=0.8)
        for cote in ("top", "right"):
            ax.spines[cote].set_visible(False)
        ax.tick_params(colors=GRIS, labelsize=9)
        ax.legend(frameon=False, fontsize=8, loc="upper left")
    axes[0].set_ylabel("Temps médian (s)", fontsize=9, color=GRIS)
    fig.suptitle("Les deux moteurs restent sous 10 secondes jusqu'à 50 et 100 millions de consultations",
                 fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.text(0.01, 0.01, "Seuil de 2 minutes hors du graphique. PostgreSQL : work_mem 64 Mo à 10 et 50 M. "
             "Machines différentes : PostgreSQL a tout le PC, Impala les 2 cœurs et 512 Mo de la VM.",
             fontsize=7.5, color=GRIS)
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    fig.savefig(SORTIE / "recit_volume.png", dpi=200)
    plt.close(fig)
    lignes_md += ["## Volume réaliste : Impala et PostgreSQL\n",
                  "| Question | Moteur | 1 M | 10 M | 50 M | 100 M |", "|---|---|---|---|---|---|"]
    for q in questions:
        lignes_md.append(f"| {q} | Impala | " + " | ".join(secondes(v) for v in impala[q]) + " |")
        lignes_md.append(f"| {q} | PostgreSQL | " + " | ".join(secondes(v) for v in postgres[q]) + " |")
    lignes_md.append("")


COULEURS_MOTEURS = {"hive": GRIS_CLAIR, "impala": BLEU, "postgres": BLEU_FONCE}


def barres_par_moteur(ax, resume, famille, tests, moteurs):
    """Une grappe par test, une barre par moteur, sur l'échelle logarithmique commune (0,1 s à plus de 2 min)."""
    largeur = 0.8 / len(moteurs)
    toutes = []
    for i, moteur in enumerate(moteurs):
        valeurs = [mediane(resume, famille, t, moteur) for t, _ in tests]
        toutes += valeurs
        positions = [x + (i - (len(moteurs) - 1) / 2) * largeur for x in range(len(tests))]
        ax.bar(positions, [0 if pd.isna(v) else v for v in valeurs], width=largeur * 0.95,
               color=COULEURS_MOTEURS.get(moteur, BLEU_FONCE), label=moteur.capitalize())
        for x, v in zip(positions, valeurs):
            if not pd.isna(v):
                ax.annotate(secondes(v) + " s", (x, v), xytext=(0, 3), textcoords="offset points",
                            ha="center", va="bottom", fontsize=8.5, color=GRIS,
                            bbox=dict(facecolor="white", edgecolor="none", pad=1))
    axe_log(ax, toutes)
    ax.set_xticks(range(len(tests)))
    ax.set_xticklabels([l for _, l in tests], fontsize=8.5)
    ax.set_ylabel("Temps médian (échelle logarithmique)", fontsize=9, color=GRIS)
    ax.legend(frameon=False, fontsize=8, loc="upper left", ncol=len(moteurs) + 1)


def figure_partition_moteurs():
    """B7 sans partition, avec partition et avec le mauvais filtre : Hive et Impala sur la même échelle (mesures du 04/11)."""
    ancien = lire(DOSSIER / "resultats.csv")
    if not (ancien["famille"] == "F1").any():
        return
    tests = [("sans_partition", "Sans partition"), ("avec_partition", "Partition par année,\nfiltre sur annee_deces"),
             ("mauvais_filtre", "Partition par année,\nfiltre sur dim_temps")]
    fig, ax = plt.subplots(figsize=(9, 4.4))
    barres_par_moteur(ax, ancien, "F1", tests, ["hive", "impala"])
    fig.suptitle("Décès de 2019 par région (B7) avec et sans partition, Hive et Impala sur la même échelle",
                 fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.tight_layout()
    fig.savefig(SORTIE / "recit_partition_annee.png", dpi=200)
    plt.close(fig)


def figure_barres(resume, famille, tests, titre, fichier, lignes_md, libelles_md, moteurs=("hive", "impala")):
    """Une figure à un panneau par moteur, une barre par test (partitions, compression, statistiques)."""
    partie = resume[resume["famille"] == famille]
    presents = [m for m in moteurs if (partie["moteur"] == m).any()]
    if not presents:
        return
    if len(presents) > 1:
        # Plusieurs moteurs : une grappe par test sur une seule échelle logarithmique, pour comparer
        # Hive (dizaines de secondes) et Impala (moins d'une seconde) sur le même axe, dans la même unité.
        fig, ax = plt.subplots(figsize=(1.9 * len(tests) + 2, 4.4))
        barres_par_moteur(ax, resume, famille, tests, presents)
    else:
        fig, ax = plt.subplots(figsize=(1.6 * len(tests) + 1.5, 4.2))
        valeurs = [mediane(resume, famille, t, presents[0]) for t, _ in tests]
        ax.bar(range(len(tests)), [0 if pd.isna(v) else v for v in valeurs], width=0.6, color=BLEU_FONCE)
        for x, v in enumerate(valeurs):
            ax.annotate(secondes(v) + ("" if pd.isna(v) else " s"), (x, 0 if pd.isna(v) else v), xytext=(0, 3),
                        textcoords="offset points", ha="center", va="bottom", fontsize=9, color=GRIS)
        ax.set_xticks(range(len(tests)))
        ax.set_xticklabels([l for _, l in tests], fontsize=8.5)
        ax.set_title(presents[0].capitalize(), fontsize=11, color=BLEU_FONCE, loc="left")
        habiller(ax, max([v for v in valeurs if not pd.isna(v)], default=0))
    fig.suptitle(titre, fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.tight_layout()
    fig.savefig(SORTIE / fichier, dpi=200)
    plt.close(fig)
    lignes_md += [f"## {titre}\n", "| " + " | ".join(["Test"] + [m.capitalize() for m in presents] + libelles_md) + " |",
                  "|---|" + "---|" * (len(presents) + len(libelles_md))]
    return presents


def tailles_vm():
    """Nombre de fichiers et Mo de chaque table de la VM, d'après hdfs dfs -count."""
    chemin = SUITE / "fichiers_tables.txt"
    if not chemin.exists():
        return {}
    tailles = {}
    for ligne in chemin.read_text(encoding="utf-8").splitlines():
        champs = ligne.split()
        if len(champs) >= 4:
            tailles[champs[0]] = (int(champs[1]), int(champs[2]), int(champs[3]) / 1e6)
    return tailles


def figure_concurrence(lignes_md):
    morceaux = [pd.read_csv(c, sep=";") for c in sorted(DOSSIER.glob("concurrence_*.csv"))]
    if not morceaux:
        return
    donnees = pd.concat(morceaux)
    donnees = donnees[donnees["statut"] == "OK"]
    resume = donnees.groupby(["moteur", "utilisateurs"])["secondes_ouverture"].agg(["median", "max"]).reset_index()
    fig, ax = plt.subplots(figsize=(7, 4.2))
    for moteur, couleur in (("impala", BLEU), ("postgres", BLEU_FONCE)):
        partie = resume[resume["moteur"] == moteur]
        if len(partie):
            ax.plot(partie["utilisateurs"], partie["median"], marker="o", color=couleur,
                    label=f"{'Impala (VM)' if moteur == 'impala' else 'PostgreSQL (PC)'}, temps médian")
            ax.fill_between(partie["utilisateurs"], partie["median"], partie["max"], color=couleur, alpha=0.15)
            for _, l in partie.iterrows():
                ax.annotate(secondes(l["median"]) + " s", (l["utilisateurs"], l["median"]), xytext=(5, -10),
                            textcoords="offset points", fontsize=8, color=couleur)
    ax.set_xticks(sorted(resume["utilisateurs"].unique()))
    ax.set_xlabel("Utilisateurs qui ouvrent le tableau de bord en même temps", fontsize=9, color=GRIS)
    habiller(ax, resume["max"].max())
    ax.set_ylabel("Temps d'ouverture des 8 visuels (s)", fontsize=9, color=GRIS)
    fig.suptitle("Ouverture du tableau de bord (B1 à B8 à la suite) par plusieurs utilisateurs en même temps",
                 fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.text(0.01, 0.01, "Bande colorée : du temps médian à l'utilisateur le plus lent. 3 tours par niveau.",
             fontsize=7.5, color=GRIS)
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    fig.savefig(SORTIE / "recit_concurrence.png", dpi=200)
    plt.close(fig)
    lignes_md += ["## Plusieurs utilisateurs en même temps\n",
                  "| Moteur | Utilisateurs | Ouverture, médiane (s) | Utilisateur le plus lent (s) |", "|---|---|---|---|"]
    for _, l in resume.iterrows():
        lignes_md.append(f"| {'Impala' if l['moteur'] == 'impala' else 'PostgreSQL'} | {l['utilisateurs']} | {secondes(l['median'])} | {secondes(l['max'])} |")
    lignes_md.append("")


VOLUMES_CHARGE = {"v1": ("volume réel (1 M de consultations)", BLEU_FONCE),
                  "v10": ("10 M de consultations", BLEU),
                  "v50": ("50 M de consultations", ORANGE)}
MOTEURS_CHARGE = {"impala": "Impala sur le Gold (VM)", "postgres": "Datamart PostgreSQL (PC)"}


def figure_charge(lignes_md):
    """Montée en charge (charge_tableau_de_bord.py) : un panneau par moteur, même échelle, une couleur par volume."""
    morceaux = [pd.read_csv(c, sep=";") for c in sorted((DOSSIER / "charge").glob("charge_*.csv")) if c.stat().st_size > 200]
    if not morceaux:
        return
    donnees = pd.concat(morceaux)
    totaux = donnees[donnees["requete"] == "TOTAL"]
    duree = float(os.environ.get("DUREE_CHARGE", 120))
    lignes = []
    for (moteur, volume, n), partie in totaux.groupby(["moteur", "volume", "utilisateurs"]):
        ok = partie[partie["statut"] == "OK"]["secondes"]
        lignes.append({"moteur": moteur, "volume": volume, "utilisateurs": n, "ouvertures": len(partie),
                       "echecs": int((partie["statut"] != "OK").sum()),
                       "mediane": ok.median() if len(ok) else float("nan"),
                       "p95": ok.quantile(0.95) if len(ok) else float("nan"),
                       "par_minute": len(ok) / duree * 60})
    resume = pd.DataFrame(lignes)
    niveaux = sorted(resume["utilisateurs"].unique())
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.8), sharey=True)
    for ax, (moteur, titre) in zip(axes, MOTEURS_CHARGE.items()):
        for volume, (libelle, couleur) in VOLUMES_CHARGE.items():
            partie = resume[(resume["moteur"] == moteur) & (resume["volume"] == volume)].sort_values("utilisateurs")
            if not len(partie):
                continue
            # Un palier où plus de la moitié des ouvertures échouent (mémoire d'Impala dépassée) n'a pas de durée
            # fiable : la médiane ne porterait que sur les rares réussites. Il est marqué d'une croix, en pointillés.
            fiable = partie[partie["echecs"] <= 0.5 * partie["ouvertures"]]
            sature = partie[partie["echecs"] > 0.5 * partie["ouvertures"]]
            ax.plot(fiable["utilisateurs"], fiable["mediane"], marker="o", color=couleur, label=libelle)
            ax.fill_between(fiable["utilisateurs"], fiable["mediane"], fiable["p95"], color=couleur, alpha=0.15)
            if len(sature):
                suite = pd.concat([fiable.tail(1), sature])
                ax.plot(suite["utilisateurs"], suite["mediane"], linestyle=":", color=couleur)
                ax.plot(sature["utilisateurs"], sature["mediane"], linestyle="none", marker="x", markersize=8,
                        markeredgewidth=2, color=couleur)
            if len(fiable):
                dernier = fiable.iloc[-1]
                ax.annotate(secondes(dernier["mediane"]) + " s", (dernier["utilisateurs"], dernier["mediane"]),
                            xytext=(6, 0), textcoords="offset points", fontsize=8, color=couleur, va="center")
        axe_log(ax, list(resume["p95"]))
        ax.set_xscale("log")
        ax.set_xticks(niveaux)
        ax.set_xticklabels([str(n) for n in niveaux])
        ax.minorticks_off()
        ax.set_xlim(min(niveaux) * 0.8, max(niveaux) * 1.6)
        ax.set_xlabel("Utilisateurs simultanés (échelle logarithmique)", fontsize=9, color=GRIS)
        ax.set_title(titre, fontsize=10, color=BLEU_FONCE, loc="left")
        ax.legend(frameon=False, fontsize=8, loc="upper left", bbox_to_anchor=(0.0, 0.85))
    axes[0].set_ylabel("Durée d'ouverture des 8 visuels (échelle logarithmique)", fontsize=9, color=GRIS)
    fig.suptitle("Durée d'ouverture du tableau de bord selon le nombre d'utilisateurs et le volume",
                 fontsize=12, color=BLEU_FONCE, x=0.01, ha="left")
    fig.text(0.01, 0.01, "Ligne, durée médiane. Bande colorée, jusqu'au 95e centile (95 % des ouvertures sont plus rapides). "
             "Chaque utilisateur consulte le tableau de bord pendant 2 minutes\net le relit 5 à 15 s entre deux ouvertures. "
             "Machines différentes, PostgreSQL dispose de tout le PC et Impala des 2 cœurs et 512 Mo de la VM.\n"
             "Croix et pointillés, plus de la moitié des ouvertures en échec (mémoire d'Impala dépassée), durée non fiable.",
             fontsize=7.5, color=GRIS)
    fig.tight_layout(rect=(0, 0.09, 1, 1))
    fig.savefig(SORTIE / "recit_charge.png", dpi=200)
    plt.close(fig)
    lignes_md += ["## Montée en charge du tableau de bord\n",
                  "| Moteur | Volume | Utilisateurs | Ouvertures | Échecs | Médiane (s) | 95e centile (s) | Ouvertures par minute |",
                  "|---|---|---|---|---|---|---|---|"]
    for _, l in resume.iterrows():
        lignes_md.append(f"| {MOTEURS_CHARGE.get(l['moteur'], l['moteur'])} | {VOLUMES_CHARGE.get(l['volume'], (l['volume'],))[0]} | "
                         f"{l['utilisateurs']} | {l['ouvertures']} | {l['echecs']} | {secondes(l['mediane'])} | "
                         f"{secondes(l['p95'])} | {nombre(l['par_minute'])} |")
    lignes_md.append("")


def main():
    SORTIE.mkdir(parents=True, exist_ok=True)
    vm = lire(SUITE / "resultats_suite.csv")
    pg = lire(DOSSIER / "resultats_postgres.csv")
    tailles = tailles_vm()
    md = ["# Chiffres du récit du benchmark\n",
          "Médiane des essais 2 à 4, en secondes. VM : QuickStart CDH 5.12, une seule machine (2 cœurs, 8 Go). "
          "PostgreSQL 14 sur le PC, réglage d'installation sauf mention.\n"]

    figure_escalier(vm, pg, md)
    figure_partition_moteurs()
    figure_volume(vm, pg, md)

    partitions = [("B7_annee", "Par année"), ("B7_mois", "Par mois"), ("B7_jour", "Par jour"),
                  ("mars_annee", "Mars 2019,\npar année"), ("mars_mois", "Mars 2019,\npar mois"),
                  ("mars_jour", "Mars 2019,\npar jour")]
    # Impala seulement : les essais Hive, faussés par la mémoire saturée de la VM, ont été arrêtés (voir plan_suite.txt).
    presents = figure_barres(vm, "F1b", partitions, "Granularité des partitions dans Impala, pour les décès de 2019 puis de mars 2019",
                             "recit_partitions.png", md, ["Fichiers sur le disque"], moteurs=("impala",))
    if presents:
        for t, l in partitions:
            fichiers = tailles.get(f"bench.deces_p_{t.split('_')[1]}", (None, None, None))[1]
            md.append(f"| {l.replace(chr(10), ' ')} | " + " | ".join(secondes(mediane(vm, "F1b", t, m)) for m in presents)
                      + f" | {fichiers if fichiers else ''} |")
        md.append("")

    compression = [("snappy", "Snappy\n(choix actuel)"), ("gzip", "Gzip"), ("non_compresse", "Sans\ncompression")]
    presents = figure_barres(vm, "F3b", compression, "Compression de Parquet, décès de 2019 par région",
                             "recit_compression.png", md, ["Place sur le disque (Mo)"])
    if presents:
        for t, l in compression:
            mo = tailles.get(f"bench.deces_{t}", (None, None, None))[2]
            md.append(f"| {l.replace(chr(10), ' ')} | " + " | ".join(secondes(mediane(vm, "F3b", t, m)) for m in presents)
                      + f" | {nombre(mo) if mo else ''} |")
        md.append("")

    statistiques = [("B1_sans_stats", "B1 sans\nstatistiques"), ("B1_avec_stats", "B1 avec\nstatistiques"),
                    ("B6_sans_stats", "B6 sans\nstatistiques"), ("B6_avec_stats", "B6 avec\nstatistiques")]
    presents = figure_barres(vm, "F8", statistiques, "Statistiques des tables (COMPUTE STATS) dans Impala",
                             "recit_statistiques.png", md, [], moteurs=("impala",))
    if presents:
        for t, l in statistiques:
            md.append(f"| {l.replace(chr(10), ' ')} | {secondes(mediane(vm, 'F8', t, 'impala'))} |")
        md.append("")

    spark = vm[vm["famille"] == "F9"]
    if len(spark):
        ancien = lire(DOSSIER / "resultats.csv")
        md += ["## Hive sur Spark au lieu de MapReduce\n", "| Question | Hive sur MapReduce (04/11) | Hive sur Spark | 1er essai sur Spark |",
               "|---|---|---|---|"]
        for q in ("B7", "B1"):
            md.append(f"| {q} | {secondes(mediane(ancien, 'F4', q, 'hive'))} | "
                      f"{secondes(mediane(vm, 'F9', f'{q}_hive_spark', 'hive'))} | "
                      f"{secondes(spark[spark['test'] == f'{q}_hive_spark']['froid'].iloc[0]) if (spark['test'] == f'{q}_hive_spark').any() else '–'} |")
        md.append("")

    figure_concurrence(md)
    figure_charge(md)

    incoherents = pd.concat([vm, pg])
    incoherents = incoherents[incoherents["coherent"] == "NON"]
    md.append("## Contrôle des résultats\n")
    md.append("Dans chaque moteur, toutes les variantes d'un même groupe rendent le même résultat."
              if incoherents.empty else
              "Variantes dont le résultat diffère de leur groupe : "
              + ", ".join(f"{r.famille} {r.test} ({r.moteur})" for r in incoherents.itertuples()) + ".")
    (DOSSIER / "resultats_recit.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"graphiques recit_*.png et resultats_recit.md écrits dans {DOSSIER}")


if __name__ == "__main__":
    main()
