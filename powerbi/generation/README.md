# Génération du rapport

Ces scripts ont servi à produire et à vérifier le rapport Power BI. Ils ne sont pas nécessaires pour l'ouvrir ni pour l'utiliser : une fois le `.pbit` généré, le rapport se modifie directement dans Power BI Desktop.

| Script ou fichier | Rôle |
|---|---|
| `generer_pbit.py` | Écrit le modèle du rapport : requêtes Power Query sur Impala, tables, relations, mesures DAX, rôle de sécurité, thème et les quatre pages. |
| `regions_france.json` | La carte des 18 régions utilisée par la carte de formes, au format TopoJSON (35 Ko). `generer_pbit.py` l'intègre au rapport. |
| `prep_carte.py` | Construit `regions_france.json` à partir des contours publics de l'IGN (dépôt GitHub `gregoiredavid/france-geojson`, fichier `regions-avec-outre-mer.geojson`, Licence ouverte). L'outre-mer y est placé dans des encadrés, et les frontières communes sont simplifiées une seule fois pour que les régions voisines restent jointives. |
| `population_regions.csv` | Population de chaque région de 2010 à 2020 (colonnes `annee`, `code_region`, `population`), reprise de la colonne « Ensemble » du fichier INSEE `estim-pop-nreg-sexe-gca-1975-2023.xls`. `generer_pbit.py` l'écrit dans le modèle comme une table fixe. |
| `prep_donnees_test.py` | Prépare des copies TSV des tables lues par le rapport, y compris les trois regroupements, à partir des exports du Gold du livrable 2 (`Livrable_2/Benchmark/export_postgres`). Elles servent à tester le rapport sans la VM. |
| `reference.py` | Calcule avec pandas les valeurs attendues des indicateurs, pour les comparer à Power BI. |
| `pbi_outils.ps1` | Ouvre Power BI Desktop, capture sa fenêtre, lit et clique ses boutons, et interroge son moteur en DAX. |
| `verifier_v3.ps1` | Requêtes DAX de vérification de la version actuelle : tuiles de la synthèse, filtre Région, rôle Bretagne, cas particuliers, taux du groupe par mois et décès pour 100 000 habitants. |
| `verifier.ps1` | Requêtes DAX de vérification de la version 1, gardées pour mémoire. |

Le premier argument de `generer_pbit.py` choisit la source et le mode de stockage :

- `directquery` produit le rapport livré, `CHU_tableau_de_bord.pbit`. Il lit les vues `bi_` créées par `../vues_powerbi.sql`, avec les paramètres `Serveur` et `Base`. Les faits et les grosses dimensions sont en DirectQuery, le temps, les tranches d'âge et les régions en mode double.
- `import` produit la version de secours, `secours_import/CHU_tableau_de_bord.pbit`. Elle lit les tables du Gold une fois, au chargement, et en garde une copie.
- `tsv` produit un modèle de test qui lit les copies TSV du dossier donné en troisième argument.

```
python generer_pbit.py directquery ..\CHU_tableau_de_bord.pbit "" 0 <dossier d'un .pbix de référence décompressé>
python generer_pbit.py import ..\secours_import\CHU_tableau_de_bord.pbit "" 0 <même dossier>
```

Le quatrième argument donne la page affichée à l'ouverture (0 pour la Synthèse). Un fichier `.pbit` est une archive ZIP. `DataModelSchema` (le modèle, en JSON) et `Report/Layout` (les pages) y sont encodés en UTF-16. Le dernier argument pointe vers un `.pbix` décompressé créé par Power BI Desktop 2.115, dont le script copie le thème de base.
