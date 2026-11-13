# Tableau de bord Power BI

Ce dossier contient le rapport Power BI du projet : un tableau de bord sur l'activité hospitalière (consultations et hospitalisations), la mortalité et la satisfaction des patients, pour deux profils, les praticiens et la direction. Il répond aux huit indicateurs B1 à B8 du rapport d'analyse :

| Indicateur | Profil | Question |
|---|---|---|
| B1 | Direction | Quelle est la part de chaque établissement dans les consultations ? |
| B2 | Praticiens | Quelle est la part de chaque diagnostic dans les consultations ? |
| B3 | Direction | Quel est le taux global d'hospitalisation ? |
| B4 | Praticiens | Combien de séjours par diagnostic ? |
| B5 | Praticiens | Quel est le taux d'hospitalisation par sexe et par tranche d'âge ? |
| B6 | Praticiens | Combien de consultations par professionnel ? |
| B7 | Direction | Combien de décès par région ? |
| B8 | Direction | Quel est le score de satisfaction des patients par région ? |

Power BI lit la couche Gold du lac de données en DirectQuery, par Impala, sur la VM Cloudera. Il ne garde aucune copie des consultations, des séjours ni des décès : chaque graphique envoie sa requête SQL à Impala, qui fait le calcul dans le lac, et Power BI n'affiche que le résultat. Il n'y a ni datamart ni PostgreSQL. Le rapport compte quatre pages, avec une seule Synthèse pour les praticiens et pour la direction.

Les données ne sont pas dans le dépôt. Pour ouvrir le rapport, il faut avoir reconstruit le Gold avec les scripts de `../etl/`, et disposer des sources.

Quelques termes :

- **Gold** : la dernière couche du lac de données, organisée en schéma en étoile (des tables de faits entourées de tables de dimensions), prête à être interrogée.
- **Impala** : un moteur SQL qui lit directement les fichiers du lac et répond en quelques secondes.
- **Import et DirectQuery** : deux façons de brancher Power BI sur des données. En Import, Power BI copie les données dans son fichier. En DirectQuery, il les laisse où elles sont et envoie une requête à chaque affichage.
- **Vue** : une requête SQL enregistrée sous un nom. Elle ne stocke rien.

## Contenu du dossier

| Fichier | Rôle |
|---|---|
| `CHU_tableau_de_bord.pbit` | Le rapport en DirectQuery. Il se connecte à l'Impala de la VM du PC qui l'ouvre, et la VM doit tourner tant que le rapport est ouvert. |
| `vues_powerbi.sql` | Le script qui crée dans la base `gold` les quatorze vues `bi_` que lit le rapport. À lancer une fois sur la VM, avant d'ouvrir le `.pbit`. |
| `secours_import/` | La version Import du rapport (`CHU_tableau_de_bord.pbit`). Elle lit le Gold une fois, au chargement, et en garde une copie : une fois enregistrée en `.pbix`, elle s'ouvre sans VM. Ce `.pbix` contient des données, il n'est donc pas dans le dépôt. |
| `generation/` | Les scripts qui ont produit et vérifié le rapport, la carte des régions et la population INSEE. Ils ne servent pas pour ouvrir le rapport. |

Un fichier `.pbit` est un modèle de rapport sans données : il décrit les tables, les relations, les mesures et les pages, et demande les paramètres de connexion à l'ouverture.

## Pourquoi le DirectQuery

Les datamarts PostgreSQL de la première version ont été abandonnés. Recopier le modèle décisionnel dans une base relationnelle à côté du lac va contre le principe du Big Data : le calcul doit se faire là où sont les données, par les moteurs distribués du cluster. Le problème n'est pas le SQL. Hive et Impala sont justement des moteurs SQL qui tournent sur Hadoop, et le Gold lui-même est construit en HiveQL.

En mode Import, Power BI copie les données dans son propre fichier au chargement, puis calcule lui-même à chaque clic. Avec 100 millions de consultations, il faudrait tout importer, et Power BI jouerait le rôle du datamart qu'on vient de supprimer. En DirectQuery, rien n'est copié. Chaque visuel envoie sa requête SQL à Impala, qui lit les fichiers Parquet du Gold, calcule et ne renvoie que le résultat, quelques lignes en général. Le rapport tient donc quel que soit le volume du lac, tant que le cluster suit.

## Ce que fait Impala, ce que fait Power BI

