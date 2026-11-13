# Benchmark (Livrable 2)

Le benchmark vérifie par la mesure les choix d'architecture du livrable 1, à savoir le modèle en étoile, le format Parquet, la partition des décès par année, Impala pour interroger le Gold, les datamarts PostgreSQL pour le tableau de bord et la règle de répartition. Il répond à une seule question, posée avant toute mesure. Le tableau de bord répond-il en moins de 2 minutes, et chaque choix y contribue-t-il réellement ?

Les tests du lac de données tournent dans la VM Cloudera (Hive et Impala). Ceux des datamarts tournent sur le PostgreSQL 14 du PC, dans une base d'essai `chu_bench` distincte des vrais datamarts (`chu_decisionnel`, job J31). Le benchmark n'écrit jamais dans `bronze`, `silver` ou `gold`. Ses tables de test sont dans la base Hive `bench` et dans `chu_bench`.

## 1. Fichiers

| Fichier | Rôle |
|---|---|
| `reglages_hive.sql` | Réglages mémoire communs à tous les essais Hive (conteneurs de 1 Go, `hive.auto.convert.join=false`) |
| `plan.txt`, `plan_suite.txt`, `plan_spark.txt` | Liste des tests, lue ligne par ligne par `lancer_benchmark.sh` (format `famille|test|groupe|fichier|moteurs`) |
| `prep_F*.hql`, `prep_N3_escalier.hql` | Préparent dans Hive les tables de test d'une famille. Relançables (`DROP TABLE IF EXISTS`) |
| `prep_F*_impala.sql` | Idem dans Impala, pour les familles que Hive ne peut pas préparer sur la VM (F1b, F7b, F8) |
| `requetes/` | Les requêtes mesurées, un dossier par famille. B1 à B8 sont dans `F4_moteur/` (HiveQL) et `F2_postgres/` (PostgreSQL) |
| `lancer_benchmark.sh` | Lance chaque test du plan 4 fois dans Hive puis dans Impala, calcule l'empreinte du résultat, garde le plan d'exécution |
| `exporter_postgres.sh` | Exporte du Gold, sur la VM, les tables utiles aux tests PostgreSQL (fichiers TSV, non livrés) |
| `postgres/01_creer_datamart.sql` | Crée et charge le datamart de test `chu_bench`, sans index ni contrainte |
| `postgres/02_volume.sql` | Fabrique les paliers de 10 et 50 millions de consultations |
| `postgres/index_0_aucun.sql`, `index_1_btree.sql`, `index_2_couvrant.sql` | Les trois états d'index comparés |
| `postgres/lancer_postgres.sh` | Lance B1 à B8 4 fois dans chaque état d'index et à chaque palier, avec ou sans `work_mem` à 64 Mo |
| `postgres/n3_escalier.sh` | Dernière marche de l'escalier, la question de l'escalier dans PostgreSQL |
| `charge_tableau_de_bord.py` | Montée en charge, plusieurs utilisateurs qui ouvrent le tableau de bord pendant 2 minutes par niveau |
| `concurrence.sh` | Premier test de concurrence, remplacé par `charge_tableau_de_bord.py` |
| `graphiques.py`, `graphiques_recit.py`, `graphiques_f2.py`, `graphiques_qualite.py` | Figures et tableaux de résultats, à partir des fichiers de `resultats/` |
| `L2_performance_et_qualite.md`, `L2_5-2_jeu_de_requetes.md` | Parties du livrable 2 qui présentent et analysent les mesures |
| `analyse_benchmark.md` | Analyse détaillée de toutes les mesures |

## 2. Lancer

Sur la VM, copier le dossier dans `/home/cloudera/bench`, puis :

```bash
cd /home/cloudera/bench
nohup bash lancer_benchmark.sh > run.log 2>&1 &                       # plan.txt
nohup bash lancer_benchmark.sh plan_suite.txt > run_suite.log 2>&1 &  # tests suivants
cat ETAT                                                              # test en cours
```

Le script retire lui-même les fins de ligne CRLF. Il peut être relancé après une panne, car les préparations faites (fichier `logs/<prep>.ok`) et les essais réussis sont sautés. Il lance `COMPUTE STATS` sur chaque table de test, sauf sur celles dont le nom contient `sans_stats`.

Sur le PC, dans Git Bash, avec le mot de passe dans `PGPASSWORD` ou dans `pgpass.conf` (jamais dans un fichier du projet) :

