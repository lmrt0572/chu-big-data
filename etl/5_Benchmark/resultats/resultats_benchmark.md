# Résultats du benchmark

208 essais lus dans resultats.csv, du 2026-11-04 08:14:10 au 2026-11-04 13:46:35 (heure de la VM). La médiane est prise sur les essais 2 à 4. Le premier essai, à froid, est donné à part.

## F1. Partitionnement : décès de 2019 par région (B7)

Chaque test est comparé au test sans partition, dans le même moteur.

| Test | Moteur | 1er essai, à froid (s) | Médiane des suivants (s) | Comparaison | Lignes | Mo lus (Hive) | Même résultat que le groupe |
|---|---|---|---|---|---|---|---|
| Sans partition | Hive | 97 | 95 | référence | 20 | 16 | oui |
| Avec partition | Hive | 87 | 85 | 1,1 fois plus rapide | 20 | 0,4 | oui |
| Partition, filtre sur dim_temps | Hive | 171 | 173 | 1,8 fois plus lent | 20 | 28 | oui |
| Sans partition | Impala | 1,9 | 1,0 | référence | 20 |  | oui |
| Avec partition | Impala | 0,5 | 0,5 | 2,0 fois plus rapide | 20 |  | oui |
| Partition, filtre sur dim_temps | Impala | 3,0 | 1,4 | 1,4 fois plus lent | 20 |  | oui |

## F3. Format de stockage : décès de 2019 par département

Parquet est comparé au format texte, dans le même moteur.

| Test | Moteur | 1er essai, à froid (s) | Médiane des suivants (s) | Comparaison | Lignes | Mo lus (Hive) | Même résultat que le groupe |
|---|---|---|---|---|---|---|---|
| Texte | Hive | 168 | 169 | référence | 99 | 1179 | oui |
| Parquet | Hive | 109 | 105 | 1,6 fois plus rapide | 99 | 65 | oui |
| Texte | Impala | 8,3 | 1,1 | référence | 99 |  | oui |
| Parquet | Impala | 1,2 | 0,4 | 3,0 fois plus rapide | 99 |  | oui |

## F4. Moteur : les 8 questions métier sur le Gold

Impala est comparé à Hive, pour la même question.

| Test | Moteur | 1er essai, à froid (s) | Médiane des suivants (s) | Comparaison | Lignes | Mo lus (Hive) | Même résultat que le groupe |
|---|---|---|---|---|---|---|---|
| B1 | Hive | 125 | 124 |  | 22 778 | 11 | oui |
| B1 | Impala | 0,7 | 0,5 | 239 fois plus rapide | 22 778 |  | oui |
| B2 | Hive | 124 | 122 |  | 15 368 | 2,8 | oui |
| B2 | Impala | 0,5 | 0,4 | 322 fois plus rapide | 15 368 |  | oui |
| B3 | Hive | 116 | 118 |  | 1 | 0,5 | oui |
| B3 | Impala | 0,3 | 0,3 | 408 fois plus rapide | 1 |  | oui |
| B4 | Hive | 82 | 82 |  | 371 | 0,2 | oui |
| B4 | Impala | 0,4 | 0,4 | 215 fois plus rapide | 371 |  | oui |
| B5 | Hive | 121 | 118 |  | 14 | 0,6 | oui |
| B5 | Impala | 0,7 | 0,6 | 194 fois plus rapide | 14 |  | oui |
| B6 | Hive | 122 | 123 |  | 20 | 15 | oui |
| B6 | Impala | 0,6 | 0,6 | 217 fois plus rapide | 20 |  | oui |
| B7 | Hive | 83 | 83 |  | 20 | 0,4 | oui |
| B7 | Impala | 0,5 | 0,5 | 166 fois plus rapide | 20 |  | oui |
| B8 | Hive | 124 | 128 |  | 17 | 0,2 | oui |
| B8 | Impala | 1,0 | 0,8 | 169 fois plus rapide | 17 |  | oui |

## F5. Précalcul : calcul sur le détail ou lecture d'une table d'agrégat

Chaque agrégat est comparé au calcul sur le détail (mesuré dans F4), dans le même moteur.

