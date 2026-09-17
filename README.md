# ⚡ Projet 8 - GreenAndCoop : Infrastructure de données Forecast 2.0

## 📌 Présentation du Projet
Dans le cadre de l'optimisation de son modèle prédictif d'approvisionnement en électricité renouvelable (*Forecast 2.0*), la coopérative GreenAndCoop renforce son réseau de capteurs météorologiques dans les Hauts-de-France[cite: 1].  
L'objectif est d'intégrer de manière résiliente et automatisée les relevés provenant de réseaux semi-professionnels (**InfoClimat**) et amateurs (**Weather Underground**) afin d'alimenter les modèles de Machine Learning sous AWS SageMaker[cite: 1].

---

## 🏗️ Architecture & Pipeline ELT
* **Extraction & Chargement (Ingestion) :** Airbyte extrait et charge les données brutes (flux JSON InfoClimat et classeurs Excel Weather Underground) directement vers PostgreSQL dans le schéma `raw`[cite: 1].
* **Stockage Cloud :** Base managée Amazon RDS PostgreSQL (`eu-west-3`, Paris) dimensionnée pour la production, avec environnement miroir local conteneurisé sous Docker.
* **Transformation & Qualité :** dbt Core orchestrant une architecture en couches (`staging`, `intermediate`, `marts`) avec tests d'intégrité automatisés.
* **Modélisation analytique :** Schéma en étoile composé d'une table de dimension (`dim_weather_stations`) et d'une table de faits unifiée (`fct_weather_readings`) optimisée par des index B-tree composites[cite: 1].
* **Orchestration Cloud cible :** Exécution conteneurisée sous AWS ECS et monitoring centralisé sous Amazon CloudWatch[cite: 1].

---

## 🚀 Guide d'Installation & Commandes

### 1. Préparation de l'environnement virtuel
```bash
python -m venv venv
# Windows :
.\venv\Scripts\Activate.ps1
# Linux / macOS :
source venv/bin/activate

pip install -r requirements.txt
```

### 2. Démarrage de l'infrastructure locale (Optionnel / Dev)
```bash
docker-compose -f docker/docker-compose.yml up -d
```

### 3. Configuration du profil de connexion dbt
Pour exécuter dbt, configurer le fichier `profiles.yml` dans votre répertoire utilisateur (`~/.dbt/profiles.yml` sous Linux/macOS ou `C:\Users\<User>\.dbt\profiles.yml` sous Windows) à partir du modèle fourni :
```bash
cp dbt/greenandcoop_dbt/profiles.yml.example ~/.dbt/profiles.yml
```

### 4. Exécution du pipeline dbt
```bash
cd dbt/greenandcoop_dbt

# 1. Validation de la connectivité (local ou AWS RDS)
dbt debug --target dev
dbt debug --target prod

# 2. Exécution des transformations par couche ou globale
dbt run --target prod

# 3. Validation de la qualité des données (10 tests automatisés)
dbt test --target prod

# 4. Consultation du Data Catalog et du Lineage Graph
dbt docs generate --target prod
dbt docs serve
```

---

## 🔄 Journal de bord & Avancement

### Session 1 : Couche Staging dbt & Audit des sources brutes
* **Déballage JSON d'InfoClimat (`stg_infoclimat.sql`) :**[cite: 1]
  * Extraction de l'objet semi-structuré `hourly` via `jsonb_each()` et `jsonb_array_elements()`[cite: 1].
  * Exclusion du nœud technique d'API `_params`[cite: 1].
  * Extraction des mesures pour les 4 stations réelles (`00052`, `000R5`, `07015`, `STATIC0010`)[cite: 1].
  * Validation du modèle en vue PostgreSQL (`PASS=1`)[cite: 1].
* **Audit de la rupture temporelle Weather Underground :**[cite: 1]
  * Constat : Absence de colonne de date dans les tables brutes `wu_ichtegem_raw` et `wu_la_madeleine_raw`[cite: 1]. Les dates figuraient uniquement dans les noms d'onglets Excel (`011024` à `071024`), non préservés lors de l'ingestion Airbyte[cite: 1].
  * Détection : Vérification de l'ordre séquentiel strict dans PostgreSQL (7 passages exacts à minuit `00:04:00`)[cite: 1].
