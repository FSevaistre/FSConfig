---
description: Rassemble toutes les infos (agenda, transcripts, Notion, Slack, Gmail) depuis une date et produit un résumé
allowed-tools: Bash, Read, Write, Glob, Grep, mcp__claude_ai_Google_Calendar__gcal_list_events, mcp__claude_ai_Google_Calendar__gcal_get_event, mcp__claude_ai_Gmail__gmail_search_messages, mcp__claude_ai_Gmail__gmail_read_message, mcp__claude_ai_Gmail__gmail_read_thread, mcp__claude_ai_Slack__slack_search_public_and_private, mcp__claude_ai_Slack__slack_read_channel, mcp__claude_ai_Slack__slack_read_thread, mcp__claude_ai_Notion__notion-search, mcp__claude_ai_Notion__notion-fetch, mcp__claude_ai_Notion__notion-update-page, mcp__claude_ai_Notion__notion-create-pages, Agent
---

L'utilisateur veut un résumé de tout ce qui s'est passé depuis une date donnée. L'argument fourni est : $ARGUMENTS

L'argument peut contenir une date et optionnellement une heure, séparées par un espace ou tout autre format naturel. Exemples : "2026-03-14", "vendredi 14h", "lundi 10:30", "la semaine dernière", "3 jours", "aujourd'hui 15h".

La date (et heure si fournie) est interprétée comme le début de la période. La fin est maintenant. Si l'argument est vide ou absent, utiliser aujourd'hui à 00:00:00 comme début (gather sur la journée en cours). Si l'argument est relatif (ex: "lundi", "la semaine dernière", "3 jours"), convertis-le en date/heure absolue. Si une heure est fournie sans date, utiliser aujourd'hui à cette heure. Si aucune heure n'est fournie, utiliser 00:00:00.

### Reprise automatique depuis le dernier gather

Si l'argument est vide, AVANT de commencer la collecte, récupère la page Notion "Gathered" (ID : `325d2e40-ea50-8194-8e49-e4f2926780ec`) avec `mcp__claude_ai_Notion__notion-fetch`. Regarde la première entrée (la plus récente, en haut de page) et extrais la date/heure du dernier gather. Utilise cette date/heure comme date de début au lieu de minuit aujourd'hui. Cela permet d'enchaîner les gathers sans trous ni doublons.

Si l'argument est explicitement fourni, l'utiliser tel quel (pas de reprise automatique).

### Heure locale

AVANT de commencer, exécute `date +"%Y-%m-%d %H:%M %Z"` pour connaître l'heure locale exacte. Utilise TOUJOURS cette heure pour les timestamps dans le résumé et la page Notion. Ne JAMAIS deviner l'heure ou utiliser UTC — l'utilisateur est en Europe/Paris.

Suis ces étapes dans l'ordre. IMPORTANT : collecte un maximum de données AVANT de rédiger le résumé final. Utilise des agents en parallèle quand c'est possible pour aller plus vite. NE PAS OUBLIER l'étape 7 (écriture Notion + sous-pages sources) après avoir affiché le résumé.

PRIORITÉ DES SOURCES (de la plus riche à la moins riche) :
1. TRANSCRIPTS & NOTES GEMINI — c'est LA source la plus importante. Ils contiennent le verbatim des discussions, les décisions, les désaccords, les actions. Toujours les télécharger et les lire en entier.
2. Slack canaux TIER 1 (comex, management, core-tech)
3. Emails internes écrits à la main
4. Notion
5. Slack autres canaux
6. Emails automatiques / notifications

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

### 3a bis — Pages "Generated by Claude" sous chaque 1:1

Chaque page 1:1 contient une sous-page "Generated by Claude" (icône 🤖) qui stocke les briefings générés par la commande /1to1. Ces briefings contiennent des données déjà agrégées (Slack, GitHub, Board, emails) sur le managee et son équipe.

Pour chaque page 1:1 :
1. Cherche la sous-page "Generated by Claude" dans le contenu (balise `<page>` avec le titre "Generated by Claude")
2. Utilise `mcp__claude_ai_Notion__notion-fetch` pour la lire
3. Si elle contient des sous-pages datées (briefings), lis la plus récente
4. Extrais les informations pertinentes qui datent de la période du gather (pas les briefings trop anciens)

Ces briefings sont une source précieuse car ils contiennent déjà un résumé structuré de l'activité du managee (PRs, cartes board, messages Slack, blocages, points d'attention).