Power BI ne lit pas directement les tables du Gold, mais les vues `bi_` créées par `vues_powerbi.sql`. Elles font les transformations que Power Query faisait en mode Import, car en DirectQuery chaque étape doit pouvoir se traduire en SQL pour Impala :

- les accents des spécialités les plus fréquentes, absents de la source (« Medecine Generale » devient « Médecine générale ») ;
- la date du jour au format date, et le premier jour du mois pour les courbes par mois ;
- le libellé de la région de chaque établissement, lu dans `dim_region` ;
- le libellé du sexe, et « Âge inconnu » pour la tranche inconnue ;
- les regroupements des décès par année et par région, de la satisfaction par année et par région, et des consultations par jour ;
- le taux d'hospitalisation du groupe (B3), par mois et par année.

Les vues ne reprennent que les colonnes utiles. Le pseudonyme du patient n'y figure pas, donc Power BI ne peut même pas le lire.

Chaque table du modèle a un mode de stockage :

| Mode | Tables | Ce qu'il fait |
|---|---|---|
| DirectQuery | faits des consultations et des séjours, établissements, professionnels, patients, diagnostics, regroupements des décès, de la satisfaction et des consultations par jour, taux du groupe | Rien n'est copié : Impala calcule à chaque visuel. |
| Double | temps, tranches d'âge, régions | Power BI garde une copie de ces petites tables (19 724 jours, 7 tranches, 21 régions) pour remplir vite les listes des filtres, et les joint aux faits dans le SQL envoyé à Impala. |
| Import | population INSEE | Elle ne vient pas du lac. C'est une table fixe de 194 lignes écrite dans le modèle. |

La barre d'état de Power BI affiche « Mode de stockage : Mixte » pour cette raison. Les mesures DAX sont les mêmes qu'en mode Import, et Power BI les traduit en SQL. Le rôle de sécurité « Direction démo Bretagne » devient une condition `WHERE` dans chaque requête envoyée à Impala.

## Réglages de la VM

Sur la VM QuickStart, Impala ne dispose par défaut que de 512 Mo de mémoire. C'est trop peu pour le DirectQuery. Une seule jointure entre les consultations et le million de professionnels dépasse cette limite, et quand une page envoie plusieurs requêtes à la fois, les visuels échouent (« Memory limit exceeded », puis `ETIMEDOUT` dans Power BI). Avant d'ouvrir le rapport, il faut donc, dans Cloudera Manager (`http://quickstart.cloudera:7180`) :

1. Arrêter le service « Cloudera Management Service », qui surveille les autres services et prend à lui seul plus de 1 Go. Arrêter aussi HBase et Oozie s'ils tournent. HDFS, Hive, Impala, YARN, ZooKeeper et Hue restent allumés.
2. Dans Impala, onglet Configuration, chercher `mem_limit` (« Limite de mémoire Impala Daemon »), mettre 3 Gio et enregistrer.
3. Redémarrer Impala.

Ces réglages sont réversibles, avec Démarrer pour les services et 512 Mio pour la limite. La VM a 8 Go de mémoire, et il reste assez de place avec ces arrêts. Avec ces réglages, une série de requêtes de vérification des chiffres est passée de 254 à 50 secondes, et plus aucun visuel n'a échoué.

## Temps de réponse

Les temps ci-dessous ont été mesurés sur la VM du projet (8 Go de mémoire), avec les réglages ci-dessus, dans une fenêtre Power BI neuve. Chaque page était donc ouverte pour la première fois. Le temps va de la première à la dernière requête reçue par Impala pour la page, d'après le journal d'Impala.

| Page | Requêtes envoyées à Impala | Temps | Requête la plus longue |
|---|---|---|---|
| Synthèse | 63 | 22 s | 7 s |
| Activité médicale | 27 | 9 s | 4 s |
| Établissements | 27 | 23 s | 9 s |
| Territoires | 34 | 10 s | 3 s |

Une page déjà affichée revient tout de suite, car Power BI garde les résultats en mémoire tant que les filtres ne changent pas. Changer un filtre renvoie des requêtes à Impala. Pour une démonstration, il vaut donc mieux ouvrir chaque page une fois, avec les filtres qu'on compte montrer.

Trois réglages du rapport ménagent la VM :