* **Reconstruction de la donnée brute dans le Staging (`stg_wu_ichtegem.sql` & `stg_wu_la_madeleine.sql`) :**[cite: 1]
  * Justification architecturale : La date d'observation est une métadonnée d'origine (RAW) et doit être reconstituée dès le staging sans altération métier[cite: 1].
  * Implémentation SQL par fonctions de fenêtrage : détection des ruptures de cycle (`recorded_time_raw < LAG(recorded_time_raw) OVER (ORDER BY ctid)`) et incrémentation cumulative du décalage journalier (`SUM(...) OVER (ORDER BY ctid)`)[cite: 1].
  * Génération validée de la colonne `recorded_date_raw` du 01/10/2024 au 07/10/2024 (1 899 lignes pour Ichtegem, 1 908 lignes pour La Madeleine, `PASS=2`)[cite: 1].
* **Audit des types bruts :**[cite: 1]
  * Constat de la présence d'unités textuelles au sein des colonnes Weather Underground (`°F`, `mph`, `in`, `inHg`) et conservation temporaire en `TEXT`/`VARCHAR` pour préserver le principe de responsabilité unique (délégation du parsing à la couche intermediate)[cite: 1].

### Session 2 : Couche Intermediate dbt & Standardisation des flux
* **Création du dossier `models/intermediate/` :**[cite: 1]
  * Mise en place de la couche d'unification et de standardisation métier conformément aux règles dbt (matérialisation en `view` pour éviter la duplication de stockage et garantir un rafraîchissement dynamique)[cite: 1].
* **Modèle `int_wu_readings_standardized.sql` :**[cite: 1]
  * Fusion par `UNION ALL` des données des stations Ichtegem et La Madeleine[cite: 1].
  * Nettoyage regex (`regexp_replace`) pour éliminer les unités impériales (`°F`, `mph`, `inHg`, `in`)[cite: 1].
  * Formules de conversion appliquées : Fahrenheit vers Celsius, mph vers km/h, inHg vers hPa, pouces vers mm[cite: 1].
  * Horodatage unifié en `TIMESTAMP WITH TIME ZONE` (UTC)[cite: 1].
  * Validation du modèle : `PASS=1`, volumétrie totale vérifiée de **3 807 lignes** (1 899 pour Ichtegem, 1 908 pour La Madeleine)[cite: 1].
* **Modèle `int_infoclimat_standardized.sql` :**[cite: 1]
  * Transtypage des colonnes brutes en types numériques (`numeric`, `integer`)[cite: 1].
  * Standardisation du champ `recorded_at_utc` en format `TIMESTAMP WITH TIME ZONE`[cite: 1].
  * Validation du modèle : `PASS=1`, volumétrie vérifiée pour les 4 stations réelles pour un total de **1 143 relevés**[cite: 1].

### Session 3 : Couche Marts dbt, Optimisation des index, Tests d'intégrité & Documentation
* **Création du dossier `models/marts/` et modélisation en étoile :**[cite: 1]
  * **Table de dimension `dim_weather_stations.sql` :**[cite: 1]
    * Consolidation et déduplication des métadonnées des stations (InfoClimat et Weather Underground)[cite: 1].
    * Respect strict des sources sans extrapolation fictive (`station_id`, `station_name`, `source_network`)[cite: 1].
    * Matérialisation physique en `table` avec index unique sur `station_id`[cite: 1].
    * Résultat : 6 stations uniques enregistrées (`SELECT 6`)[cite: 1].
  * **Table de faits `fct_weather_readings.sql` :**[cite: 1]
    * Unification verticale par `UNION ALL` des couches intermédiaires standardisées[cite: 1].
    * Génération de la surrogate key `reading_id` par empreinte MD5 (`station_id` + `recorded_at_utc`)[cite: 1].
    * Conservation de 100 % des métriques sources sans perte (nébulosité en octats, visibilité, temps OMM, UV, rayonnement solaire) via projection explicite de valeurs `NULL` typées pour les champs exclusifs[cite: 1].
    * Matérialisation physique en `table` avec création automatisée de 4 index B-tree (`reading_id` UNIQUE, `station_id`, `recorded_at_utc`, et composite `(station_id, recorded_at_utc)`)[cite: 1].
    * Résultat : **4 950 relevés physiques** générés sans perte (`SELECT 4950`), dont 1 143 InfoClimat et 3 807 Weather Underground[cite: 1].