```bash
cd postgres
psql -U postgres -h localhost -c "CREATE DATABASE chu_bench ENCODING 'UTF8' TEMPLATE template0"
psql -U postgres -h localhost -d chu_bench -v ON_ERROR_STOP=1 -f 01_creer_datamart.sql
psql -U postgres -h localhost -d chu_bench -v ON_ERROR_STOP=1 -v schema=v10 -v copies=10 -f 02_volume.sql
psql -U postgres -h localhost -d chu_bench -v ON_ERROR_STOP=1 -v schema=v50 -v copies=50 -f 02_volume.sql
bash lancer_postgres.sh          # paliers de 1 et 10 millions
bash lancer_postgres.sh v50      # palier de 50 millions
cd ..
python charge_tableau_de_bord.py postgres v1    # puis v10, v50, et impala v1, v10, v50
```

`01_creer_datamart.sql` lit les TSV dans `export_postgres/`, produits sur la VM par `bash exporter_postgres.sh` puis copiés sur le PC. Ces fichiers contiennent des données de santé pseudonymisées et ne quittent pas le PC.

Ordre conseillé : `plan.txt`, puis `plan_suite.txt` sur la VM, en même temps que F2 sur le PC. La montée en charge se lance en dernier, un moteur à la fois, car la VM tourne sur le même PC.

## 3. Familles de tests

Chaque famille vérifie un choix du livrable 1 en ne changeant qu'un facteur à la fois, sur la même question métier. Les tests d'un même groupe doivent rendre le même résultat (même empreinte), sinon la comparaison ne vaut rien.

| Famille | Choix vérifié | Variantes comparées | Préparation |
|---|---|---|---|
| N3 Escalier | Tous les choix, un par marche | Tables d'origine en texte (4 jointures, Hive), étoile en texte, étoile en Parquet, Impala, datamart sans puis avec index | `prep_N3_escalier.hql`, `postgres/n3_escalier.sh` |
| F1 Partitionnement | Décès partitionnés par année | B7 sans partition, avec partition, avec un filtre qui ne porte pas sur la colonne de partition | `prep_F1_partitionnement.hql` |
| F1b Granularité | L'année est le bon découpage | Partitions par année, mois, jour, sur B7 et sur une question d'un mois | `prep_F1b_granularite_impala.sql` |
| F2 Index PostgreSQL | Index des datamarts | Sans index, B-tree sur chaque clé, index couvrants, à 1, 10 et 50 millions de lignes, `work_mem` de 4 ou 64 Mo | `postgres/` |
| F3 Format | Parquet | Les décès en texte et en Parquet | `prep_F3_format.hql` |
| F3b Compression | Snappy | Snappy, Gzip, sans compression (place et temps de B7) | `prep_F3b_compression.hql` |
| F4 Moteur | Hive pour charger, Impala pour interroger | B1 à B8 dans Hive et dans Impala | aucune (tables du Gold) |
| F5 Précalcul | Agrégats envoyés aux datamarts | B7, B1, B2 sur le détail et sur une table d'agrégat | `prep_F5_precalcul.hql` |
| F6 Jointures | Modèle en étoile, et méthode de jointure | 4 jointures contre 1, puis jointure redistribuée, map join, bucket map join, sort-merge bucket | `prep_F6_jointures.hql` |
| F7b Volume | Règle de répartition | B1, B2, B6 à 1, 10, 50 et 100 millions de consultations, dans Impala et PostgreSQL | `prep_F7b_volume_realiste_impala.sql`, `postgres/02_volume.sql` |
| F8 Statistiques | `COMPUTE STATS` après chaque chargement | B1 et B6 sur des copies sans statistiques | `prep_F8_statistiques_impala.sql` |
| F9 Hive sur Spark | Le coût fixe vient de MapReduce | B1 et B7 avec `hive.execution.engine=spark` | aucune |
| Charge | Servir le tableau de bord depuis PostgreSQL | 1 à 50 utilisateurs, Impala et PostgreSQL, à 1, 10 et 50 millions | `charge_tableau_de_bord.py` |

F7 (copies identiques des consultations) est remplacée par F7b, parce que des copies identiques se compressaient presque entièrement en Parquet. Ses requêtes et ses résultats sont gardés pour mémoire. F9 n'a pas abouti, YARN n'ayant jamais démarré les sessions Spark faute de mémoire sur la VM. Le premier test de concurrence (`concurrence.sh`) est remplacé par la montée en charge, plus proche de l'usage réel.

## 4. Requêtes B1 à B8

Les huit requêtes reprennent les indicateurs du livrable 1, sur 2019 pour les consultations, les séjours et les décès, et sur 2020 pour la satisfaction. Chaque fichier commence par un en-tête qui donne la définition du livrable 1, l'écart éventuel avec cette définition, les opérations éprouvées, le résultat attendu et les temps mesurés. La version PostgreSQL ne diffère de la version HiveQL que par `100.0` au lieu de `100`, pour éviter une division entière, et par B7, qui lit l'agrégat des décès au lieu du détail partitionné.

