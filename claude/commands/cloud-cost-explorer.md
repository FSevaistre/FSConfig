---
description: Rapport de couts cloud (AWS + GCP) — vue CTO sur les depenses, tendances et anomalies
allowed-tools: Bash, Read, Write
---

Rapport de couts cloud pour le CTO. L'argument fourni est : $ARGUMENTS

## Parsing de l'argument

- **Vide** : rapport standard (mois en cours + comparaison 3 mois + prevision + top services + cout journalier) sur AWS + GCP
- **"aws"** : rapport AWS uniquement
- **"gcp"** : rapport GCP uniquement
- **"detail <service>"** : zoom sur un service specifique (ex: "detail RDS", "detail Vertex AI")
- **"compare"** : comparaison detaillee mois sur mois par service (qui monte, qui descend)
- **"all"** : rapport sur tous les comptes AWS (pretto-admin, pretto-prod, pretto-staging, pretto-shared) + GCP
- **"account <profil>"** : rapport sur un compte AWS specifique (ex: "account pretto-prod")

---

# PARTIE AWS

## Etape 0 — Profil et date

Determine le profil AWS a utiliser :
- Par defaut : `pretto-admin`
- Si l'argument contient "account <profil>" : utiliser ce profil
- Si l'argument contient "all" : iterer sur tous les profils

Recupere la date du jour :
```bash
date +"%Y-%m-%d"
```

Calcule :
- MONTH_START : premier jour du mois en cours (YYYY-MM-01)
- MONTH_END : date du jour (YYYY-MM-DD)
- PREV_MONTH_START : premier jour du mois precedent
- THREE_MONTHS_AGO : premier jour il y a 3 mois

Verifie que les credentials fonctionnent :
```bash
aws --profile <profil> sts get-caller-identity
```
Si ca echoue, dire a l'utilisateur de lancer `! aws sso login --profile <profil>`.

## Etape 1 — Vue d'ensemble du mois

```bash
aws --profile <profil> ce get-cost-and-usage \
  --time-period Start=MONTH_START,End=MONTH_END \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json
```

Extraire :
- Total du mois
- Top 10 services par cout
- Pourcentage de chaque service

## Etape 2 — Comparaison 3 mois

```bash
aws --profile <profil> ce get-cost-and-usage \
  --time-period Start=THREE_MONTHS_AGO,End=MONTH_END \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --output json
```

Calculer l'evolution mois sur mois (M vs M-1, M-1 vs M-2).

## Etape 3 — Prevision fin de mois

```bash
aws --profile <profil> ce get-cost-forecast \
  --time-period Start=MONTH_END,End=PREMIER_JOUR_MOIS_SUIVANT \
  --granularity MONTHLY \
  --metric BLENDED_COST \
  --output json
```

## Etape 4 — Cout journalier (7 derniers jours)

```bash
aws --profile <profil> ce get-cost-and-usage \
  --time-period Start=DATE_7J_AVANT,End=MONTH_END \
  --granularity DAILY \
  --metrics BlendedCost \
  --output json
```

Detecter les anomalies : un jour > 1.5x la moyenne des 6 autres jours = alerte.

## Etape 5 — Detection d'anomalies par service (si argument "compare")

```bash
aws --profile <profil> ce get-cost-and-usage \
  --time-period Start=PREV_MONTH_START,End=MONTH_END \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json
```

Pour chaque service, comparer le cout M vs M-1. Signaler :
- Hausse > 20% = attention
- Hausse > 50% = alerte
- Nouveau service (pas present le mois precedent) = nouveau

## Etape 6 — Detail par service (si argument "detail <service>")

```bash
aws --profile <profil> ce get-cost-and-usage \
  --time-period Start=THREE_MONTHS_AGO,End=MONTH_END \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["<service>"]}}'  \
  --output json
```

Afficher la courbe journaliere sur 3 mois pour ce service.

---

# PARTIE GCP

## Configuration GCP

- Projet principal : `pretto-apis`
- Region BigQuery : `region-eu`
- Billing account ID : `01D562-9EB5A4-2E44CC`
- Devise : EUR (taux de change applique par Google)

## Etape G0 — Verifier l'acces

```bash
gcloud auth print-identity-token --quiet 2>/dev/null || echo "NOT_LOGGED_IN"
```
Si ca echoue, dire a l'utilisateur de lancer `! gcloud auth login`.

## Etape G1 — Couts GCP par service via billing export

L'export billing est configure dans `pretto-apis.billing_export`. La table s'appelle `gcp_billing_export_v1_01D562_9EB5A4_2E44CC`.

```bash
bq query --use_legacy_sql=false --project_id=pretto-apis --format=csv --max_rows=500 "
SELECT
  service.description AS service,
  FORMAT_TIMESTAMP('%Y-%m', usage_start_time) AS month,
  ROUND(SUM(cost), 2) AS cost_eur,
  ROUND(SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)), 2) AS credits_eur,
  ROUND(SUM(cost) + SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)), 2) AS net_cost_eur
FROM \`pretto-apis.billing_export.gcp_billing_export_v1_01D562_9EB5A4_2E44CC\`
WHERE usage_start_time >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH))
GROUP BY 1, 2
ORDER BY 2 DESC, 5 DESC
"
```

Si la table n'existe pas encore (export recent, donnees pas encore arrivees), utiliser le fallback INFORMATION_SCHEMA ci-dessous.