- **Quatre requêtes à la fois au plus.** Par défaut, Power BI en envoie jusqu'à dix en parallèle, ce qui sature une VM à un seul nœud.
- **Les 100 premières lignes des longs tableaux.** Les tableaux des diagnostics, des professionnels et des établissements ne montrent que les 100 premiers, et leur titre le dit (« Les 100 établissements les plus actifs »). Impala calcule ainsi les séjours et les patients de 100 lignes au lieu de plusieurs dizaines de milliers. La ligne de total est masquée, car elle n'additionnerait que ces 100 lignes. En mode Import, les tableaux restent complets.
- **Pas d'intégrité référentielle supposée.** Ce réglage permet en général des jointures plus rapides. Il empêchait le connecteur Impala de traduire certaines mesures en SQL (« Nous n'avons pas pu replier l'expression sur la source de données »), et il a été retiré.

## Les quatre pages

On passe d'une page à l'autre avec les onglets de Power BI, en bas de l'écran.

| Page | Indicateurs | Contenu |
|---|---|---|
| Synthèse | Les huit, de B1 à B8 | Les huit tuiles, celles des praticiens en haut (B2, B4, B5, B6) et celles de la direction en bas (B1, B3, B7, B8). Chaque tuile donne un chiffre, une ligne de contexte et un petit graphique. Le lien « Voir le détail » ouvre la page qui détaille l'indicateur. |
| Activité médicale | B2, B4, B5, B6 | Quatre chiffres clés, le taux d'hospitalisation par âge et par sexe, la part de chaque spécialité, puis les tableaux des diagnostics et des professionnels. |
| Établissements | B1, B3 | Quatre chiffres clés, dont la part des consultations sans établissement, le taux par mois comparé au groupe, les consultations par région et le tableau des établissements. |
| Territoires | B7, B8 | Deux cartes des régions (décès pour 100 000 habitants, écart de satisfaction au score national), le tableau des régions, la courbe des décès de 2010 à 2019 et les régions les plus et les moins bien notées. |

Dans Power BI Desktop, tant que le rapport est en mode modification, il faut maintenir Ctrl en cliquant sur « Voir le détail ». Un simple clic suffit en mode lecture, et dans le service Power BI.

## Les filtres

Chaque page commence par une barre de filtres sous forme de listes déroulantes.

- **Année de l'activité** : une ou plusieurs années, de 2015 à 2023, avec 2019 à l'ouverture. Elle agit sur les consultations et les hospitalisations, et suit d'une page à l'autre.
- **Année des décès**, sur la page Territoires : de 2010 à 2020, avec 2019 à l'ouverture, l'année retenue pour B7. L'année 2020 est incomplète, car le fichier des décès s'arrête au début de 2020, et le rapport l'écrit sous le chiffre.
- **Année de la satisfaction**, sur la page Territoires : 2019 ou 2020, les deux seules années du fichier, avec 2020 à l'ouverture, l'année retenue pour B8.
- **Région** : une ou plusieurs régions, avec une zone de recherche. Elle suit d'une page à l'autre et agit sur tous les visuels.
- **Sexe, âge, spécialité et diagnostic** sur la page Activité médicale. La spécialité et le diagnostic ont une zone de recherche, car la liste des diagnostics compte plus de 15 000 libellés.
- **Établissement** sur la page Établissements, avec une zone de recherche parmi les 416 666 établissements.

Chaque thème a sa propre liste d'années, car les données ne couvrent pas la même période. Une seule liste commune laisserait des visuels vides, par exemple la satisfaction pour 2017. Les listes des décès et de la satisfaction ne s'affichent que sur la page Territoires. La Synthèse en garde une copie invisible, reliée à celles de Territoires : ses tuiles B7 et B8 montrent 2019 et 2020 à l'ouverture, puis les années choisies sur Territoires. Sans ces copies, elles additionneraient toutes les années.

Toutes les listes acceptent plusieurs valeurs. On coche chaque valeur voulue, et si une liste n'en garde qu'une, il faut maintenir Ctrl en cliquant. Pour vider un filtre, il suffit de cliquer sur la gomme qui apparaît en haut à droite de la liste quand on la survole.

## Lire les graphiques et les tableaux

