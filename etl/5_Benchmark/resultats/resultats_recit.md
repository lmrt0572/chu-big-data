# Chiffres du récit du benchmark

Médiane des essais 2 à 4, en secondes. VM : QuickStart CDH 5.12, une seule machine (2 cœurs, 8 Go). PostgreSQL 14 sur le PC, réglage d'installation sauf mention.

## Escalier avant/après (consultations par région)

| Marche | Temps médian (s) | Gain par rapport à la marche précédente |
|---|---|---|
| Tables d'origine, texte, 4 jointures, Hive | 185 |  |
| Modèle en étoile, texte, 1 jointure, Hive | 52 | 3,6 fois plus rapide |
| Étoile, Parquet, Hive | 57 | 1,1 fois plus lent |
| Étoile, Parquet, Impala | 0,71 | 80 fois plus rapide |
| Datamart, PostgreSQL, sans index | 0,90 | 1,3 fois plus lent |
| Datamart, PostgreSQL, indexé | 0,30 | 3,0 fois plus rapide |

## Volume réaliste : Impala et PostgreSQL

| Question | Moteur | 1 M | 10 M | 50 M | 100 M |
|---|---|---|---|---|---|
| B1 | Impala | 0,43 | 0,65 | 1,2 | 2,3 |
| B1 | PostgreSQL | 0,10 | 0,33 | 1,1 | – |
| B2 | Impala | 0,33 | 0,43 | 1,0 | 1,9 |
| B2 | PostgreSQL | 0,05 | 0,18 | 0,76 | – |
| B6 | Impala | 0,49 | 0,99 | 4,5 | 6,7 |
| B6 | PostgreSQL | 0,14 | 1,5 | 2,5 | – |

## Granularité des partitions dans Impala, pour les décès de 2019 puis de mars 2019

| Test | Impala | Fichiers sur le disque |
|---|---|---|
| Par année | 0,53 | 51 |
| Par mois | 0,56 | 603 |
| Par jour | 0,91 | 18352 |
| Mars 2019, par année | 0,71 | 51 |
| Mars 2019, par mois | 0,53 | 603 |
| Mars 2019, par jour | 0,65 | 18352 |

## Compression de Parquet, décès de 2019 par région

| Test | Hive | Impala | Place sur le disque (Mo) |
|---|---|---|---|
| Snappy (choix actuel) | 60 | 1,3 | 116 |
| Gzip | 56 | 0,98 | 52 |
| Sans compression | 73 | 0,83 | 218 |

## Statistiques des tables (COMPUTE STATS) dans Impala

| Test | Impala |
|---|---|
| B1 sans statistiques | 0,65 |
| B1 avec statistiques | 0,52 |
| B6 sans statistiques | 0,75 |
| B6 avec statistiques | 0,60 |

## Hive sur Spark au lieu de MapReduce

| Question | Hive sur MapReduce (04/11) | Hive sur Spark | 1er essai sur Spark |
|---|---|---|---|
| B7 | 83 | – | – |
| B1 | 124 | – | – |

## Plusieurs utilisateurs en même temps

| Moteur | Utilisateurs | Ouverture, médiane (s) | Utilisateur le plus lent (s) |
|---|---|---|---|
| Impala | 1 | 3,9 | 4,2 |
| Impala | 5 | 17 | 19 |
| Impala | 10 | 36 | 37 |
| PostgreSQL | 1 | 0,54 | 0,84 |
| PostgreSQL | 5 | 0,85 | 0,94 |
| PostgreSQL | 10 | 1,5 | 1,7 |

## Montée en charge du tableau de bord

