---
description: Briefing du matin - agenda, 1:1 du jour, gather, plan d'action, temps disponible
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, Skill, mcp__claude_ai_Google_Calendar__gcal_list_events, mcp__claude_ai_Google_Calendar__gcal_get_event, mcp__claude_ai_Notion__notion-fetch, mcp__claude_ai_Notion__notion-search, mcp__claude_ai_Notion__notion-update-page, mcp__claude_ai_Notion__notion-create-pages, mcp__claude_ai_Slack__slack_search_public_and_private, mcp__claude_ai_Slack__slack_read_thread, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Slack__slack_send_message_draft, mcp__claude_ai_Gmail__gmail_search_messages, mcp__claude_ai_Gmail__gmail_read_message
---

Briefing du matin pour le CTO. L'objectif est de preparer la journee en 1 seul endroit.

## Etape 0 — Heure locale

Exécute `date +"%Y-%m-%d %H:%M %Z"` pour connaître l'heure et la date du jour. Utilise TOUJOURS cette date pour toutes les recherches.

## Etape 1 — Agenda du jour

Utilise `mcp__claude_ai_Google_Calendar__gcal_list_events` :
- timeMin = aujourd'hui 00:00:00
- timeMax = aujourd'hui 23:59:59
- timeZone = Europe/Paris
- condenseEventDetails = false
- maxResults = 50

Pour chaque event, note :
- Heure de debut et fin
- Titre
- Participants (numAttendees + noms si disponibles)
- hasAttachments (pour les transcripts post-reunion)

Calcule :
- **Temps total en reunion** : somme des durees de tous les meetings (hors all-day, hors working locations, hors events perso identifies par colorId ou absence d'attendees pro)
- **Temps hors reunion** : heures de bureau (9h-19h = 10h) - temps en reunion
- **Blocs libres** : les creneaux > 30min sans reunion entre 9h et 19h. Lister chaque bloc avec sa duree.

## Etape 1bis — Absences de la semaine (Lucca)

Lance `/lucca` via l'outil Skill (sans argument = absences de l'équipe pour la semaine en cours).

Intègre le résultat dans la synthèse finale (section ABSENCES DE LA SEMAINE) et dans le message Slack principal.

## Etape 2 — Detecter les 1:1 du jour

Lis `~/.claude/team.json` pour obtenir la liste des managees (first_name).

Pour chaque event du calendrier du jour, verifie si le titre contient "1:1", "1/1", "one on one", ou le prenom d'un managee (match insensible a la casse). Si c'est un 1:1 avec un managee :
1. Note le managee et l'heure
2. Lance la commande `/1to1 <prenom ou alias>` via l'outil Skill pour preparer le briefing

Lancer les /1to1 en SEQUENTIEL (pas en parallele, chaque /1to1 est un skill complet qui fait beaucoup d'appels).

OPTIMISATION : si il y a 2+ 1:1 dans la journee, lancer le /gather (etape 3) en PARALLELE du 2e /1to1 via un Agent en background. Le gather et le 2e 1:1 sont independants et peuvent tourner en meme temps. Attendre que les deux soient termines avant de passer a l'etape 4.

Si aucun 1:1 n'est detecte, skip cette etape.

## Etape 3 — Gather

Lance `/gather` via l'outil Skill (sans argument = reprise automatique depuis le dernier gather).

Attends le resultat avant de continuer.

## Etape 3bis — Veille marche (optionnelle)

Lance `/market-watch` via l'outil Skill. Cette etape fournit le contexte macro du marche du credit immobilier (taux, OAT, decisions bancaires, geopolitique).

Integre les signaux forts dans la section RATTRAPAGE du briefing final (1-2 lignes max, pas le rapport complet).
Le rapport complet est ecrit dans la page Gathered par le skill lui-meme.

Si le morning coffee prend deja trop de temps (> 15 minutes ecoulees depuis le debut), SKIP cette etape.

## Etape 4 — Plan d'action + reconciliation avec le gather

### 4a — Recuperer le plan d'action

Recupere le plan d'action depuis Notion :
- Data source : `collection://c4f17e42-c412-4b75-8f8e-588b9b7e5bea`
- Utilise `mcp__claude_ai_Notion__notion-search` avec data_source_url et query vide ou generique pour lister les cartes

Filtre les cartes qui ne sont PAS done/terminées. Pour chaque carte active, note :
- Titre
- Statut (Done / Not started / In progress)
- Date limite (Due Date)
- Owner / assignee
- Timebox (heures)

Si la recherche ne retourne pas assez de resultats, utilise `mcp__claude_ai_Notion__notion-fetch` directement sur le board (`f5b2bbdd-96c8-4431-bdbb-29cc6acb9121`) pour voir la structure.

### 4b — Reconcilier chaque action du gather avec le plan d'action

Pour CHAQUE item de la section "REQUIERT TON ACTION" du gather, cherche si une carte correspondante existe deja dans le plan d'action (match par sujet, pas necessairement par titre exact — utiliser le bon sens).

Applique ces regles :

1. **Carte existe + statut Done** → SUPPRIMER de la liste des actions. C'est deja fait. Ne pas le mentionner dans le briefing.

2. **Carte existe + Due Date = aujourd'hui (ou pas de date)** → GARDER dans le briefing. Mentionner "(plan d'action)" a cote pour indiquer que c'est deja tracke.

