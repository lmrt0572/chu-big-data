# Schémas

Ces schémas viennent des rapports des livrables 1 et 2 et du diaporama du livrable 3.

| Fichier | Ce qu'il montre | Origine |
|---|---|---|
| `architecture.png` | L'architecture de la solution : les sources, Talend, les couches Bronze, Silver et Gold sur HDFS, Impala, puis Power BI. | Diaporama du livrable 3 |
| `sources_liens.png` | Les sources, leurs volumes et les liens entre elles. Un trait plein est un lien vérifié, un pointillé un lien partiel ou à construire, avec la part de lignes que l'on retrouve. | Livrable 1 |
| `base_source_postgresql.png` | Les tables de la base PostgreSQL source, avec leurs clés et leur nombre de lignes. | Livrable 1 |
| `modele_dimensionnel_conceptuel.png` | Le modèle en constellation : quatre tables de faits (consultation, hospitalisation, décès, satisfaction) et leurs dimensions. Chaque fait porte les indicateurs B1 à B8 qu'il alimente. | Diaporama du livrable 3 |
| `modele_dimensionnel_logique.png` | Le même modèle avec les colonnes de chaque table. | Livrable 1 |
| `chaine_etl.png` | Les jobs de chaque étape (extraction, référentiels, personnes, événements, dimensions, faits, datamarts) et l'ordre dans lequel ils s'enchaînent. | Livrable 1 |
| `tracabilite_audit.png` | Ce que l'on garde à chaque couche pour retrouver l'origine d'une ligne, et la table d'audit qui compte une ligne par job exécuté. | Livrable 1 |

Le schéma de la chaîne de traitement date de la conception du livrable 1 : il prévoit une étape de datamarts PostgreSQL, que le livrable 3 a remplacée par une lecture directe du Gold par Impala (voir `architecture.png`).
