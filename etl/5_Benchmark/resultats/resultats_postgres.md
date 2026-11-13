# F2 : index et réglage du datamart PostgreSQL

232 essais lus dans resultats_postgres.csv, du 2026-11-05 13:31:54 au 2026-11-05 20:10:50 (heure du PC). Médiane des essais 2 à 4, en secondes. Réglage d'installation de PostgreSQL 14 (work_mem 4 Mo, shared_buffers 128 Mo).

## Effet des index

| Palier | Question | Sans index | B-tree par clé | Index couvrant | Même résultat |
|---|---|---|---|---|---|
| 1 million | B1 | 0,17 | 0,10 | 0,10 | oui |
| 1 million | B2 | 0,10 | 0,04 | 0,05 | oui |
| 1 million | B3 | 0,01 | 0,01 | 0,01 | oui |
| 1 million | B4 | < 0,01 | < 0,01 | < 0,01 | oui |
| 1 million | B5 | 0,02 | 0,02 | 0,02 | oui |
| 1 million | B6 | 0,20 | 0,14 | 0,14 | oui |
| 1 million | B7 | < 0,01 | < 0,01 | < 0,01 | oui |
| 1 million | B8 | < 0,01 | 0,01 | < 0,01 | oui |
| 10 millions | B1 | 0,72 | 0,46 | 0,45 | oui |
| 10 millions | B2 | 0,49 | 0,25 | 0,14 | oui |
| 10 millions | B6 | 1,7 | 1,9 | 3,3 | oui |
| 50 millions | B1 | 3,6 | 4,0 | 1,1 | oui |
| 50 millions | B2 | 3,2 | 3,6 | 0,64 | oui |
| 50 millions | B6 | 6,5 | 6,0 | 7,3 | oui |

## Coût des index

| Palier | État | Création (s) | Place des index (Mo) | Table des consultations (Mo) |
|---|---|---|---|---|
| 1 million | Sans index | – | – | 62 |
| 1 million | B-tree par clé | 6,6 | 81 | 62 |
| 1 million | Index couvrant | 8,4 | 114 | 62 |
| 10 millions | Sans index | – | – | 619 |
| 10 millions | B-tree par clé | 33 | 447 | 619 |
| 10 millions | Index couvrant | 63 | 803 | 619 |
| 50 millions | Sans index | – | – | 3094 |
| 50 millions | B-tree par clé | 229 | 1900 | 3094 |
| 50 millions | Index couvrant | 354 | 3552 | 3094 |

## Mémoire de travail, état « sans index »

| Palier | Question | work_mem 4 Mo | work_mem 64 Mo | Même résultat |
|---|---|---|---|---|
| 10 millions | B1 | 0,72 | 0,71 | oui |
| 10 millions | B2 | 0,49 | 0,50 | oui |
| 10 millions | B6 | 1,7 | 1,1 | oui |
| 50 millions | B1 | 3,6 | 2,6 | oui |
| 50 millions | B2 | 3,2 | 2,5 | oui |
| 50 millions | B6 | 6,5 | 5,4 | oui |

## Mémoire de travail, état « index couvrant »

| Palier | Question | work_mem 4 Mo | work_mem 64 Mo | Même résultat |
|---|---|---|---|---|
| 10 millions | B1 | 0,45 | 0,33 | oui |
| 10 millions | B2 | 0,14 | 0,18 | oui |
| 10 millions | B6 | 3,3 | 1,5 | oui |
| 50 millions | B1 | 1,1 | 1,1 | oui |
| 50 millions | B2 | 0,64 | 0,76 | oui |
| 50 millions | B6 | 7,3 | 2,5 | oui |