| Moteur | Volume | Utilisateurs | Ouvertures | Échecs | Médiane (s) | 95e centile (s) | Ouvertures par minute |
|---|---|---|---|---|---|---|---|
| Impala sur le Gold (VM) | volume réel (1 M de consultations) | 1 | 7 | 0 | 4,2 | 6,8 | 3,5 |
| Impala sur le Gold (VM) | volume réel (1 M de consultations) | 2 | 16 | 0 | 4,2 | 5,8 | 8,0 |
| Impala sur le Gold (VM) | volume réel (1 M de consultations) | 5 | 37 | 0 | 7,4 | 11 | 18 |
| Impala sur le Gold (VM) | volume réel (1 M de consultations) | 10 | 41 | 0 | 20 | 34 | 20 |
| Impala sur le Gold (VM) | volume réel (1 M de consultations) | 20 | 44 | 0 | 54 | 65 | 22 |
| Impala sur le Gold (VM) | 10 M de consultations | 1 | 7 | 0 | 4,8 | 6,3 | 3,5 |
| Impala sur le Gold (VM) | 10 M de consultations | 2 | 14 | 1 | 4,6 | 9,3 | 6,5 |
| Impala sur le Gold (VM) | 10 M de consultations | 5 | 30 | 5 | 12 | 18 | 12 |
| Impala sur le Gold (VM) | 10 M de consultations | 10 | 40 | 31 | 20 | 29 | 4,5 |
| Impala sur le Gold (VM) | 10 M de consultations | 20 | 44 | 43 | 12 | 12 | 0,5 |
| Impala sur le Gold (VM) | 50 M de consultations | 1 | 6 | 0 | 8,6 | 9,3 | 3,0 |
| Impala sur le Gold (VM) | 50 M de consultations | 2 | 12 | 2 | 8,8 | 11 | 5,0 |
| Impala sur le Gold (VM) | 50 M de consultations | 5 | 26 | 19 | 21 | 23 | 3,5 |
| Impala sur le Gold (VM) | 50 M de consultations | 10 | 31 | 30 | 19 | 19 | 0,5 |
| Impala sur le Gold (VM) | 50 M de consultations | 20 | 43 | 43 | – | – | 0,0 |
| Datamart PostgreSQL (PC) | volume réel (1 M de consultations) | 1 | 11 | 0 | 0,37 | 0,43 | 5,5 |
| Datamart PostgreSQL (PC) | volume réel (1 M de consultations) | 2 | 21 | 0 | 0,35 | 0,40 | 10 |
| Datamart PostgreSQL (PC) | volume réel (1 M de consultations) | 5 | 63 | 0 | 0,34 | 0,44 | 32 |
| Datamart PostgreSQL (PC) | volume réel (1 M de consultations) | 10 | 118 | 0 | 0,35 | 0,44 | 59 |
| Datamart PostgreSQL (PC) | volume réel (1 M de consultations) | 20 | 221 | 0 | 0,35 | 0,45 | 110 |
| Datamart PostgreSQL (PC) | volume réel (1 M de consultations) | 50 | 562 | 0 | 0,45 | 0,60 | 281 |
| Datamart PostgreSQL (PC) | 10 M de consultations | 1 | 9 | 0 | 2,2 | 2,5 | 4,5 |
| Datamart PostgreSQL (PC) | 10 M de consultations | 2 | 18 | 0 | 2,3 | 2,5 | 9,0 |
| Datamart PostgreSQL (PC) | 10 M de consultations | 5 | 50 | 0 | 2,6 | 3,0 | 25 |
| Datamart PostgreSQL (PC) | 10 M de consultations | 10 | 94 | 0 | 2,9 | 3,9 | 47 |
| Datamart PostgreSQL (PC) | 10 M de consultations | 20 | 163 | 0 | 4,3 | 8,7 | 82 |
| Datamart PostgreSQL (PC) | 10 M de consultations | 50 | 159 | 0 | 33 | 46 | 80 |
| Datamart PostgreSQL (PC) | 50 M de consultations | 1 | 8 | 0 | 4,1 | 4,3 | 4,0 |
| Datamart PostgreSQL (PC) | 50 M de consultations | 2 | 15 | 0 | 4,2 | 5,8 | 7,5 |
| Datamart PostgreSQL (PC) | 50 M de consultations | 5 | 41 | 0 | 5,2 | 6,7 | 20 |
| Datamart PostgreSQL (PC) | 50 M de consultations | 10 | 67 | 0 | 9,2 | 14 | 34 |
| Datamart PostgreSQL (PC) | 50 M de consultations | 20 | 73 | 0 | 25 | 33 | 36 |
| Datamart PostgreSQL (PC) | 50 M de consultations | 50 | 99 | 0 | 70 | 95 | 50 |

## Contrôle des résultats

Dans chaque moteur, toutes les variantes d'un même groupe rendent le même résultat.