| Test | Moteur | 1er essai, à froid (s) | Médiane des suivants (s) | Comparaison | Lignes | Mo lus (Hive) | Même résultat que le groupe |
|---|---|---|---|---|---|---|---|
| B7 détail | Hive | 83 | 83 | référence | 20 | 0,4 | oui |
| B7 agrégat | Hive | 46 | 45 | 1,8 fois plus rapide | 20 | < 0,1 | oui |
| B1 détail | Hive | 125 | 124 | référence | 22 778 | 11 | oui |
| B1 agrégat | Hive | 89 | 86 | 1,5 fois plus rapide | 22 778 | 9,3 | oui |
| B2 détail | Hive | 124 | 122 | référence | 15 368 | 2,8 | oui |
| B2 agrégat | Hive | 83 | 85 | 1,4 fois plus rapide | 15 368 | 1,0 | oui |
| B7 détail | Impala | 0,5 | 0,5 | référence | 20 |  | oui |
| B7 agrégat | Impala | 0,6 | 0,3 | 1,9 fois plus rapide | 20 |  | oui |
| B1 détail | Impala | 0,7 | 0,5 | référence | 22 778 |  | oui |
| B1 agrégat | Impala | 0,7 | 0,5 | aussi rapide | 22 778 |  | oui |
| B2 détail | Impala | 0,5 | 0,4 | référence | 15 368 |  | oui |
| B2 agrégat | Impala | 0,4 | 0,4 | aussi rapide | 15 368 |  | oui |

## F6. Jointures

Les jointures sont comparées aux tables d'origine pour la région, et au shuffle join pour la spécialité.

| Test | Moteur | 1er essai, à froid (s) | Médiane des suivants (s) | Comparaison | Lignes | Mo lus (Hive) | Même résultat que le groupe |
|---|---|---|---|---|---|---|---|
| Tables d'origine 4 jointures | Hive | 322 | 317 | référence | 13 | 308 | oui |
| Modèle en étoile 1 jointure | Hive | 86 | 82 | 3,9 fois plus rapide | 13 | 3,6 | oui |
| Shuffle join | Hive | 85 | 85 | référence | 66 | 8,6 | oui |
| Map join | Hive | 60 | 58 | 1,5 fois plus rapide | 66 | 4,1 | oui |
| Map join sur tables en buckets | Hive | 56 | 58 | 1,5 fois plus rapide | 66 | 1,6 | oui |
| Bucket map join | Hive | 213 | 74 | 1,1 fois plus rapide | 66 | 1,7 | oui |
| Sort-merge bucket join | Hive | 61 | 65 | 1,3 fois plus rapide | 66 | 6,1 | oui |
| Shuffle join | Impala | 1,9 | 1,2 | référence | 66 |  | oui |

## F7. Volume : consultations recopiées 1, 10 et 100 fois

Chaque palier est comparé au palier de 1 million, pour la même question et le même moteur.

| Test | Moteur | 1er essai, à froid (s) | Médiane des suivants (s) | Comparaison | Lignes | Mo lus (Hive) | Même résultat que le groupe |
|---|---|---|---|---|---|---|---|
| B1_1M | Hive | 129 | 128 | référence | 22 778 | 11 | oui |
| B1_10M | Hive | 129 | 129 | aussi rapide | 22 778 | 11 | oui |
| B1_100M | Hive | 355 | 176 | 1,4 fois plus lent | 22 778 | 12 | oui |
| B6_1M | Hive | 85 | 86 | référence | 66 | 8,6 | oui |
| B6_10M | Hive | 100 | 104 | 1,2 fois plus lent | 66 | 9,3 | oui |
| B6_100M | Hive | 238 | 256 | 3,0 fois plus lent | 66 | 11 | oui |
| B1_1M | Impala | 1,1 | 0,6 | référence | 22 778 |  | oui |
| B1_10M | Impala | 1,3 | 0,6 | aussi rapide | 22 778 |  | oui |
| B1_100M | Impala | 1,9 | 0,8 | 1,5 fois plus lent | 22 778 |  | oui |
| B6_1M | Impala | 2,2 | 1,3 | référence | 66 |  | oui |
| B6_10M | Impala | 2,3 | 1,9 | 1,5 fois plus lent | 66 |  | oui |
| B6_100M | Impala | 7,2 | 5,5 | 4,3 fois plus lent | 66 |  | oui |

## Hive et Impala donnent-ils le même résultat ?

Les sorties sont comparées après retrait des guillemets qu'impala-shell ajoute aux libellés, avec les nombres arrondis à 2 décimales. Hive et Impala donnent le même résultat pour 22 tests sur 23. Les résultats diffèrent pour F4 B8.
