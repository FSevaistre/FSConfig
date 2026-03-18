---
description: Rassemble toutes les infos (agenda, transcripts, Notion, Slack, Gmail, GitHub, Board) depuis une date et produit un résumé stratégique
allowed-tools: Bash, Read, Write, Glob, Grep, mcp__claude_ai_Google_Calendar__gcal_list_events, mcp__claude_ai_Google_Calendar__gcal_get_event, mcp__claude_ai_Gmail__gmail_search_messages, mcp__claude_ai_Gmail__gmail_read_message, mcp__claude_ai_Gmail__gmail_read_thread, mcp__claude_ai_Slack__slack_search_public_and_private, mcp__claude_ai_Slack__slack_read_channel, mcp__claude_ai_Slack__slack_read_thread, mcp__claude_ai_Notion__notion-search, mcp__claude_ai_Notion__notion-fetch, mcp__claude_ai_Notion__notion-update-page, mcp__claude_ai_Notion__notion-create-pages, Agent
---

L'utilisateur est CTO. Ce gather doit produire une vision stratégique, pas un dump chronologique. L'argument fourni est : $ARGUMENTS

L'argument peut contenir une date et optionnellement une heure, séparées par un espace ou tout autre format naturel. Exemples : "2026-03-14", "vendredi 14h", "lundi 10:30", "la semaine dernière", "3 jours", "aujourd'hui 15h".

La date (et heure si fournie) est interprétée comme le début de la période. La fin est maintenant. Si l'argument est vide ou absent, utiliser aujourd'hui à 00:00:00 comme début (gather sur la journée en cours). Si l'argument est relatif (ex: "lundi", "la semaine dernière", "3 jours"), convertis-le en date/heure absolue. Si une heure est fournie sans date, utiliser aujourd'hui à cette heure. Si aucune heure n'est fournie, utiliser 00:00:00.

### Reprise automatique depuis le dernier gather

Si l'argument est vide, AVANT de commencer la collecte, récupère la page Notion "Gathered" (ID : `325d2e40-ea50-8194-8e49-e4f2926780ec`) avec `mcp__claude_ai_Notion__notion-fetch`. Regarde la première entrée (la plus récente, en haut de page) et extrais la date/heure du dernier gather. Utilise cette date/heure comme date de début au lieu de minuit aujourd'hui. Cela permet d'enchaîner les gathers sans trous ni doublons.

En même temps, lis la section "OUVERT" du dernier gather (les décisions en attente, actions à suivre). Tu dois les tracker dans ce gather : pour chaque item ouvert, vérifier s'il a avancé et le reporter dans le résumé.

Si l'argument est explicitement fourni, l'utiliser tel quel (pas de reprise automatique).

### Heure locale

AVANT de commencer, exécute `date +"%Y-%m-%d %H:%M %Z"` pour connaître l'heure locale exacte. Utilise TOUJOURS cette heure pour les timestamps dans le résumé et la page Notion. Ne JAMAIS deviner l'heure ou utiliser UTC — l'utilisateur est en Europe/Paris.

### Profondeur adaptative

Calcule la durée de la fenêtre (timeMax - timeMin) et adapte la profondeur :

- **< 3 heures** : Slack (from/to moi + TIER 1 seulement), Gmail (scan rapide), Calendar. PAS de Notion 1:1 ni Board ni GitHub. Format résumé court.
- **3-8 heures (demi-journée)** : Tout sauf Notion 1:1. GitHub PRs sur master. Board si pertinent.
- **> 8 heures (journée+)** : Collecte complète. Notion 1:1, Board, GitHub, transcripts Gemini, tout.

### Ordre d'exécution

Suis ces étapes dans l'ordre. IMPORTANT : collecte un maximum de données AVANT de rédiger le résumé final. Utilise des agents en parallèle quand c'est possible pour aller plus vite. NE PAS OUBLIER l'étape 8 (écriture Notion + sous-pages sources) après avoir affiché le résumé.

