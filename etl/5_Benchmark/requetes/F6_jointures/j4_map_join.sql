-- Famille F6 Jointures (modèle en étoile et méthodes de jointure de Hive), test j4_map_join (voir README_Benchmark.md).
-- Même requête en map join : la table des professionnels est chargée en mémoire dans chaque tâche.
SET hive.auto.convert.join=true;
-- Sur la VM, la tâche qui charge la petite table plante quand Hive la lance dans un programme à part.
SET hive.exec.submit.local.task.via.child=false;
SELECT p.specialite, COUNT(*) AS nb_consultations
FROM bench.consult_simple c
JOIN bench.prof_simple p ON c.id_professionnel = p.id_professionnel
GROUP BY p.specialite;