- **Les taux masqués sous 10 patients.** Le taux d'hospitalisation n'est pas affiché quand une case compte moins de 10 patients hospitalisés. C'est la règle du secret statistique : avec plusieurs filtres, une case peut ne correspondre qu'à un ou deux patients, qu'on pourrait alors reconnaître. Plus on filtre, plus des barres disparaissent.
- **Les séjours et la spécialité.** Dans les données, un séjour n'est relié à aucun professionnel. Quand on filtre une spécialité, les séjours et le taux d'hospitalisation restent donc vides, et le rapport l'écrit sous le chiffre.
- **Les zéros des tableaux.** Les séjours sont rares (374 en 2019, pour 87 497 consultations) et leurs diagnostics sont presque tous différents. La plupart des diagnostics vus en consultation n'ont donc aucun séjour, et le tableau affiche 0 plutôt qu'une case vide.
- **Les échelles.** Les barres partent toujours de zéro, et leur valeur est écrite au bout. Les courbes partent aussi de zéro, sauf celle des décès par an de la page Territoires, dont l'axe est resserré pour rendre visibles les écarts d'une année à l'autre, ce que son titre signale. Les petits graphiques des tuiles ont une échelle automatique, car ils montrent une forme et non un niveau.
- **Les courbes par année.** La courbe des décès de 2010 à 2019 et le petit graphique de la satisfaction montrent toujours toutes les années, quelle que soit l'année choisie, pour garder la tendance sous les yeux. Elles suivent en revanche le filtre Région.
- **L'axe des mois.** Les courbes par mois suivent le calendrier. Avec 2018 et 2019 cochées, elles vont de janvier 2018 à décembre 2019, au lieu d'additionner les deux mois de janvier.
- **Le taux du groupe sur plusieurs années.** La carte « Taux d'hospitalisation » ne donne le taux du groupe que pour une seule année, car des patients distincts ne s'additionnent pas d'une année à l'autre. Avec plusieurs années, elle l'indique.
- **Les cartes.** La carte des décès va du bleu clair au bleu marine selon le nombre de décès pour 100 000 habitants. La carte de la satisfaction montre l'écart au score national, en rouge sous la moyenne, en bleu au-dessus et en gris autour.

## Les décès rapportés à la population

Un nombre de décès dépend surtout de la taille de la région. Le rapport divise donc les décès de chaque région par sa population, et donne un nombre de décès pour 100 000 habitants.

La population vient des estimations de l'INSEE par région (fichier `estim-pop-nreg-sexe-gca-1975-2023.xls`, Licence ouverte), de 2010 à 2020. Elle est rangée dans `generation/population_regions.csv` et écrite dans le modèle comme une table fixe. Les décès à l'étranger, dans l'outre-mer hors région et de région inconnue ne sont pas comptés, faute de population. L'INSEE ne donne pas Mayotte avant 2014.

En 2019, la France compte 911,9 décès pour 100 000 habitants. La Nouvelle-Aquitaine est la plus haute (1 099,7), l'Île-de-France parmi les plus basses (627,8). Ces taux ne tiennent pas compte de l'âge des habitants, et une région âgée a plus de décès. Les comparer à structure d'âge égale est une piste d'amélioration.

## Activer la carte de formes

Les cartes de la page Territoires utilisent la carte de formes de Power BI. Elle dessine seulement les contours des régions, sans fond de carte ni zoom, et fonctionne sans internet. Dans la version 2.115 de Power BI, ce visuel est encore en préversion. Pour l'activer, il faut aller dans Fichier, Options et paramètres, Options, Fonctionnalités en préversion, cocher « Visuel Carte de formes », puis fermer et rouvrir Power BI. Ce réglage appartient à Power BI et non au fichier, donc chacun doit le cocher sur son propre PC.

Les contours viennent des données publiques de l'IGN (Admin Express 2018, Licence ouverte), par le dépôt GitHub `gregoiredavid/france-geojson`. Le script `generation/prep_carte.py` les simplifie et place les cinq régions d'outre-mer dans des encadrés, à gauche de la métropole. Chaque encadré a sa propre échelle, donc la taille des régions d'outre-mer ne se compare pas à celle de la métropole.

## Ouvrir le rapport en DirectQuery