PRIORITÉ DES SOURCES (de la plus riche à la moins riche) :
1. TRANSCRIPTS & NOTES GEMINI — c'est LA source la plus importante. Ils contiennent le verbatim des discussions, les décisions, les désaccords, les actions. Toujours les télécharger et les lire en entier.
2. Slack canaux TIER 1 (comex, management, core-tech)
3. Emails internes écrits à la main
4. Notion
5. GitHub PRs sur master
6. Board Produit-Tech
7. Slack autres canaux
8. Emails automatiques / notifications

## Étape 1 — Google Calendar + Transcripts Gemini

Utilise `mcp__claude_ai_Google_Calendar__gcal_list_events` avec :
- timeMin = date de début à l'heure fournie (ou 00:00:00 si aucune heure spécifiée)
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

## Étape 3 — Notion (1:1 et pages récentes) — SKIP si fenêtre < 3h

### 3a — Pages 1:1

Lis le fichier `~/.claude/team.json` pour obtenir les `notion_1to1_page` de chaque managee.

Pour chaque page 1:1, utilise `mcp__claude_ai_Notion__notion-fetch` pour lire son contenu. Regarde la dernière entrée datée (la plus récente). Extraire :
- Priorités et succès de la semaine
- Blocages et difficultés
- Sujets RH (départs, recrutement, performance)
- Décisions ou questions ouvertes

### 3a bis — Pages "Generated by Claude" sous chaque 1:1

Chaque page 1:1 contient une sous-page "Generated by Claude" qui stocke les briefings générés par /1to1. Ces briefings contiennent des données déjà agrégées (Slack, GitHub, Board, emails) sur le managee et son équipe.

Pour chaque page 1:1 :
1. Cherche la sous-page "Generated by Claude" dans le contenu (balise `<page>`)
2. Utilise `mcp__claude_ai_Notion__notion-fetch` pour la lire
3. Si elle contient des briefings datés, lis le plus récent qui tombe dans la période du gather
4. Extrais les informations pertinentes

Intègre ces éléments dans le résumé final par projet/initiative, PAS comme une liste séparée.

### 3b — Autres pages Notion

Utilise `mcp__claude_ai_Notion__notion-search` avec un filtre `created_date_range` (start_date = date de début). Lis les pages les plus pertinentes.

## Étape 4 — Slack

### Recherches

Fais les recherches suivantes en parallèle avec `mcp__claude_ai_Slack__slack_search_public_and_private` :

Paramètres communs : `sort="timestamp"`, `sort_dir="desc"`, `include_context=false`, `response_format="concise"`

IMPORTANT — Filtres de date Slack :
- Pour un gather sur une seule journée : utiliser `on:YYYY-MM-DD`
- Pour un gather sur plusieurs jours : utiliser `after:YYYY-MM-DD` avec la veille du jour de début (le filtre `after:` est exclusif dans Slack, il faut soustraire 1 jour). Ex: pour commencer le 14 mars, utiliser `after:2026-03-13`.
- NE JAMAIS utiliser `after:YYYY-MM-DD` avec la date du jour elle-même, ça exclut le jour courant.

Ordre de priorité des recherches :
1. `in:comex <date>`
2. `in:management_group <date>`
3. `in:tech-management <date>`
4. `in:core-tech <date>`
5. `in:product-management <date>`
6. `from:<@U3KR4PTDX> <date>` (messages envoyés par moi)
7. `to:<@U3KR4PTDX> <date>` (messages adressés à moi)

Si fenêtre > 3h, ajouter :
8. `in:team-produit-tech <date>`
9. `in:team-pretto-produit-tech <date>`
10. Canaux TIER 2-3 si pertinent

### Hiérarchie des canaux

TIER 1 — Direction & stratégie (résumer chaque message/thread en détail, citer qui a dit quoi) :
- #comex (C02RKJG8P0Q)
- #comex-et-legal (C04BC17BF62)
- #management_group (GPW8XBBUZ)
- #product-management (G04CQC4JXNE)
- #tech-management (C03337XES3Z)
- #core-tech (C031Y86H4TV)
- DMs et group DMs (canaux de type im/mpim)

