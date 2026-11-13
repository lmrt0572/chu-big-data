"""Montée en charge du tableau de bord : N utilisateurs qui consultent le tableau de bord pendant un temps donné.

Chaque utilisateur virtuel garde une connexion ouverte et répète le même scénario jusqu'à la fin de la fenêtre
de mesure : il ouvre le tableau de bord (les 8 requêtes B1 à B8 à la suite, comme les 8 visuels), puis le lit
pendant une pause tirée au hasard entre PAUSE_MIN et PAUSE_MAX secondes, puis l'ouvre de nouveau. Les
utilisateurs arrivent de façon étalée (décalage aléatoire au départ), et non tous à la même seconde.

Le simulateur tourne sur le PC pour les deux moteurs, avec le même code : les cœurs de la VM ne servent donc
qu'à Impala, contrairement à l'ancien test (concurrence.sh) qui lançait un impala-shell par utilisateur sur la VM.

Usage (Python avec impyla et psycopg) :
  python charge_tableau_de_bord.py impala  v1                 Gold sur la VM, volume réel
  python charge_tableau_de_bord.py postgres v1                datamart, volume réel
  python charge_tableau_de_bord.py postgres v50               datamart, consultations à 50 millions
Variables facultatives : NIVEAUX="1 2 5 10 20 50", DUREE=120 (secondes par niveau), PAUSE_MIN=5, PAUSE_MAX=15.
PostgreSQL : mot de passe lu dans PGPASSWORD ou pgpass.conf, jamais écrit ici. work_mem fixé à 64 Mo (réglage retenu).
Résultat : resultats/charge/charge_<moteur>_<volume>.csv, une ligne par requête et une ligne TOTAL par ouverture.
"""
import csv
import os
import random
import re
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

DOSSIER = Path(__file__).parent
REQUETES = {"impala": DOSSIER / "requetes" / "F4_moteur", "postgres": DOSSIER / "requetes" / "F2_postgres"}


def lire_requetes(moteur, volume="v1"):
    requetes = []
    for fichier in sorted(REQUETES[moteur].glob("B*.sql")):
        # Impala à 10 ou 50 M : B1, B2 et B6 lisent les consultations gonflées (bench.consult_v10, v50),
        # les mêmes requêtes que pour le test de volume. Les autres questions ne lisent pas les consultations.
        if moteur == "impala" and volume != "v1" and fichier.name[:2] in ("B1", "B2", "B6"):
            fichier = DOSSIER / "requetes" / "F7b_volume_realiste" / f"{fichier.name[:2]}_{volume[1:]}M.sql"
        texte = "\n".join(l for l in fichier.read_text(encoding="utf-8").splitlines() if not l.strip().startswith("--"))
        requetes.append((fichier.name[:2], texte.strip().rstrip(";")))
    assert len(requetes) == 8, f"8 requêtes attendues, {len(requetes)} trouvées"
    return requetes


def connecter(moteur, volume):
    if moteur == "impala":
        from impala.dbapi import connect
        return connect(host=os.environ.get("IMPALA_HOTE", "quickstart.cloudera"), port=21050,
                       auth_mechanism="NOSASL", timeout=600)
    import psycopg
    conn = psycopg.connect(host=os.environ.get("PGHOST", "localhost"), user=os.environ.get("PGUSER", "postgres"),
                           dbname=os.environ.get("PGDATABASE", "chu_bench"), autocommit=True)
    # v10 et v50 ne contiennent que les consultations à 10 et 50 M : les autres faits viennent de v1, les dimensions de dm.
    chemin = f"{volume},v1,dm" if volume in ("v10", "v50") else "v1,dm"
    conn.execute(f"SET search_path = {chemin}")
    conn.execute("SET work_mem = '64MB'")
    return conn


