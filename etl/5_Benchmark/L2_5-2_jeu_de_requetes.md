### 5.2. Jeu de requêtes de benchmark

Plutôt que d'inventer des requêtes artificielles, nous avons bâti le benchmark sur les huit questions métier B1 à B8 définies au livrable 1, parce que ce sont exactement celles que le tableau de bord enverra, avec les mêmes filtres, les mêmes jointures et les mêmes regroupements, et qu'un temps mesuré sur elles se lit donc directement comme un temps d'affichage pour l'utilisateur. Chaque question est écrite deux fois, en HiveQL pour Hive et Impala, qui lisent le Gold, et en SQL pour PostgreSQL, qui lit les datamarts, et les deux versions ne diffèrent que par des détails de syntaxe, comme l'écriture `100.0` au lieu de `100` dans PostgreSQL, où la division de deux entiers rendrait sinon un entier. Nous n'avons pas branché Power BI pour ces mesures, car lancer directement les requêtes qu'il enverrait donne le temps de calcul sans y mêler le temps de dessin des visuels, qui ne dépend pas de notre architecture.

Les huit requêtes couvrent les quatre tables de faits du Gold et ne sollicitent pas toutes le moteur de la même façon, ce qui nous permet de voir sur quel type d'opération chaque choix physique pèse vraiment. On peut les ranger en quatre familles :

1. **Jointure et regroupement sur les consultations (B1, B2 et B6).** Ces trois requêtes filtrent l'année 2019 dans la table des consultations, qui compte 1 027 157 lignes et qui est de loin la plus grosse table que lit le tableau de bord, puis regroupent les lignes par établissement, par diagnostic ou par professionnel et les joignent à la dimension correspondante. B1 et B2 calculent en plus la part de chaque groupe dans le total, au moyen d'une fonction de fenêtre, et B6 trie les professionnels pour ne garder que les vingt premiers. Ce sont les requêtes qui lisent le plus de données et qui renvoient le plus de lignes, jusqu'à 22 778 pour B1.
2. **Comptage de patients distincts sur les hospitalisations (B3 et B5).** B3 compte les patients hospitalisés en 2019 et les rapporte au nombre total de patients de la base, et B5 compte à la fois les séjours et les patients distincts par sexe et par tranche d'âge, ce qui demande deux jointures. Le `COUNT(DISTINCT id_patient)` est en principe l'opération la plus coûteuse d'un moteur de requêtes, puisqu'il oblige à garder en mémoire, ou à trier, la liste de tous les patients déjà vus avant de pouvoir compter.
3. **Agrégation sur la table des décès (B7).** B7 additionne les décès de 2019 par région dans une table de 24,9 millions de lignes, ce qui en fait le test naturel du partitionnement par année, puisqu'un moteur qui exploite la partition n'ouvre que le dossier de 2019 au lieu des 51 dossiers de la table.
4. **Moyenne pondérée sur la satisfaction (B8).** B8 calcule le score e-Satis de 2020 par région en pondérant chaque établissement par son nombre de réponses, avec deux jointures, l'une vers la région et l'autre vers le calendrier pour filtrer l'année. La table est petite, mais la requête est la seule à diviser deux sommes décimales, ce qui met à l'épreuve la précision des moteurs plus que leur vitesse.

Les deux requêtes qui suivent illustrent les deux familles que nous attendions comme les plus lourdes, B1 pour les jointures sur un gros volume et B3 pour le comptage de valeurs distinctes.

```sql
-- B1, part de chaque établissement dans les consultations de 2019 (version Hive et Impala)
SELECT e.id_etablissement, e.raison_sociale, t.nb_consultations,
       ROUND(100 * t.nb_consultations / SUM(t.nb_consultations) OVER (), 2) AS part_pct
FROM (
    SELECT id_etablissement, COUNT(*) AS nb_consultations
    FROM gold.fait_consultation
    WHERE id_temps BETWEEN 20190101 AND 20191231
    GROUP BY id_etablissement
) t
JOIN gold.dim_etablissement e ON t.id_etablissement = e.id_etablissement;
```