| Requête | Indicateur | Conformité au livrable 1 |
|---|---|---|
| B1 | Part de chaque établissement dans les consultations | Conforme |
| B2 | Part de chaque diagnostic dans les consultations | Conforme |
| B3 | Taux global d'hospitalisation | Simplifiée, dénominateur pris sur tous les patients et non sur les patients actifs (consultation ou séjour sur Y) |
| B4 | Séjours par diagnostic | Compte les séjours sans calculer la part |
| B5 | Hospitalisation par sexe et tranche d'âge | Simplifiée, sur toute la période, sans dénominateur ni règle du premier événement |
| B6 | Consultations par professionnel | Les 20 premiers professionnels, sans la part |
| B7 | Décès de 2019 par région | Conforme |
| B8 | Score e-Satis 2020 par région, pondéré | Conforme |

Les versions simplifiées de B3 et B5 ne combinent pas consultations et hospitalisations. Elles comptent des patients distincts sur 2 479 séjours seulement, ce qui en fait des requêtes légères. Les versions conformes, qui compteraient les patients distincts sur l'union des consultations et des séjours de la période, seraient sans doute les plus lourdes du jeu. Elles sont décrites en commentaire dans les fichiers mais n'ont pas été mesurées.

## 5. Protocole

- Chaque test est lancé 4 fois. Le premier essai, à froid, est écarté et l'on garde la médiane des essais 2 à 4.
- L'empreinte d'un résultat est calculée sur la sortie, nombres arrondis à 2 décimales et lignes triées, ce qui permet de vérifier que toutes les variantes d'un groupe et tous les moteurs répondent la même chose.
- Le seuil de lecture est de 2 minutes, fixé avant les mesures.
- Les copies de volume (F7b) ne recopient pas les consultations à l'identique. Chaque copie remplace l'établissement, le professionnel, le patient, le diagnostic et la date par d'autres valeurs réelles selon une formule fixe, la même dans Impala et dans PostgreSQL. Ces données gonflées ne servent jamais aux indicateurs.
- La montée en charge simule des utilisateurs qui ouvrent le tableau de bord (B1 à B8 à la suite), le lisent de 5 à 15 secondes puis l'ouvrent de nouveau, pendant 2 minutes par niveau, avec des arrivées étalées. Les clients tournent sur le PC pour les deux moteurs.

## 6. Résultats

| Fichier | Contenu |
|---|---|
| `resultats/resultats.csv` | F1 et F3 à F7, Hive et Impala, un essai par ligne |
| `resultats/suite/resultats_suite.csv` | F1b, F3b, F7b, F8, F9, N3 |
| `resultats/resultats_postgres.csv` | F2 et la dernière marche de N3 |
| `resultats/charge/charge_<moteur>_<volume>.csv` | Montée en charge, une ligne par requête et une ligne TOTAL par ouverture |
| `resultats/plans/`, `resultats/suite/plans/` | Plans d'exécution Hive et Impala (`EXPLAIN`) |
| `resultats/plans_postgres/` | Plans PostgreSQL (`EXPLAIN (ANALYZE, BUFFERS)`), un par requête, palier et état d'index |
| `resultats/logs/`, `resultats/suite/logs/` | Sortie de chaque test, journaux de préparation, taille des index (`postgres_index.csv`) |
| `resultats/graphiques/` | Toutes les figures |
| `resultats/resultats_benchmark.md`, `resultats_postgres.md`, `resultats_recit.md` | Tableaux de chiffres produits par les scripts de graphiques |

Les colonnes des fichiers d'essais sont `horodatage`, `famille`, `test`, `groupe`, `moteur`, `essai`, `secondes_moteur`, `secondes_total`, `lignes`, `octets_lus_hdfs`, `empreinte` et `statut` (OK ou ECHEC).

## 7. Limites

- Toutes les mesures sont faites sur une seule machine, la VM QuickStart (2 cœurs, 8 Go, 512 Mo pour Impala) et le PC qui l'héberge. Les écarts entre variantes d'un même moteur sont fiables, les temps absolus et les comparaisons entre Impala et PostgreSQL ne le sont pas.
- B3, B4, B5 et B6 sont des versions simplifiées des indicateurs du livrable 1 (section 4).
- L'écart d'arrondi de B8 dans Impala (71,59 au lieu de 71,60 pour la Martinique) est expliqué mais la variante corrigée n'a pas été mesurée.
- Le temps d'écriture des différentes compressions n'a pas été mesuré.
- Les bases `bench` (VM, environ 3,3 Go) et `chu_bench` (PC, environ 7,2 Go) sont à supprimer quand l'équipe n'en a plus besoin.