def utilisateur(moteur, volume, requetes, numero, niveau, debut_mesure, fin_mesure, lignes, verrou, graine):
    hasard = random.Random(graine)
    pause_min, pause_max = float(os.environ.get("PAUSE_MIN", 5)), float(os.environ.get("PAUSE_MAX", 15))
    conn = connecter(moteur, volume)
    cur = conn.cursor()
    # arrivée étalée : chaque utilisateur commence à un moment différent de la première pause
    attente = debut_mesure + hasard.uniform(0, pause_max) - time.time()
    if attente > 0:
        time.sleep(attente)
    ouverture = 0
    while time.time() < fin_mesure:
        ouverture += 1
        depart_ouverture = time.time()
        statut_ouverture = "OK"
        for nom, sql in requetes:
            t0 = time.time()
            try:
                cur.execute(sql)
                cur.fetchall()
                statut = "OK"
            except Exception as erreur:  # une erreur (mémoire d'Impala, délai) est un résultat, on la garde
                statut = "ECHEC " + re.sub(r"\s+", " ", str(erreur))[:120]
                statut_ouverture = "ECHEC"
                try:
                    conn.close()
                except Exception:
                    pass
                conn = connecter(moteur, volume)
                cur = conn.cursor()
            with verrou:
                lignes.append([niveau, numero, ouverture, nom, round(t0 - debut_mesure, 2), round(time.time() - t0, 3), statut])
        with verrou:
            lignes.append([niveau, numero, ouverture, "TOTAL", round(depart_ouverture - debut_mesure, 2),
                           round(time.time() - depart_ouverture, 3), statut_ouverture])
        time.sleep(max(0.0, min(hasard.uniform(pause_min, pause_max), fin_mesure - time.time())))
    conn.close()


def main():
    moteur, volume = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "v1"
    niveaux = [int(n) for n in os.environ.get("NIVEAUX", "1 2 5 10 20 50").split()]
    duree = float(os.environ.get("DUREE", 120))
    requetes = lire_requetes(moteur, volume)
    sortie = DOSSIER / "resultats" / "charge" / f"charge_{moteur}_{volume}.csv"
    sortie.parent.mkdir(parents=True, exist_ok=True)
    nouveau = not sortie.exists()
    with sortie.open("a", newline="", encoding="utf-8") as f:
        ecrivain = csv.writer(f, delimiter=";")
        if nouveau:
            ecrivain.writerow(["horodatage", "moteur", "volume", "utilisateurs", "utilisateur", "ouverture", "requete",
                               "debut_s", "secondes", "statut"])
        # une ouverture à vide pour chauffer les caches, non comptée
        conn = connecter(moteur, volume)
        cur = conn.cursor()
        for _, sql in requetes:
            cur.execute(sql)
            cur.fetchall()
        conn.close()
        for niveau in niveaux:
            print(f"{datetime.now():%H:%M:%S} {moteur} {volume} : {niveau} utilisateur(s) pendant {duree:.0f} s", flush=True)
            lignes, verrou = [], threading.Lock()
            debut = time.time() + 2
            fils = [threading.Thread(target=utilisateur, args=(moteur, volume, requetes, u, niveau, debut, debut + duree,
                                                               lignes, verrou, 1000 * niveau + u))
                    for u in range(1, niveau + 1)]
            for t in fils:
                t.start()
            for t in fils:
                t.join()
            horodatage = f"{datetime.now():%Y-%m-%d %H:%M:%S}"
            for ligne in sorted(lignes, key=lambda l: l[4]):
                ecrivain.writerow([horodatage, moteur, volume] + ligne)
            f.flush()
            totaux = sorted(l[5] for l in lignes if l[3] == "TOTAL")
            echecs = sum(1 for l in lignes if l[3] == "TOTAL" and l[6] != "OK")
            if totaux:
                print(f"   {len(totaux)} ouvertures, médiane {totaux[len(totaux) // 2]:.2f} s, "
                      f"95e centile {totaux[min(len(totaux) - 1, int(0.95 * len(totaux)))]:.2f} s, échecs {echecs}", flush=True)
            time.sleep(5)
    print(f"{datetime.now():%H:%M:%S} fin, résultats dans {sortie}")


if __name__ == "__main__":
    main()