```sql
-- B3, taux global d'hospitalisation en 2019, rapporté aux patients de la base
SELECT h.nb_patients_hospitalises, p.nb_patients,
       ROUND(100 * h.nb_patients_hospitalises / p.nb_patients, 2) AS taux_pct
FROM (
    SELECT COUNT(DISTINCT id_patient) AS nb_patients_hospitalises
    FROM gold.fait_hospitalisation
    WHERE id_temps_admission BETWEEN 20190101 AND 20191231
) h
CROSS JOIN (
    SELECT COUNT(*) AS nb_patients FROM gold.dim_patient WHERE id_patient <> -1
) p;
```

La requête B7 n'a pas la même forme dans les deux mondes, et cette différence est voulue. Dans le Gold, elle lit le détail des décès en filtrant sur la colonne de partition `annee_deces`, alors que dans le datamart elle lit la table `agg_deces_region`, qui ne compte que 1 068 lignes, une par région et par année, parce que la règle de répartition du livrable 1 n'envoie dans PostgreSQL que des décès déjà agrégés. Les deux versions rendent pourtant exactement le même résultat, ce que nous avons vérifié comme pour toutes les autres requêtes en comparant une empreinte calculée sur les lignes renvoyées par chaque moteur.

Ce contrôle des empreintes a d'ailleurs montré que la requête B8 était plus intéressante que prévu. Impala tronque en effet la division de deux nombres décimaux au lieu de l'arrondir, si bien qu'il affiche 71,59 pour la Martinique, là où Hive et PostgreSQL donnent 71,60. L'écart est minime, mais il aurait suffi à faire afficher deux chiffres différents pour le même indicateur selon l'outil utilisé, et il se corrige en convertissant les sommes en nombres à virgule flottante (`DOUBLE`) dans la version destinée à Impala.

Les mesures obligent enfin à nuancer ce que nous attendions de ces requêtes, et en particulier l'idée que le comptage de patients distincts serait l'opération la plus lourde du jeu. Sur nos données, c'est l'inverse qui se produit, parce que la table des hospitalisations ne compte que 2 479 séjours, si bien que B3 est l'une des requêtes les plus rapides, avec 0,29 seconde dans Impala et 0,01 seconde dans PostgreSQL, contre 0,52 et 0,17 seconde pour B1. Le coût d'un `COUNT(DISTINCT)` dépend du nombre de lignes qu'il doit parcourir bien plus que de l'opération elle-même, et ce sont donc les requêtes sur les consultations, B1 et B6, qui dominent le jeu, avec dans Hive environ 11 à 15 Mo lus contre moins de 0,5 Mo pour B3, B5 et B7. Nos requêtes B3 et B5 ne portent par ailleurs que sur les hospitalisations, alors qu'une version qui compterait les patients distincts sur les consultations et les hospitalisations réunies parcourrait plus d'un million de lignes et deviendrait sans doute la plus lourde du jeu. Nous ne l'avons pas mesurée, parce qu'aucun des huit indicateurs ne la demande, mais c'est elle qu'il faudrait ajouter si l'équipe voulait éprouver le comptage distinct dans des conditions réalistes.

Pour éprouver la règle de répartition au-delà du volume actuel, nous avons enfin reconduit les trois requêtes sur les consultations, B1, B2 et B6, sur des copies de la table portées à 10, 50 et 100 millions de lignes. À chaque copie, l'établissement, le professionnel, le patient, le diagnostic et la date sont remplacés par d'autres valeurs réelles selon une formule fixe, ce qui garantit que PostgreSQL et Impala travaillent sur exactement les mêmes lignes, alors que des copies identiques auraient faussé le test, puisque Parquet les aurait compressées presque entièrement. Ces données gonflées servent uniquement au benchmark et n'entrent jamais dans le calcul des indicateurs.
