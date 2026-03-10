---
description: Rassemble toutes les infos (agenda, transcripts, Notion, Slack, Gmail) depuis une date et produit un résumé
allowed-tools: Bash, Read, Write, Glob, Grep, mcp__claude_ai_Google_Calendar__gcal_list_events, mcp__claude_ai_Google_Calendar__gcal_get_event, mcp__claude_ai_Gmail__gmail_search_messages, mcp__claude_ai_Gmail__gmail_read_message, mcp__claude_ai_Gmail__gmail_read_thread, mcp__claude_ai_Slack__slack_search_public_and_private, mcp__claude_ai_Slack__slack_read_channel, mcp__claude_ai_Slack__slack_read_thread, mcp__claude_ai_Notion__notion-search, mcp__claude_ai_Notion__notion-fetch, Agent
---

L'utilisateur veut un résumé de tout ce qui s'est passé depuis une date donnée. L'argument fourni est : $ARGUMENTS

La date fournie doit être interprétée comme la date de début. La date de fin est aujourd'hui. Si l'argument est vide ou absent, utiliser aujourd'hui comme date de début (gather sur la journée en cours). Si l'argument est relatif (ex: "lundi", "la semaine dernière", "3 jours"), convertis-le en date absolue.

Suis ces étapes dans l'ordre. IMPORTANT : collecte un maximum de données AVANT de rédiger le résumé final. Utilise des agents en parallèle quand c'est possible pour aller plus vite.

PRIORITÉ DES SOURCES (de la plus riche à la moins riche) :
1. TRANSCRIPTS & NOTES GEMINI — c'est LA source la plus importante. Ils contiennent le verbatim des discussions, les décisions, les désaccords, les actions. Toujours les télécharger et les lire en entier.
2. Slack canaux TIER 1 (comex, management, core-tech)
3. Emails internes écrits à la main
4. Notion
5. Slack autres canaux
6. Emails automatiques / notifications

## Étape 1 — Google Calendar + Transcripts Gemini

Utilise `mcp__claude_ai_Google_Calendar__gcal_list_events` avec :
- timeMin = date de début à 00:00:00
- timeMax = maintenant
- timeZone = Europe/Paris
- condenseEventDetails = false (pour avoir les attachments et la description)
- maxResults = 250

Pagine si nécessaire (nextPageToken).

Pour chaque événement de type meeting (pas les all-day, pas les working locations) :
1. Regarde les `attachments` (si hasAttachments: true). Les notes Gemini sont des Google Docs attachés au meeting.
2. Regarde la `description` de l'événement pour des liens Google Docs/Drive (regex: https://(docs|drive).google.com/[^\s"<]+)
3. Pour chaque lien trouvé (attachments ou description), note-le pour téléchargement.

SI aucun attachment ou lien n'est trouvé dans les events, utilise le script gdrive-dl pour chercher les transcripts/notes Gemini sur Drive :
```bash
~/.local/bin/gdrive-dl search "Notes par Gemini" --after=YYYY-MM-DD --max=20
```
et aussi :
```bash
~/.local/bin/gdrive-dl search "Transcript" --after=YYYY-MM-DD --max=20
```
Cela retourne du JSON avec les fichiers trouvés (id, name, webViewLink). Corrèle les résultats avec les noms des meetings du calendrier.

## Étape 2 — Télécharger et lire les transcripts/notes (ÉTAPE LA PLUS IMPORTANTE)

Les transcripts et notes Gemini sont la source d'information la plus riche et la plus fiable. Ils contiennent le verbatim des discussions, les décisions prises, les désaccords, les actions assignées. NE JAMAIS SAUTER CETTE ÉTAPE.

Crée d'abord le dossier : `mkdir -p /tmp/gather`

Pour chaque fichier trouvé (attachments, liens dans descriptions, ou résultats de recherche Drive) :
```bash
~/.local/bin/gdrive-dl "<url_ou_id>" -o "/tmp/gather/<nom_sanitizé>.pdf"
```

Ensuite lis CHAQUE PDF téléchargé avec l'outil Read. Les PDFs peuvent être longs :
- D'abord lire les pages 1-20
- Si le PDF a plus de 20 pages, lire les pages suivantes aussi (21-36, etc.)
- Ne PAS se contenter des premières pages, les décisions et actions sont souvent à la fin des réunions

Pour chaque transcript, extraire :
- Les sujets abordés
- Les décisions prises (qui a tranché, quoi, pourquoi)
- Les désaccords ou points de tension
- Les actions assignées (qui doit faire quoi, pour quand)
- Les questions restées ouvertes