3. **Carte existe + Due Date dans le futur (apres aujourd'hui)** → SUPPRIMER de la liste des actions du jour. On fera plus tard. Ne pas le mentionner dans le briefing.

4. **Carte n'existe PAS** → CREER une nouvelle carte dans le plan d'action :
   - Data source : `collection://c4f17e42-c412-4b75-8f8e-588b9b7e5bea`
   - Properties :
     - Name : titre descriptif court de l'action
     - Done : "Not started"
     - Due Date : date du jour
     - Timebox : estimation en heures (0.5 pour un truc rapide, 1-2 pour du travail de fond)
   - Mentionner "(ajoute dans le plan d'action)" a cote dans le briefing.

IMPORTANT : utiliser `mcp__claude_ai_Notion__notion-create-pages` avec le parent `data_source_id: c4f17e42-c412-4b75-8f8e-588b9b7e5bea` pour creer les cartes. Bien utiliser les bons noms de proprietes du schema : "Name" (title), "Done" (status), "Timebox (heures)" (number), et les proprietes de date au format "date:Due Date:start", "date:Due Date:is_datetime".

Le resultat de cette reconciliation est la liste finale des actions du jour : uniquement les items pertinents pour AUJOURD'HUI, chacun annote de son origine.

## Etape 5 — Synthese Morning Coffee

Redige le briefing du matin. Format texte simple :

```
MORNING COFFEE — [jour, date]
==============================

AGENDA DU JOUR
--------------
[Liste chronologique des reunions avec heure, duree, participants]

  09:00 - 09:30  Tech Management (FH, Xavier, Etienne, Ophelie)
  10:00 - 10:30  1:1 Xavier ← briefing prepare
  ...

  Temps en reunion : Xh XXmin
  Temps libre : Xh XXmin
  Blocs libres :
  - 11:00-13:00 (2h)
  - 15:30-19:00 (3h30)

ABSENCES DE LA SEMAINE
----------------------
[Absences récupérées depuis Lucca, jour par jour]

  Lundi    : Kévin Morpain (congés)
  Mardi    : Kévin Morpain (congés), Alice Mothe (congés)
  ...

  Absent(e)s aujourd'hui : Kévin Morpain

1:1 DU JOUR
-----------
[Pour chaque 1:1 detecte, un mini-resume du briefing /1to1 :]

  1:1 Xavier (10:00) :
  - Points cles : [2-3 bullets du briefing]
  - Sujets a aborder : [les suggestions du briefing]

RATTRAPAGE (gather)
-------------------
[Resume du /gather — UNIQUEMENT les actions qui ont survecu a la
reconciliation avec le plan d'action (etape 4b). Chaque item est annote :]

- [action 1] (plan d'action)          ← etait deja dans le plan, due aujourd'hui
- [action 2] (ajoute dans le plan d'action)  ← n'existait pas, carte creee
- [action 3] (plan d'action)          ← idem

[Les items Done ou prevus dans le futur ne sont PAS listes ici.]

PLAN D'ACTION
-------------
[Cartes actives du board dues aujourd'hui ou sans date, triees par priorite.
Ne pas re-lister les items deja dans RATTRAPAGE.]
- [carte 1] — statut, timebox si dispo
- [carte 2] — statut
...

MA JOURNEE
----------
[Synthese actionnable : qu'est-ce que je fais de mes blocs libres ?]

  Bloc 11:00-13:00 (2h) :
  → Suggestion : [action du plan d'action ou item REQUIERT TON ACTION]

  Bloc 15:30-19:00 (3h30) :
  → Suggestion : [autre action]

  Actions urgentes a caser :
  - [items REQUIERT TON ACTION ayant survecu la reconciliation]
  - [cartes plan d'action dues aujourd'hui]
  - [items marques "ajoute dans le plan d'action"]
```

REGLES :
- Ne pas repeter le contenu integral du gather ou des 1:1. Juste les points cles.
- La section MA JOURNEE est la plus importante : elle connecte le temps disponible aux actions a mener.
- Etre pragmatique sur les suggestions de blocs : ne pas suggerer du deep work sur un bloc de 30min.
- Si pas de 1:1, omettre la section.
- Si le plan d'action est vide, omettre la section.

## Etape 6 — Affichage

Affiche le briefing directement dans la console. NE PAS publier dans Notion.
Le /gather et les /1to1 publient deja leurs resultats dans Notion -- le morning coffee est juste un agregat pour la console.

## Etape 7 — Envoi par Slack DM

Envoie le briefing en DM Slack a l'utilisateur (slack_id : U3KR4PTDX) avec `mcp__claude_ai_Slack__slack_send_message`.

Le message principal contient l'AGENDA DU JOUR (liste des réunions + temps libre + blocs libres) + les ABSENCES DE LA SEMAINE.
Les sections suivantes sont envoyées en replies dans le thread (thread_ts du message principal) :
1. Les 1:1 du jour (résumé de chaque briefing)
2. Le rattrapage (gather : REQUIERT TON ACTION, décisions prises, équipe)
3. MA JOURNÉE (suggestions pour les blocs libres + actions urgentes)

REGLES :
- Pas d'emojis unicode dans le texte (sauf si explicitement demandé)
- Utiliser le formatting Slack standard : *bold* pour les titres, - pour les listes
- Max 4000 chars par message, decouper si necessaire
- Ne pas envoyer les sections vides

## Etape 8 — Proposition d'amelioration

Contexte : l'utilisateur est CTO. Son objectif est de savoir comment l'entreprise vit pour aller la ou on peut avoir besoin de lui. Le morning coffee doit etre un peu mieux chaque jour.

A la toute fin de l'execution (apres l'envoi Slack), prends du recul sur le morning coffee qui vient de se derouler et propose 1 a 3 ameliorations concretes. Pour chaque amelioration :
- Decris le probleme ou le manque observe pendant cette execution
- Propose une modification precise (quelle etape, quel fichier, quel changement)
- Estime l'impact (quel gain pour le CTO au quotidien)

Types d'ameliorations possibles :
- ANGLES MORTS : des informations qui manquaient et qui auraient ete utiles (ex: un canal Slack non couvert, une source de donnees ignoree, un signal business rate)
- BRUIT : des informations qui ont ete collectees mais qui n'apportent rien au CTO (ex: trop de notifications automatiques, sections vides, doublons entre gather et 1:1)
- FORMAT : des ameliorations de lisibilite ou de structure du briefing (ex: une section trop longue, un tri manquant, une info mal placee)
- FLUX : des ameliorations du process lui-meme (ex: une etape trop lente, un skill manquant, une reconciliation mal faite)
- PROFONDEUR : des endroits ou l'analyse devrait aller plus loin (ex: lire un thread Slack important, croiser deux sources, detecter un pattern)

Affiche les propositions dans la console. Si l'utilisateur valide une amelioration, applique-la immediatement en modifiant le fichier skill correspondant (morning-coffee.md, gather.md, 1to1.md, etc.).