EXCLUSIONS DMs — Ignorer complètement :
- Group DM avec Philippe Mineur et Olivier (Olivier Carreau)
- Tout DM ou group DM impliquant uniquement Philippe Mineur et/ou Olivier Carreau sans autre participant professionnel

TIER 2 — Équipe produit & tech (résumer les sujets importants, regrouper le reste) :
- #team-produit-tech (CN08K8G01)
- #team-pretto-produit-tech (C04HGTGJC6Q)
- #team-pretto-tech (C049GCM1KPS)
- #produit (C3LRZQ6Q5)
- #info-managers (C0893RLAS3D)
- #management-transition-iad (C0ADYSWUC5B)
- #salesops-tech-product (C02EFFM0N9W)
- #recrutement-tech (C02T36Q7R2N)

TIER 3 — Squads & projets (résumer en 1 ligne par sujet notable, omettre le bruit) :
- #team-apollo-tech (C03EYTQ4XSM)
- #team-finspot-produit-tech (C043M2L0V99)
- #squad-eclipse-tech (C0AHRTNP29M)
- #squad-board-produit-tech (C0A40T1B881)
- #stream-arthur-tech (C0A7QR4GW1Y)
- #galaxie-tech-ops (C036PS524Q1)
- #general (C3LHVQACU)
- #tech-sharing (CCTM61J1G)

TIER 4 — Alertes & bots (mentionner uniquement les incidents non résolus ou les volumes anormaux) :
- #alerts-* (tous les canaux d'alertes)
- Messages de bots — `include_bots=false` par défaut

### Lecture des threads

TOUJOURS lire les threads complets (slack_read_thread) pour :
- Tout message dans un canal TIER 1
- DMs et group DMs (hors exclusions)
- Messages où l'utilisateur est mentionné (@François)
- Messages écrits par l'utilisateur lui-même
- Tout thread avec 3+ réponses quel que soit le canal

Pour les canaux TIER 2-3, lire aussi les threads si le sujet semble important (décision, blocage, lien partagé, annonce).

## Étape 4bis — Radar Business (signaux hors périmètre direct) — SKIP si fenêtre < 3h

L'objectif est de capter les signaux business importants dans les canaux où le CTO n'est pas actif au quotidien. L'approche : des recherches par mots-clés sur TOUS les canaux publics (pas seulement les TIER 1-4).

### Recherches par signal

Faire ces recherches en parallèle avec `mcp__claude_ai_Slack__slack_search_public_and_private` :
- Paramètres : `sort="timestamp"`, `sort_dir="desc"`, `response_format="concise"`, `include_context=true`, `limit=10`
- Utiliser le même filtre de date que pour l'étape 4

1. **Incidents & urgences business** :
   `"incident" OR "urgent" OR "bloquant" OR "down" OR "en panne" <date>` (exclure les canaux déjà couverts en TIER 1-2 avec `-in:`)

2. **Résultats & chiffres** :
   `"objectif" OR "résultat" OR "record" OR "conversion" OR "CA" <date>` en filtrant `-in:team-produit-tech -in:team-pretto-produit-tech`

3. **Banques & partenaires** (coeur métier) :
   `in:info-banques <date>` — changements de critères, taux, quotas
   `in:pôle-banques <date>` — sujets transverses pôle banque
   `in:alerte-pole-banque <date>` — alertes opérationnelles

4. **Client & feedback** :
   `in:espace-client <date>` — bugs remontés par les EC
   `in:qualite-des-leads <date>` — qualité du flux entrant
   `in:feedbacks-zou-client <date>` — retours utilisateurs

5. **Sales & pipeline** :
   `in:sales <date>` — seulement si fenêtre > 8h (trop de bruit sinon)

6. **Marketing & growth** :
   `in:marketing <date>` — seulement les messages avec 2+ réactions (signal de pertinence)

### Triage des résultats