1. Démarrer la VM Cloudera et faire les réglages de la partie « Réglages de la VM ».
2. Vérifier que le PC trouve la VM. Le nom `quickstart.cloudera` doit être relié à l'adresse de la VM par une ligne du fichier `C:\Windows\System32\drivers\etc\hosts`. Sans cette ligne, on peut donner directement l'adresse de la VM à l'étape 4, par exemple `192.168.74.132:21050`. L'adresse s'affiche dans un terminal de la VM avec la commande `ifconfig`.
3. Lancer `vues_powerbi.sql` une fois, dans l'éditeur Impala de Hue ou avec `impala-shell -i quickstart.cloudera -f vues_powerbi.sql`. La dernière requête du script doit redonner 87 497 consultations, 373 patients hospitalisés sur 58 797, 620 490 décès et les scores 73,43 et 73,64.
4. Double-cliquer sur `CHU_tableau_de_bord.pbit`. Si Power BI affiche « Risque potentiel de sécurité » (« Ce fichier utilise plusieurs sources de données »), cliquer sur OK : le modèle mêle Impala, en direct, et la population INSEE, copiée dans le fichier. Power BI demande ensuite deux paramètres, `Serveur` (`quickstart.cloudera:21050`) et `Base` (`gold`). Il suffit de garder les valeurs proposées, ou de mettre l'adresse de la VM dans `Serveur`, puis de cliquer sur Charger.
5. Power BI demande ensuite comment se connecter à Impala. Choisir **Anonyme**, car Impala n'a pas d'authentification sur la VM QuickStart, puis Se connecter. S'il signale qu'il ne peut pas chiffrer la connexion, accepter la connexion non chiffrée, puisque la VM tourne sur le même PC.
6. Le chargement prend moins d'une minute, car Power BI ne copie que les petites tables. La Synthèse s'affiche ensuite en une vingtaine de secondes.
7. On peut enregistrer le rapport en `.pbix` pour ne plus avoir à saisir les paramètres. Ce fichier ne contient pas les données du lac : il lui faut toujours la VM.

Le rapport utilise la colonne `libelle_region` de `dim_etablissement` quand le Gold l'a, mais il marche aussi avec un Gold plus ancien qui ne l'a pas, car la vue `bi_dim_etablissement` lit alors la région dans `dim_region`.

## Ouvrir la version de secours, sans VM

La version de `secours_import/` lit le Gold une fois, au chargement, et en garde une copie dans le fichier. Après un chargement réussi et un enregistrement en `.pbix`, le rapport s'ouvre en quelques secondes sans la VM. Ses pages et ses chiffres sont les mêmes que ceux de la version DirectQuery, à une différence près : les longs tableaux y sont complets. Le bouton Actualiser relit le Gold par Impala, donc il ne marche que si la VM tourne. Sinon, il suffit de fermer le rapport sans l'enregistrer.

## Versions de Power BI et Git

Le rapport a été construit avec Power BI Desktop 2.115 (mars 2023). Une version plus récente ouvre sans problème ces fichiers, mais l'inverse est faux : un `.pbix` enregistré avec une version récente ne s'ouvre pas avec une version plus ancienne. Un `.pbix` est un fichier binaire qui ne se fusionne pas, c'est pourquoi le dépôt garde les `.pbit` et les scripts de `generation/`, qui reconstruisent le modèle.

## Le modèle

Le modèle reprend le schéma en étoile du Gold, à travers les vues `bi_`. Les faits des consultations et des hospitalisations sont reliés aux dimensions du temps, du patient, de la tranche d'âge, de l'établissement, du diagnostic et du professionnel. Les regroupements des décès et de la satisfaction, ainsi que la population, sont reliés à la dimension des régions. Une relation va aussi de la région de l'établissement vers la dimension des régions : c'est elle qui permet à un seul filtre Région d'agir à la fois sur les consultations, les séjours, les décès et la satisfaction.

Une petite table calculée, `Années` (2010 à 2023), n'est reliée à aucune autre. Elle sert d'axe aux courbes par année, qui doivent montrer toutes les années même quand une liste d'années n'en garde qu'une.

Toutes les mesures DAX sont rangées dans la table `Mesures`, par dossier : consultations, hospitalisations, décès, satisfaction, puis « 5 Textes » (les lignes de contexte sous les chiffres), « 6 Couleurs » (les mesures qui renvoient une couleur, par exemple le rouge d'un écart négatif) et « 7 Tableaux » (les versions des mesures qui affichent 0 au lieu d'une case vide).

Quatre mesures méritent une explication.

