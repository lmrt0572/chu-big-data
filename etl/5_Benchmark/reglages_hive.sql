-- Réglages Hive communs à tous les tests, chargés par lancer_benchmark.sh avant chaque requête.
-- Ce sont ceux du Silver et du Gold : sans eux, les jointures et l'écriture Parquet échouent sur la VM.
-- Un test peut en changer un dans son propre fichier (par exemple le map join).
SET hive.auto.convert.join=false;
SET mapreduce.map.memory.mb=1024;
SET mapreduce.map.java.opts=-Xmx820m;
SET mapreduce.reduce.memory.mb=1024;
SET mapreduce.reduce.java.opts=-Xmx820m;
SET parquet.compression=SNAPPY;