Pour chaque résultat, évalue sa pertinence CTO :
- **IMPORTANT** : incident affectant les clients, changement de critères banque, problème de qualité des leads, décision business sans la tech, résultat exceptionnel (positif ou négatif)
- **FYI** : feedback intéressant, tendance marché, sujet opérationnel qui pourrait devenir technique
- **IGNORER** : bruit opérationnel quotidien, conversations entre EC, questions individuelles de sales

Ne garder que les résultats IMPORTANT et FYI. Lire les threads complets des résultats IMPORTANT.

### Canaux business de référence

- #info-banques — critères, taux, contacts, quotas (IMPORTANT : tout changement de critères impact le moteur de financement)
- #pôle-banques — sujets transverses pôle banque
- #alerte-pole-banque — alertes opérationnelles banques
- #espace-client — bugs et problèmes clients (IMPORTANT : les bugs UI/UX qui remontent ici sont souvent en avance sur Sentry)
- #qualite-des-leads — qualité du flux entrant (IMPORTANT : baisse de qualité = problème marketing ou technique)
- #sales — discussions sales générales
- #mandat — problèmes opérationnels de signature/envoi
- #marketing — campagnes, stratégie acquisition
- #general — annonces company-wide

## Étape 5 — Gmail

Utilise `mcp__claude_ai_Gmail__gmail_search_messages` avec :
- q = "after:YYYY/MM/DD" (format Gmail : YYYY/M/D)
- maxResults = 100

### Triage des emails

PRIORITÉ HAUTE (lire le contenu avec gmail_read_message) :
- Emails internes écrits à la main : From @pretto.fr, To @pretto.fr, PAS un no-reply/via/automated
- Emails de personnes externes adressés directement à l'utilisateur (pas à une mailing list)