- **B3 Taux d'hospitalisation** compte des patients et non des actes. Parmi les patients venus sur la période, en consultation ou en hospitalisation, il donne la part de ceux qui ont été hospitalisés. Un patient venu dix fois ne compte donc qu'une fois.
- **B3 Taux du groupe** donne le même taux pour le groupe entier. Il est lu dans les vues `bi_b3_groupe_mois` et `bi_b3_groupe_annee`, qu'Impala calcule et qui ne sont reliées à aucun établissement. Le rôle de sécurité ne les filtre donc pas, et une direction peut comparer son taux à celui du groupe sans voir les patients des autres établissements.
- **B1 Part de l'établissement** divise les consultations visibles par le total du groupe, lu dans la vue des consultations par jour, que le rôle ne filtre pas non plus.
- **B5 Taux d'hospitalisation (secret statistique)** reprend B3 par sexe ou par tranche d'âge, mais reste vide quand une case compte moins de 10 patients hospitalisés.

Le rapport contient un rôle de démonstration, « Direction démo Bretagne », qui ne voit que les établissements de Bretagne. Pour le montrer, il faut aller dans l'onglet Modélisation, cliquer sur « Voir comme », puis cocher ce rôle. En 2019, la part du groupe (B1) passe alors à 2,95 % et le taux d'hospitalisation à 0,59 %, contre 0,63 % pour le groupe. Le rôle est défini à l'échelle d'une région, car dans les données fournies chaque établissement n'a qu'un séjour au plus.

## Valeurs de référence

Ces valeurs sont celles que le rapport affiche sur le Gold du projet, calculées aussi par des requêtes Impala indépendantes et par les requêtes DAX de `generation/verifier_v3.ps1`. Elles permettent de vérifier un Gold reconstruit.

| Indicateur, année 2019 sauf mention | Valeur |
|---|---|
| Consultations | 87 497 |
| Séjours | 374 |
| Part des consultations sans établissement | 36,0 % |
| B2, part du diagnostic le plus fréquent | 0,02 %, sur 15 368 diagnostics |
| B3, patients hospitalisés sur patients venus | 373 sur 58 797, soit 0,63 % |
| B3 pour le rôle Bretagne, ou avec le filtre Région sur la Bretagne | 15 sur 2 556, soit 0,59 % |
| B4, part du diagnostic de séjour le plus fréquent | 0,53 %, sur 374 séjours |
| B5, taux d'hospitalisation par sexe | hommes 0,68 %, femmes 0,60 % |
| B6, part de la médecine générale | 50,4 % |
| B7, décès en 2019 | 620 490, soit 11,5 % de plus qu'en 2010 |
| B7, décès pour 100 000 habitants | France 911,9, Nouvelle-Aquitaine 1 099,7, Bretagne 1 061,6, Île-de-France 627,8 |
| B8, score national | 73,43 en 2019, 73,64 en 2020 |
| Écart au score national 2020 | Bretagne +1,32, Guyane −7,92 |
| Consultations et taux par région de l'établissement | Île-de-France 12 262 et 0,72 %, Bretagne 2 579 et 0,59 % |

L'évolution du score national entre 2019 et 2020 est affichée à +0,20 point. Elle est calculée sur les scores exacts, alors que la différence des scores arrondis (73,64 − 73,43) donne 0,21.

## Limites

- Le nombre de patients venus (dénominateur de B3) n'est pas entièrement calculé par Impala. Power BI lui demande la liste des patients de la période, puis les compte lui-même. Avec 58 797 patients en 2019, c'est rapide. Mais en DirectQuery, Power BI refuse toute réponse de plus d'un million de lignes, donc à 100 millions de consultations ce calcul devrait passer dans une vue Impala, comme le taux du groupe.
- Sur une VM à un seul nœud, une page met de 10 à 25 secondes à s'afficher la première fois. Sur un vrai cluster, Impala répartirait ces requêtes sur plusieurs machines.
- Les données fournies sont en partie synthétiques, ce qui limite certaines pages. Le diagnostic le plus fréquent ne représente que 0,02 % des consultations de 2019 (18 consultations sur 87 497), si bien que B2 et B4 ne font ressortir aucune pathologie dominante. Le fichier des décès s'arrête au début de 2020, d'où une année 2020 incomplète, que la courbe n'affiche pas.
- La requête B3 du benchmark (`../etl/5_Benchmark`) rapporte les patients hospitalisés à tous les patients de la base, alors que le rapport d'analyse et ce tableau de bord les rapportent aux patients venus sur la période.