## Étape 3 — Notion (1:1 et pages récentes)

### 3a — Pages 1:1

Cherche les pages 1:1 avec `mcp__claude_ai_Notion__notion-search` :
- query = "1/1"
- Récupère toutes les pages 1:1 (Xavier, Renaud, Etienne, David, François H.)

Pour chaque page 1:1 trouvée, utilise `mcp__claude_ai_Notion__notion-fetch` pour lire son contenu. Regarde la dernière entrée datée (la plus récente) de chaque 1:1. Extraire les éléments importants :
- Priorités et succès de la semaine
- Blocages et difficultés
- Sujets RH (départs, recrutement, performance)
- Décisions ou questions ouvertes

Intègre ces éléments directement dans le résumé final (sections CE QUI S'EST PASSÉ et DÉCISIONS EN ATTENTE), NE PAS les lister séparément.

### 3b — Autres pages Notion

Utilise `mcp__claude_ai_Notion__notion-search` pour chercher les pages modifiées récemment :
- Fais une recherche avec un filtre `created_date_range` avec start_date = date de début
- Cherche avec des termes génériques liés au travail de l'utilisateur

Utilise `mcp__claude_ai_Notion__notion-fetch` sur les pages les plus pertinentes pour lire leur contenu.

## Étape 4 — Slack

Fais plusieurs recherches avec `mcp__claude_ai_Slack__slack_search_public_and_private` :
- `from:<@U3KR4PTDX> after:YYYY-MM-DD` — messages envoyés par l'utilisateur
- `to:<@U3KR4PTDX> after:YYYY-MM-DD` — messages adressés à l'utilisateur
- `after:YYYY-MM-DD` dans des canaux importants si connus

Paramètres : `sort="timestamp"`, `sort_dir="desc"`, `include_context=false`, `response_format="concise"`

### Hiérarchie des canaux Slack

TIER 1 — Direction & stratégie (TOUJOURS lire les threads) :
- #comex (C02RKJG8P0Q)
- #comex-et-legal (C04BC17BF62)
- #management_group (GPW8XBBUZ)
- #product-management (G04CQC4JXNE)
- #tech-management (C03337XES3Z)
- #core-tech (C031Y86H4TV)
- DMs et group DMs (canaux de type im/mpim)

TIER 2 — Équipe produit & tech (lire si mention ou sujet important) :
- #team-produit-tech (CN08K8G01)
- #team-pretto-produit-tech (C04HGTGJC6Q)
- #team-pretto-tech (C049GCM1KPS)
- #produit (C3LRZQ6Q5)
- #info-managers (C0893RLAS3D)
- #management-transition-iad (C0ADYSWUC5B)
- #salesops-tech-product (C02EFFM0N9W)
- #recrutement-tech (C02T36Q7R2N)

TIER 3 — Squads & projets (noter si pertinent) :
- #team-apollo-tech (C03EYTQ4XSM)
- #team-finspot-produit-tech (C043M2L0V99)
- #squad-eclipse-tech (C0AHRTNP29M)
- #squad-board-produit-tech (C0A40T1B881)
- #stream-arthur-tech (C0A7QR4GW1Y)
- #galaxie-tech-ops (C036PS524Q1)
- #general (C3LHVQACU)
- #tech-sharing (CCTM61J1G)

TIER 4 — Alertes & bots (ignorer sauf incident non résolu) :
- #alerts-* (tous les canaux d'alertes)
- Messages de bots — `include_bots=false` par défaut

### Triage et pondération des messages

PRIORITÉ HAUTE (lire le thread complet avec slack_read_thread) :
- Tout message dans un canal TIER 1
- DMs et group DMs
- Messages où l'utilisateur est mentionné (@François)
- Messages écrits par l'utilisateur lui-même

PRIORITÉ MOYENNE (noter dans le résumé) :
- Messages dans des canaux TIER 2
- Annonces dans #general
- Messages avec des liens partagés (docs, PRs, designs)

PRIORITÉ BASSE (ignorer sauf contenu notable) :
- Messages dans des canaux TIER 3-4
- Messages de bots, notifications automatiques

Quand il y a beaucoup de messages dans un même thread, résumer le thread plutôt que lister chaque message. Identifier qui a dit quoi sur les points importants.

Pour les recherches, faire en priorité :
1. `in:comex after:YYYY-MM-DD`
2. `in:management_group after:YYYY-MM-DD`
3. `in:tech-management after:YYYY-MM-DD`
4. `in:core-tech after:YYYY-MM-DD`
5. `in:product-management after:YYYY-MM-DD`
6. `from:<@U3KR4PTDX> after:YYYY-MM-DD` (messages envoyés par l'utilisateur)
7. `to:<@U3KR4PTDX> after:YYYY-MM-DD` (messages adressés à l'utilisateur)

Si un thread semble contenir une décision ou une action, utilise `mcp__claude_ai_Slack__slack_read_thread` pour lire le détail.

## Étape 5 — Gmail

Utilise `mcp__claude_ai_Gmail__gmail_search_messages` avec :
- q = "after:YYYY/MM/DD" (format Gmail : YYYY/M/D)
- maxResults = 100

### Triage et pondération des emails

Classe chaque email selon cette grille de priorité :

PRIORITÉ HAUTE (lire le contenu avec gmail_read_message) :
- Emails internes écrits à la main : From @pretto.fr, To @pretto.fr, PAS un no-reply/via/automated
- Emails de personnes externes adressés directement à l'utilisateur (pas à une mailing list)

PRIORITÉ MOYENNE (noter sujet + expéditeur dans le résumé) :
- Emails internes automatiques mais actionnables (demandes d'accès, approbations)
- Réponses de clients ou partenaires

PRIORITÉ BASSE (ignorer sauf volume anormal) :
- Notifications de services (New Relic, Sentry, Zapier, Salesforce, AWS, Datadog...)
- Newsletters, marketing, invitations événements
- Notifications GitHub/GitLab (PR merged, CI failed...)
- Emails via mailing lists tech@, salesforce@, aws@

Pour détecter les notifications automatiques, regarde ces signaux :
- From contient "via", "noreply", "no-reply", "notifications", "alert", "support@"
- From est un domaine de service connu (zapier, newrelic, sentry, salesforce, github, aws, datadog, retool, airtable, notion, apple, google)
- Subject contient [ALERT], "exception", "error", "script exception", "your job", "daily report"
- Subject commence par "Invitation:", "Updated invitation:", "Invitation mise à jour:", "Accepted:", "Accepté:", "Declined:", "Refusé:", "Accepté provisoirement:", "Tentatively accepted:" — ce sont des emails de calendrier Google, les IGNORER complètement (l'info est déjà dans le calendrier)
- To est une adresse de groupe/alias (tech@, aws@, salesforce@, privacy@)
- labelIds contient CATEGORY_FORUMS ou CATEGORY_PROMOTIONS (= pas CATEGORY_PERSONAL)

Quand il y a beaucoup de notifications du même type (ex: 10 Salesforce exceptions), les regrouper en une seule ligne : "Salesforce: 10 exceptions Apex (Ringover, ContactTrigger...)" plutôt que lister chacune.

## Étape 6 — Résumé

Une fois TOUTES les données collectées, rédige un résumé structuré en texte simple (pas de markdown riche).

RÈGLES DE FORMAT :
- Ne PAS inclure les sections qui n'ont rien d'important à signaler. Si une section serait vide ou triviale, l'omettre.
- Grouper les décisions au maximum plutôt que lister individuellement. Prioriser les décisions au niveau entreprise.
- Les informations des 1:1 Notion doivent être intégrées dans les sections existantes (CE QUI S'EST PASSÉ, DÉCISIONS EN ATTENTE), pas listées séparément.
- Ne PAS lister les réunions du calendrier. Le calendrier sert uniquement à trouver les transcripts/notes Gemini. Dans le résumé, ne mentionner que le contenu extrait des transcripts et notes, pas la liste des meetings de la journée.

Sections possibles (n'inclure que celles qui ont du contenu pertinent) :

```
RÉSUMÉ — du [date début] au [date fin]
=========================================

CE QUI S'EST PASSÉ
------------------
- [bullet points des événements, discussions Slack, changements Notion, points importants des 1:1]

DÉCISIONS PRISES
----------------
- [grouper les décisions par thème, prioriser les décisions entreprise]

DÉCISIONS EN ATTENTE
--------------------
- [sujets ouverts, questions non résolues, actions à suivre, blocages remontés dans les 1:1]

EMAILS IMPORTANTS (internes / écrits à la main)
------------------------------------------------
- [emails haute priorité avec expéditeur, sujet et résumé du contenu]

NOTIFICATIONS & ALERTES (résumé groupé)
----------------------------------------
- [regrouper par source, ne mentionner que si volume anormal ou incident non résolu]
```

Sois concis mais complet. Privilégie les informations actionnables.