PRIORITÉ MOYENNE (noter sujet + expéditeur dans le résumé) :
- Emails internes automatiques mais actionnables (demandes d'accès, approbations)
- Réponses de clients ou partenaires

PRIORITÉ BASSE (ignorer sauf volume anormal) :
- Notifications de services (New Relic, Sentry, Zapier, Salesforce, AWS, Datadog...)
- Newsletters, marketing, invitations événements
- Notifications GitHub (PR merged, CI failed...)
- Emails via mailing lists tech@, salesforce@, aws@

Pour détecter les notifications automatiques :
- From contient "via", "noreply", "no-reply", "notifications", "alert", "support@"
- From est un domaine de service connu (zapier, newrelic, sentry, salesforce, github, aws, datadog, retool, airtable, notion, apple, google)
- Subject contient [ALERT], "exception", "error", "script exception", "your job", "daily report"
- Subject commence par "Invitation:", "Updated invitation:", "Invitation mise à jour:", "Accepted:", "Accepté:", "Declined:", "Refusé:", "Accepté provisoirement:", "Tentatively accepted:" — IGNORER (info déjà dans le calendrier)
- To est une adresse de groupe/alias (tech@, aws@, salesforce@, privacy@)
- labelIds contient CATEGORY_FORUMS ou CATEGORY_PROMOTIONS (= pas CATEGORY_PERSONAL)

Quand il y a beaucoup de notifications du même type, les regrouper : "Salesforce: 10 exceptions Apex (Ringover, ContactTrigger...)" plutôt que lister chacune.

## Étape 6 — GitHub & Board — SKIP si fenêtre < 3h

### 6a — PRs mergées sur master

```bash
gh pr list --repo finspot/pretto --state merged --search "merged:>YYYY-MM-DD" --limit 30 --json title,url,mergedAt,author
```

Grouper par auteur. Identifier les PRs qui touchent à des sujets stratégiques (architecture, sécurité, migrations, nouvelles features majeures). Ignorer le bruit (typos, bumps, petits fix).

### 6b — Mes PRs en attente

Récupère les PRs qui nécessitent ton attention :

```bash
# PRs où je suis assigné en reviewer (en attente de ma review)
gh pr list --repo finspot/pretto --search "review-requested:FSevaistre" --state open --json number,title,url,author,createdAt,additions,deletions

# Mes PRs ouvertes en attente de review
gh pr list --repo finspot/pretto --author FSevaistre --state open --json number,title,url,createdAt,additions,deletions,reviewDecision
```

Pour chaque PR trouvée :
- Si `reviewDecision` est "APPROVED" ou "CHANGES_REQUESTED" → la review est déjà faite, ne PAS la mettre dans REQUIERT TON ACTION
- Si review-requested mais la PR a déjà été reviewed/approved par d'autres et n'a plus besoin de ta review → ne PAS la mettre
- Seules les PRs réellement en attente de ton action apparaissent dans le résumé

Intègre les résultats dans le résumé :
- PRs en attente de ma review → section REQUIERT TON ACTION (seulement celles pas encore reviewées)
- Mes PRs en attente → section OUVERT avec le statut (draft, en attente de review, changes requested)

### 6c — Board Produit-Tech

Utilise `mcp__claude_ai_Notion__notion-search` avec :
- data_source_url = `collection://295d2e40-ea50-806b-9453-000bd76fc8de`
- query = termes pertinents (noms de projets en cours, batch actif)

Regarde l'état des cartes actives : ce qui a bougé, ce qui est bloqué, ce qui est terminé.

## Étape 7 — Synthèse stratégique

Une fois TOUTES les données collectées, AVANT de rédiger le résumé, fais une passe de synthèse :

1. **Recoupe les sources** : si un sujet apparaît dans un transcript ET dans Slack ET dans un 1:1, c'est un sujet important. Regroupe les infos.

2. **Identifie les initiatives en cours** : Eclipse, Arthur, migrations, core-tech, recrutement, etc. Pour chaque initiative, rassemble tout ce qui la concerne (PRs, discussions, blocages, avancées).

3. **Évalue les risques** : cartes bloquées, deadlines proches, personnes surchargées ou silencieuses, sujets qui traînent, tensions détectées.

4. **Vérifie les open items du gather précédent** : pour chaque item "OUVERT" du dernier gather, cherche dans les données collectées s'il y a eu du mouvement.

### Format du résumé

Rédige un résumé structuré en texte simple. N'inclure que les sections qui ont du contenu.

```
RÉSUMÉ — du [date début HH:mm] au [date fin HH:mm]
=====================================================

REQUIERT TON ACTION
-------------------
[Ce que tu dois faire toi-même. Décisions à prendre, reviews à faire,
messages à envoyer, arbitrages à rendre. Chaque item = qui attend quoi de toi.
IMPORTANT pour les reviews : ne lister que les PRs réellement en attente de
ta review (vérifiées via gh pr list). Si une PR a déjà été mergée, approved,
ou reviewée, ne PAS la mettre ici.]

SUIVI (depuis le dernier gather)
--------------------------------
[Pour chaque item "OUVERT" du gather précédent :]
- [sujet] → [RÉSOLU : comment] ou [AVANCÉ : détail] ou [TOUJOURS OUVERT]

PAR INITIATIVE
--------------
[Regrouper par projet/initiative, pas par source. Pour chaque initiative :]

  ECLIPSE
  - Avancées : [PRs, discussions, décisions]
  - Blocages : [ce qui coince]
  - Prochaines étapes : [ce qui est prévu]

  ARTHUR
  - ...

  CORE-TECH
  - ...

  [etc.]

ÉQUIPE
------
[Signaux sur les personnes : qui est bloqué, qui est surchargé,
qui est silencieux, feedback remontés en 1:1, sujets RH]

DÉCISIONS PRISES
----------------
[Décisions actées pendant la période, groupées par thème.
Qui a décidé, quoi, contexte minimal.]

RADAR BUSINESS
--------------
[Signaux captés hors du périmètre tech direct. Organisé par domaine :]

  BANQUES & PARTENAIRES
  - [changements de critères, nouveaux quotas, problèmes de connecteurs]

  CLIENTS & PRODUIT
  - [bugs remontés par les EC, feedback utilisateurs, problèmes d'UX]

  SALES & PIPELINE
  - [résultats notables, problèmes de qualité des leads, tendances]

  MARCHÉ
  - [annonces, mouvements concurrents, régulation]

[Ne pas inclure les sous-sections vides. Ne garder que les signaux
qui méritent l'attention d'un CTO : impacts potentiels sur la tech,
la roadmap produit, ou les décisions stratégiques.]

INCIDENTS & ALERTES
-------------------
[Incidents (New Relic, pannes), volumes anormaux (SF exceptions),
alertes non résolues. Regroupé par source.]

OUVERT
------
[Tout ce qui reste en suspens et devra être suivi au prochain gather.
Actions assignées à d'autres, sujets non tranchés, deadlines à venir.
Ce sont les items que le prochain gather reprendra dans "SUIVI".]
```

RÈGLES :
- "REQUIERT TON ACTION" est TOUJOURS la première section quand elle a du contenu
- "OUVERT" est TOUJOURS la dernière section — c'est le pont vers le prochain gather
- "PAR INITIATIVE" est le coeur du résumé — c'est là que la vision stratégique se construit
- Ne PAS lister les réunions du calendrier. Ne mentionner que le CONTENU extrait des transcripts.
- Ne PAS séparer les infos par source. Regrouper par sujet/initiative.
- Être concis mais complet. Chaque bullet = une info actionnable ou un fait notable.

## Étape 8 — Écriture dans la page Notion "Gathered" + sous-pages sources

Après avoir affiché le résumé à l'utilisateur, écris le résumé ET les données brutes dans Notion.

### 8a — Créer les sous-pages sources

Pour CHAQUE source collectée ayant du contenu, crée une sous-page sous la page Gathered (ID : `325d2e40-ea50-8194-8e49-e4f2926780ec`) avec `mcp__claude_ai_Notion__notion-create-pages` :

Types de sous-pages à créer :

1. **Transcripts Gemini** (icône : "📝") — UNE sous-page par transcript/notes de meeting
   - Titre : `YYYY-MM-DD HH:mm — Transcript — <nom du meeting>`
   - Contenu : texte complet du transcript

2. **Slack** (icône : "💬") — UNE sous-page regroupant tous les résultats Slack
   - Titre : `YYYY-MM-DD HH:mm — Slack`
   - Contenu : messages organisés par canal avec threads

3. **Gmail** (icône : "📧") — UNE sous-page regroupant les emails importants
   - Titre : `YYYY-MM-DD HH:mm — Gmail`
   - Contenu : emails haute priorité (From, To, Subject, Date, body) + notifications groupées

4. **Notion 1:1** (icône : "📓") — UNE sous-page si des 1:1 consultés
   - Titre : `YYYY-MM-DD HH:mm — Notion 1:1`
   - Contenu : extraits pertinents des 1:1

5. **Calendar** (icône : "📅") — UNE sous-page avec les events
   - Titre : `YYYY-MM-DD HH:mm — Calendar`
   - Contenu : events simplifiés (summary, start, end, attendees, hasAttachments)

6. **GitHub** (icône : "🔀") — UNE sous-page si des PRs collectées
   - Titre : `YYYY-MM-DD HH:mm — GitHub`
   - Contenu : PRs mergées groupées par auteur

7. **Radar Business** (icône : "📡") — UNE sous-page si des signaux business captés
   - Titre : `YYYY-MM-DD HH:mm — Radar Business`
   - Contenu : tous les messages business récupérés, organisés par canal/domaine

NE PAS créer de sous-page pour une source sans résultat. Créer en parallèle.

### 8b — Écrire le résumé dans la page principale

Utilise `mcp__claude_ai_Notion__notion-fetch` pour récupérer le contenu actuel, puis `mcp__claude_ai_Notion__notion-update-page` pour PREPEND.

Format :
```
## <mention-date start="YYYY-MM-DD" startTime="HH:mm" timeZone="Europe/Paris"/> — Gather

<details>
<summary>Sources (N sous-pages)</summary>
	- [liste des sous-pages]
</details>

[Le résumé complet en Notion markdown]

---
```

L'entrée la plus récente est toujours en haut. La date/heure est l'heure d'exécution du gather.
