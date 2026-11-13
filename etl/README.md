# Scripts du projet CHU (Bronze, Silver, Gold, Datamarts, Benchmark)

Ce dossier regroupe les scripts qui construisent les quatre couches de l'entrepôt, dans l'ordre où on les lance, ainsi que le benchmark du livrable 2 avec ses résultats. Les jobs portent les numéros de la fiche des jobs du livrable 1, à savoir J01 à J04 pour le Bronze, J11 à J17 pour le Silver, J21 et J22 pour le Gold et J31 pour les datamarts. Les noms des fichiers `.hql` ne doivent pas être changés, parce que les scripts de lancement les appellent par leur nom.

La clé HMAC de pseudonymisation n'est dans aucun fichier de ce dossier. Le contexte Talend `CHU_Bronze` la demande à l'exécution (sa valeur est vide dans l'export) et elle est conservée à part, dans un fichier de propriétés qui n'est jamais partagé. Les données de santé, même pseudonymisées, ne sont pas non plus dans ce dossier.

## 1_Bronze (Talend puis Hive)

- `bronze_tables.hql` crée la base `bronze` et ses tables externes sur `/chu/bronze`, partitionnées par date de chargement.
- `talend/jobs_talend_J01_J04.zip` est l'export du projet Talend `PROJET_BIG_DATA`, à importer tel quel dans Talend. Il contient les jobs J01 à J04, la routine `ChuCrypto` et les contextes.
- `talend/J01_Base_PostgreSQL.item`, `J02_Referentiels.item`, `J03_Hospitalisations.item`, `J04_Open_Data.item` et `J04b_Esatis_2020.item` sont les mêmes jobs sortis de l'export, pour pouvoir les lire sans Talend (`J04b` est la partie e-Satis 2020 du job J04). `routine_ChuCrypto.item` est la routine de pseudonymisation.
- `referentiel_insee/` contient les deux fichiers INSEE 2025 (régions et départements) lus par J02.
- `verifier_bronze.hql` contrôle les volumes après chargement.

## 2_Silver (Hive, sur la VM)

- `silver_tables.hql` crée les tables Silver en Parquet, puis `J11_referentiels.hql` à `J17_satisfaction.hql` les remplissent.
- `lancer_silver.sh` enchaîne tout (`bash lancer_silver.sh 2026-10-30`, ou un seul job avec `bash lancer_silver.sh 2026-10-30 J16_deces`).
- `verifier_silver.hql` fait les contrôles de la couche.

## 3_Gold (Hive, sur la VM)

- `gold_tables.hql` crée le schéma en étoile (sept dimensions et quatre faits, décès partitionnés par année), `J21_dimensions.hql` remplit les dimensions et `J22_faits.hql` les faits.
- `lancer_gold.sh` enchaîne le tout puis la vérification (`nohup bash lancer_gold.sh 2026-10-30 > run.log 2>&1 &`).
- `verifier_gold.hql` contrôle les volumes, l'unicité des clés et le rattachement de chaque fait à ses dimensions.

## 4_Datamarts (PostgreSQL, puis la VM)

- `datamarts_tables.sql` crée la base `chu_decisionnel` (schémas `chargement`, `datamart_praticiens` et `datamart_direction`), les tables avec leurs clés primaires et étrangères, et les fonctions de publication.
- `datamarts_securite.sql` crée les rôles par profil, les droits par colonne, les vues métier et la sécurité au niveau des lignes de la direction.
- `datamarts_index.sql` pose les index B-tree sur les clés étrangères des faits et les index couvrants des requêtes du tableau de bord.
- `J31_datamarts.sh`, sur la VM, lance `J31_datamarts.hql` (copie texte du Gold et agrégats), puis l'export Sqoop et la publication transactionnelle. Le mot de passe du compte de chargement `chu_etl` est lu dans un fichier de la VM en droits `400` et n'est écrit nulle part ici.

Ordre de mise en place, une seule fois : `datamarts_tables.sql`, puis `datamarts_securite.sql`, puis `datamarts_index.sql`. Le premier recrée les tables, il faut donc relancer les deux autres après lui.

## 5_Benchmark (VM et PostgreSQL)

Le benchmark du livrable 2, avec ses scripts, ses résultats et les rapports qui les analysent. `README_Benchmark.md` décrit chaque fichier, la façon de lancer les tests, les familles de tests, les requêtes B1 à B8 et leurs écarts avec les définitions du livrable 1, le protocole et l'emplacement de chaque résultat. Les scripts s'appellent par des chemins relatifs et doivent garder cette arborescence. Les fichiers TSV exportés du Gold, qui contiennent des données de santé pseudonymisées, ne sont pas livrés.

## Rappels pour la VM

- Les fichiers venant de Windows ont des fins de ligne CRLF, il faut lancer `sed -i 's/\r$//' *.sh *.hql` avant de les exécuter.
- Tout job Hive tourne avec `hive.auto.convert.join=false` et des conteneurs MapReduce de 1 Go, sinon il échoue sur « Java heap space ».