Intègre ces éléments directement dans le résumé final (sections CE QUI S'EST PASSÉ et DÉCISIONS EN ATTENTE), NE PAS les lister séparément.

### 3b — Autres pages Notion

Utilise `mcp__claude_ai_Notion__notion-search` pour chercher les pages modifiées récemment :
- Fais une recherche avec un filtre `created_date_range` avec start_date = date de début
- Cherche avec des termes génériques liés au travail de l'utilisateur

Utilise `mcp__claude_ai_Notion__notion-fetch` sur les pages les plus pertinentes pour lire leur contenu.

## Étape 4 — Slack

Fais plusieurs recherches avec `mcp__claude_ai_Slack__slack_search_public_and_private` :
- `from:<@U3KR4PTDX> on:YYYY-MM-DD` — messages envoyés par l'utilisateur
- `to:<@U3KR4PTDX> on:YYYY-MM-DD` — messages adressés à l'utilisateur
- `on:YYYY-MM-DD` dans des canaux importants si connus

Paramètres : `sort="timestamp"`, `sort_dir="desc"`, `include_context=false`, `response_format="concise"`

IMPORTANT — Filtres de date Slack :
- Pour un gather sur une seule journée : utiliser `on:YYYY-MM-DD`
- Pour un gather sur plusieurs jours : utiliser `after:YYYY-MM-DD` avec la veille du jour de début (le filtre `after:` est exclusif dans Slack, il faut soustraire 1 jour). Ex: pour commencer le 14 mars, utiliser `after:2026-03-13`.
- NE JAMAIS utiliser `after:YYYY-MM-DD` avec la date du jour elle-même, ça exclut le jour courant.

### Hiérarchie des canaux Slack

Tous les canaux sont lus et collectés. Les tiers déterminent le niveau de détail dans le RÉSUMÉ :

TIER 1 — Direction & stratégie (résumer chaque message/thread en détail, citer qui a dit quoi) :
- #comex (C02RKJG8P0Q)
- #comex-et-legal (C04BC17BF62)
- #management_group (GPW8XBBUZ)
- #product-management (G04CQC4JXNE)
- #tech-management (C03337XES3Z)
- #core-tech (C031Y86H4TV)
- DMs et group DMs (canaux de type im/mpim)

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

### Collecte et triage

TOUJOURS lire les threads complets (slack_read_thread) pour :
- Tout message dans un canal TIER 1
- DMs et group DMs
- Messages où l'utilisateur est mentionné (@François)
- Messages écrits par l'utilisateur lui-même
- Tout thread avec 3+ réponses quel que soit le canal

Pour les canaux TIER 2-3, lire aussi les threads si le sujet semble important (décision, blocage, lien partagé, annonce).

Tout est collecté et stocké dans la sous-page Slack. Le résumé est ensuite rédigé avec le niveau de détail correspondant au tier.

Pour les recherches, faire en priorité :
1. `in:comex on:YYYY-MM-DD`
2. `in:management_group on:YYYY-MM-DD`
3. `in:tech-management on:YYYY-MM-DD`
4. `in:core-tech on:YYYY-MM-DD`
5. `in:product-management on:YYYY-MM-DD`
6. `from:<@U3KR4PTDX> on:YYYY-MM-DD` (messages envoyés par l'utilisateur)
7. `to:<@U3KR4PTDX> on:YYYY-MM-DD` (messages adressés à l'utilisateur)

Si un thread semble contenir une décision ou une action, utilise `mcp__claude_ai_Slack__slack_read_thread` pour lire le détail.

### Threads actifs à surveiller

En plus des recherches ci-dessus, cherche les threads avec beaucoup d'activité (3+ réponses) sur les canaux TIER 1 et TIER 2 :
- `is:thread on:YYYY-MM-DD in:<canal>` pour chaque canal TIER 1 et TIER 2
- Regarde le champ `reply_count` dans les résultats de recherche. Tout thread avec 3+ réponses est considéré actif.

Pour chaque thread actif détecté :
1. Lis le thread complet avec `slack_read_thread`
2. Fais un mini-résumé : sujet, participants, conclusion ou état actuel
3. Évalue si l'utilisateur devrait intervenir. Critères d'intervention :
   - Une question est posée sans réponse et FS pourrait y répondre
   - Une décision est en train d'être prise sans l'avis de FS
   - Un blocage est signalé qui remonte à FS
   - Un désaccord qui pourrait nécessiter un arbitrage
   - L'utilisateur est mentionné mais n'a pas encore répondu

Dans le résumé final, ajoute une section dédiée si des threads nécessitent une intervention :

```
THREADS ACTIFS À SURVEILLER
----------------------------
- #canal — sujet (N réponses) : [résumé 1 ligne]. ACTION REQUISE : [ce qu'il faudrait faire]
- #canal — sujet (N réponses) : [résumé 1 ligne]. RAS, juste FYI.
```

Ne lister que les threads avec du contenu substantiel (pas les threads de 3 emojis).

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

## Étape 7 — Écriture dans la page Notion "Gathered" + sous-pages sources

Après avoir affiché le résumé à l'utilisateur, écris le résumé ET les données brutes dans Notion.

### 7a — Créer les sous-pages sources

Pour CHAQUE source collectée ayant du contenu, crée une sous-page sous la page Gathered (ID : `325d2e40-ea50-8194-8e49-e4f2926780ec`) avec `mcp__claude_ai_Notion__notion-create-pages` :

```json
{
  "parent": {"page_id": "325d2e40-ea50-8194-8e49-e4f2926780ec"},
  "pages": [
    {
      "properties": {"title": "YYYY-MM-DD HH:mm — <type source> — <nom>"},
      "icon": "<emoji>",
      "content": "<contenu brut>"
    }
  ]
}
```

Types de sous-pages à créer (une par source, regrouper quand c'est logique) :

1. **Transcripts Gemini** (icône : "📝") — UNE sous-page par transcript/notes de meeting
   - Titre : `YYYY-MM-DD HH:mm — Transcript — <nom du meeting>`
   - Contenu : le texte complet du transcript tel que lu dans le PDF (notes Gemini + transcription verbatim si disponible)

2. **Slack** (icône : "💬") — UNE sous-page regroupant tous les résultats Slack
   - Titre : `YYYY-MM-DD HH:mm — Slack`
   - Contenu : tous les messages récupérés, organisés par canal avec les threads lus. Format :
     ```
     ### #canal-name
     - [timestamp] @user : message
     - [timestamp] @user : message
       Thread (N replies) :
       - @user : reply
       - @user : reply
     ```

3. **Gmail** (icône : "📧") — UNE sous-page regroupant les emails importants lus
   - Titre : `YYYY-MM-DD HH:mm — Gmail`
   - Contenu : pour chaque email lu avec gmail_read_message, inclure From, To, Subject, Date et le body. Pour les emails non lus (notifications), lister juste le sujet groupé.

4. **Notion 1:1** (icône : "📓") — UNE sous-page si des pages 1:1 ont été consultées
   - Titre : `YYYY-MM-DD HH:mm — Notion 1:1`
   - Contenu : les extraits pertinents des pages 1:1 consultées (dernière entrée de chaque 1:1)

5. **Calendar** (icône : "📅") — UNE sous-page avec la liste brute des events
   - Titre : `YYYY-MM-DD HH:mm — Calendar`
   - Contenu : dump JSON simplifié des events (summary, start, end, attendees, hasAttachments)

NE PAS créer de sous-page pour une source qui n'a donné aucun résultat.

Les sous-pages peuvent être créées en parallèle dans un seul appel à `notion-create-pages` (multi-pages).

### 7b — Écrire le résumé dans la page principale

Utilise `mcp__claude_ai_Notion__notion-fetch` pour récupérer le contenu actuel de la page, puis `mcp__claude_ai_Notion__notion-update-page` pour PREPEND (ajouter AU DESSUS du contenu existant) une nouvelle entrée.

Format de chaque entrée :
```
## <mention-date start="YYYY-MM-DD" startTime="HH:mm" timeZone="Europe/Paris"/> — Gather

<details>
<summary>Sources collectées (N sous-pages)</summary>
	- [liste des sous-pages créées avec leur titre]
</details>

[Le résumé complet en Notion markdown — utiliser ### pour les sous-sections, **gras** pour les noms, - pour les listes]

---
```

L'entrée la plus récente doit toujours être en haut de la page. La date/heure dans le heading est l'heure actuelle (= le moment où le gather est exécuté), ce qui permet au prochain gather sans argument de reprendre depuis cette heure.
