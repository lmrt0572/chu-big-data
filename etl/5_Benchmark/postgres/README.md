# F2 : index du datamart PostgreSQL

Ce dossier mesure ce que rapportent les index sur le datamart PostgreSQL (moitié « indexation » des graphiques avant/après du sujet). Tout tourne sur le PC, avec le PostgreSQL 14 installé avec pgAdmin, et non sur la VM.

## Mise en place (une seule fois)

1. Mot de passe : créer `%APPDATA%\postgresql\pgpass.conf` avec la ligne `localhost:5432:*:postgres:MOT_DE_PASSE`. Ce fichier reste sur le PC. Il ne va jamais dans ce dossier.
2. Dans Git Bash, depuis `Benchmark/postgres` (ou `5_Benchmark/postgres` dans la livraison) :

```bash
PSQL="/c/Program Files/PostgreSQL/14/bin/psql.exe"
"$PSQL" -U postgres -h localhost -c "CREATE DATABASE chu_bench ENCODING 'UTF8' TEMPLATE template0"
"$PSQL" -U postgres -h localhost -d chu_bench -v ON_ERROR_STOP=1 -f 01_creer_datamart.sql
"$PSQL" -U postgres -h localhost -d chu_bench -v ON_ERROR_STOP=1 -v schema=v10 -v copies=10 -f 02_volume.sql
# facultatif, environ 3 Go sur le disque :
"$PSQL" -U postgres -h localhost -d chu_bench -v ON_ERROR_STOP=1 -v schema=v50 -v copies=50 -f 02_volume.sql
```

La dernière requête de `01_creer_datamart.sql` affiche le nombre de lignes de chaque table. Il doit être égal au nombre de lignes du fichier TSV moins l'en-tête (par exemple 1 027 157 consultations).

## Mesure

```bash
bash lancer_postgres.sh          # paliers de 1 et 10 millions
bash lancer_postgres.sh v50      # palier de 50 millions, s'il a été créé
```

Trois états d'index, avec 4 essais par requête (médiane des essais 2 à 4, comme sur la VM) :

| État | Fichier | Contenu |
|---|---|---|
| `sans_index` | `index_0_aucun.sql` | aucun index, ni clé primaire |
| `btree` | `index_1_btree.sql` | index unique sur l'identifiant de chaque dimension, un index par clé étrangère des faits |
| `couvrant` | `index_2_couvrant.sql` | état btree, plus des index (date) INCLUDE (colonnes regroupées), qui permettent de lire l'index seul |

Fichiers produits, dans `resultats/` :
- `resultats_postgres.csv` : les essais, au même format que `resultats.csv` (moteur `postgres`, famille `F2`) ;
- `logs/postgres_index.csv` : la durée de création et la place des index pour chaque palier et chaque état ;
- `plans_postgres/` : le plan réel (`EXPLAIN ANALYZE`) de chaque test, à ouvrir aussi dans pgAdmin ;
- `logs/sortie_F2_*` : la sortie de chaque test, pour comparer avec Hive et Impala.

## À savoir

- Les fichiers TSV sont produits sur la VM par `exporter_postgres.sh` à partir du Gold, puis copiés dans `export_postgres/`. Les huit questions B1 à B8 donnent le même résultat qu'en Gold, ce que vérifie l'empreinte de chaque test.
- Les paliers de 10 et 50 millions ne recopient pas les consultations à l'identique : chaque copie déplace les clés vers d'autres valeurs réelles. La formule est expliquée en tête de `02_volume.sql`. Le même calcul peut s'écrire dans Hive, ce qui donnerait les mêmes tables sur la VM.
- B3, B4, B5, B7 et B8 ne lisent pas les consultations : elles ne sont mesurées qu'au palier de 1 million.
- Ce sont des données de santé pseudonymisées : la base `chu_bench` et les TSV restent sur le PC.
