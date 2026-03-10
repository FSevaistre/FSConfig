---
description: Collecte 20 transcripts d'appels Salesforce au hasard et les met dans Notion
allowed-tools: Bash, Read, Write, Glob, Grep, mcp__claude_ai_Notion__notion-fetch, mcp__claude_ai_Notion__notion-create-pages, mcp__claude_ai_Notion__notion-update-page
---

Tu es un assistant qui collecte des transcripts d'appels depuis Salesforce et les stocke dans Notion.

## Configuration

- Page Notion parent : `32cd2e40-ea50-80fd-90dd-f1b6188f4302` (Transcripts)
- Bucket GCS : `gs://pretto-transcription-ringover/`
- Org Salesforce : `pretto-sf`
- Champ transcript SF : `transcription_path__c` (attention : revient en lowercase depuis l'API)

## Workflow

### 1. Requêter Salesforce pour 20 appels avec transcripts

D'abord, calculer la date d'il y a 7 jours au format SOQL (YYYY-MM-DDT00:00:00Z) :
```python
from datetime import datetime, timedelta
seven_days_ago = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%dT00:00:00Z')
```

Puis requêter :
```bash
sfdx data:query -o pretto-sf --query "SELECT Id, Subject, Description, Transcription_Path__c, CreatedDate FROM Task WHERE Subject LIKE '%Appel%' AND Transcription_Path__c LIKE '%transcripts%' AND CreatedDate > <seven_days_ago> ORDER BY CreatedDate DESC LIMIT 500" --json 2>/dev/null
```

Filtrer les résultats en Python :
- Garder uniquement les appels avec Description > 200 chars (= résumé substantiel)
- Garder uniquement les appels > 5 min (extraire la durée du Subject avec regex `\((\d+):(\d+):(\d+)\)`)
- Dédupliquer par Subject (prendre la première occurrence)
- Prendre 20 au hasard parmi les candidats (`random.sample`)
- Stocker dans `/tmp/collect_transcripts.json`

### 2. Télécharger les transcripts complets depuis GCS

Pour chaque appel, télécharger le transcript :
```bash
gsutil cat "gs://pretto-transcription-ringover/<transcription_path__c>" > /tmp/transcript_<i>.txt
```

Vérifier que chaque fichier est non-vide.

### 3. Créer la page parent du jour dans Notion

Créer une page enfant sous `32cd2e40-ea50-80fd-90dd-f1b6188f4302` avec :
- Titre : `Collecte du <date du jour> — 20 appels`
- Icône : 📞
- Contenu : intro + pour chaque appel, un `### N. <Subject>` avec le résumé (Description nettoyée du préfixe "Appel de...\nDurée:...")

### 4. Créer les sous-pages avec les transcripts complets

Pour chaque appel, créer une sous-page sous la page du jour avec :
- Titre : `N. <Expert> → <Client> (<date>)`
- Icône : 📞
- Contenu :
  ```
  ### Résumé
  <description nettoyée>

  ---

  ### Transcript complet
  ```
  <transcript verbatim depuis GCS>
  ```
  ```

IMPORTANT : les transcripts sont gros (5-40k chars chacun). Créer les sous-pages par batch de taille < 45k chars pour ne pas dépasser les limites de l'API Notion. Faire les batches séquentiellement.

Le champ `transcription_path__c` revient en LOWERCASE depuis l'API sfdx. Toujours chercher avec `.get('transcription_path__c', '') or .get('Transcription_Path__c', '')`.

### 5. Mettre à jour la page parent avec les liens

Une fois toutes les sous-pages créées, mettre à jour la page parent du jour pour ajouter sous chaque résumé un lien `→ Transcript complet` pointant vers la sous-page correspondante (format Notion : `<page url="https://www.notion.so/<page_id>">Transcript complet</page>`).

### 6. Bilan

Afficher :
- Nombre d'appels collectés
- Nombre de transcripts téléchargés
- Lien vers la page Notion