## Etape G3 — Fallback : couts BigQuery via INFORMATION_SCHEMA

Si pas d'export billing, recuperer au moins les couts BigQuery (le plus gros poste) :
```bash
bq query --use_legacy_sql=false --project_id=pretto-apis --format=csv --max_rows=200 "
SELECT
  FORMAT_TIMESTAMP('%Y-%m', creation_time) AS month,
  CASE
    WHEN user_email LIKE '%appspot%' THEN 'App Engine'
    WHEN user_email LIKE '%airflow%' OR user_email LIKE '%composer%' THEN 'Cloud Composer'
    WHEN user_email LIKE '%dbt%' THEN 'dbt'
    WHEN user_email LIKE '%metabase%' THEN 'Metabase'
    WHEN user_email LIKE '%dataplatform%' THEN 'Data Platform'
    WHEN user_email LIKE '%@pretto.fr' THEN 'Users'
    ELSE REGEXP_EXTRACT(user_email, r'^([^@]+)')
  END AS service,
  COUNT(*) AS job_count,
  ROUND(SUM(total_bytes_billed) / POWER(1024, 4), 2) AS tb_billed,
  ROUND(SUM(total_bytes_billed) / POWER(1024, 4) * 6.25, 2) AS estimated_cost_usd
FROM \`region-eu\`.INFORMATION_SCHEMA.JOBS
WHERE creation_time >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH))
  AND job_type = 'QUERY'
  AND state = 'DONE'
  AND error_result IS NULL
GROUP BY 1, 2
ORDER BY 1 DESC, 5 DESC
"
```

Note : ces couts sont estimes sur la base du tarif on-demand (6.25$/TB). Si le compte est en flat-rate (BigQuery Reservation), le cout reel est le forfait de reservation (~3000 EUR/mois).

## Etape G4 — Couts GCP reels via Tableau des couts (reference)

Pour les couts GCP reels par service (incluant Vertex AI, Cloud Composer, Storage, etc.), les donnees de reference sont dans la console GCP :
- URL : https://console.cloud.google.com/billing/01D562-9EB5A4-2E44CC/reports/tabular

Top services GCP connus (derniere mise a jour mars 2026) :
- BigQuery Reservation API : ~3000 EUR/mois (flat-rate)
- Cloud Composer : ~1800 EUR/mois
- Vertex AI : ~1400 EUR/mois (en forte hausse +102%)
- Cloud Storage : ~740 EUR/mois
- Artifact Registry : ~370 EUR/mois (en forte hausse +178%)
- Cloud Dataflow : ~340 EUR/mois
- Total GCP : ~9500-11000 EUR/mois

---

# FORMAT DU RAPPORT COMBINE

```
CLOUD COST EXPLORER — [date]
==========================================

AWS — Compte : [profil] ([account_id])
------------------------------------------

RESUME
  Mois en cours : $X,XXX (au JJ/MM)
  Prevision fin de mois : $X,XXX
  Run rate journalier : $XXX/jour

TENDANCE (3 mois)
  M-2 : $X,XXX
  M-1 : $X,XXX [+/-XX%]
  M   : $X,XXX [+/-XX%] (prevision)

TOP SERVICES AWS
  $X,XXX (XX%)  ##########  Service 1
  $X,XXX (XX%)  #######     Service 2
  $X,XXX (XX%)  #####       Service 3
  ...

COUT JOURNALIER AWS (7j)
  YYYY-MM-DD : $XXX  ################
  YYYY-MM-DD : $XXX  ###############
  ...


GCP — Projet : pretto-apis
------------------------------------------

RESUME
  Mois en cours : X,XXX EUR (au JJ/MM)
  Prevision fin de mois : X,XXX EUR

TENDANCE (3 mois)
  M-2 : X,XXX EUR
  M-1 : X,XXX EUR [+/-XX%]
  M   : X,XXX EUR [+/-XX%] (prevision)

TOP SERVICES GCP
  X,XXX EUR (XX%)  ##########  Service 1
  X,XXX EUR (XX%)  #######     Service 2
  X,XXX EUR (XX%)  #####       Service 3
  ...


VISION GLOBALE
==========================================
  AWS total mois : $X,XXX (~X,XXX EUR)
  GCP total mois : X,XXX EUR
  TOTAL CLOUD    : X,XXX EUR
  Evolution M/M-1 : +/-XX%

ANOMALIES
  [!] Service X : +XX% vs mois dernier ($XXX -> $XXX)
  [!] Jour YYYY-MM-DD : $XXX (1.8x la moyenne)
  [new] Service Y : $XXX (pas present le mois dernier)
```

---

# REGLES

- AWS : toujours utiliser BlendedCost (pas UnblendedCost)
- Arrondir a 2 decimales pour les petits montants, a l'entier pour > 100
- Les barres ASCII sont proportionnelles au cout le plus eleve
- Filtrer les services < 1$ / 1 EUR dans le top services (bruit)
- Ne pas inclure les taxes dans les comparaisons de services
- Pour la vision globale, convertir AWS USD en EUR avec le taux 0.84 (approximation) sauf si un taux plus recent est disponible
- Si le mois precedent a un cout anormalement eleve (> 2x les autres mois), le signaler comme "probablement un achat reserve ou Savings Plan"
- Pour GCP, privilegier les donnees du billing export si disponible, sinon utiliser INFORMATION_SCHEMA + les couts de reference connus
- Lancer les requetes AWS et GCP en parallele quand possible