* **Optimisation et mesure des performances (PostgreSQL) :**[cite: 1]
  * Validation de la présence des index B-tree via l'inspection du catalogue (`\d public.fct_weather_readings`)[cite: 1].
  * Mesure des plans d'exécution via `EXPLAIN ANALYZE` sur un filtrage spatio-temporel typique du ML : utilisation confirmée de l'index (`Index Scan`) et temps d'exécution mesuré à **0.198 ms**[cite: 1].
* **Gouvernance, Qualité & Documentation (`schema.yml`) :**[cite: 1]
  * Formalisation de 10 tests de qualité de données sous dbt 1.12 (`unique`, `not_null`, et intégrité référentielle `relationships` entre la table de faits et la table de dimension)[cite: 1].
  * Validation complète des tests : **`PASS=10 WARN=0 ERROR=0`**[cite: 1].
  * Compilation du dictionnaire de métadonnées (`catalog.json` via `dbt docs generate`)[cite: 1].
  * Génération et validation visuelle du **Lineage Graph** de bout en bout (`raw` $\rightarrow$ `staging` $\rightarrow$ `intermediate` $\rightarrow$ `marts`) sur l'interface dbt docs (`dbt docs serve`)[cite: 1].

### Session 4 : Déploiement Cloud AWS RDS, Ingestion Airbyte & Validation Cloud
* **Provisionnement & Sécurisation de l'instance AWS RDS :**
  * Création d'une instance PostgreSQL 15 managée (`greenandcoop-db.clu0g26cg1mz.eu-west-3.rds.amazonaws.com`).
  * Configuration du Security Group autorisant les flux entrants sur le port 5432 pour l'ingestion Airbyte et le pilotage dbt.
* **Architecture dbt multi-environnements (`profiles.yml`) :**
  * Isolation stricte des cibles : `dev` (PostgreSQL local Docker) et `prod` (AWS RDS).
  * Sécurisation des accès de production via variables d'environnement (`DBT_PROD_DB_HOST`, `DBT_PROD_DB_PASSWORD`, etc.) sans exposition de secrets dans le code versionné.
  * Validation de la connectivité via `dbt debug --target prod`.
* **Ingestion Cloud automatisée avec Airbyte :**
  * Création de la destination Cloud `RDS PostgreSQL - GreenAndCoop` configurée sur le schéma `raw`.
  * Configuration et synchronisation des trois connexions sources en mode `Full refresh | Overwrite` :
    * `File - InfoClimat JSON` $\rightarrow$ `raw.infoclimat_raw`
    * `File - Weather Underground Ichtegem` $\rightarrow$ `raw.wu_ichtegem_raw`
    * `File - Weather Underground La Madeleine` $\rightarrow$ `raw.wu_la_madeleine_raw`
  * Validation de la réception des données brutes sur RDS via requêtes `psql`.
* **Transformation & Qualité en production Cloud :**
  * Nettoyage des modèles temporaires dbt (`models/example`) et purge du fichier `dbt_project.yml`.
  * Exécution complète du pipeline en production (`dbt run --target prod`) : matérialisation réussie des tables et vues sur AWS RDS (**`PASS=9`**, 4 950 lignes insérées dans `fct_weather_readings`).
  * Exécution de la suite de tests en production (`dbt test --target prod`) : validation totale de l'intégrité des données (**`PASS=10 WARN=0 ERROR=0`**).

---

## 🔍 Commandes d'audit et de vérification Cloud (AWS RDS)

```bash
# Vérification des tables brutes créées par Airbyte sur AWS RDS
docker run -it --rm postgres:15-alpine psql -h greenandcoop-db.clu0g26cg1mz.eu-west-3.rds.amazonaws.com -p 5432 -U postgres -d greenandcoop_db -c "\dt raw.*"

# Vérification du nombre d'enregistrements dans la table de faits Cloud
docker run -it --rm postgres:15-alpine psql -h greenandcoop-db.clu0g26cg1mz.eu-west-3.rds.amazonaws.com -p 5432 -U postgres -d greenandcoop_db -c "SELECT count(*) FROM public.fct_weather_readings;"

# Exécution des tests dbt en environnement de production Cloud
dbt test --target prod
```