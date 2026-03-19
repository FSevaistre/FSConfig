---
description: Briefing du matin - agenda, 1:1 du jour, gather, plan d'action, temps disponible
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, Skill, mcp__claude_ai_Google_Calendar__gcal_list_events, mcp__claude_ai_Google_Calendar__gcal_get_event, mcp__claude_ai_Notion__notion-fetch, mcp__claude_ai_Notion__notion-search, mcp__claude_ai_Notion__notion-update-page, mcp__claude_ai_Notion__notion-create-pages, mcp__claude_ai_Slack__slack_search_public_and_private, mcp__claude_ai_Slack__slack_read_thread, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Gmail__gmail_search_messages, mcp__claude_ai_Gmail__gmail_read_message
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

## Etape 2 — Detecter les 1:1 du jour

Lis `~/.claude/team.json` pour obtenir la liste des managees (first_name).

Pour chaque event du calendrier du jour, verifie si le titre contient "1:1", "1/1", "one on one", ou le prenom d'un managee (match insensible a la casse). Si c'est un 1:1 avec un managee :
1. Note le managee et l'heure
2. Lance la commande `/1to1 <prenom ou alias>` via l'outil Skill pour preparer le briefing

Lancer les /1to1 en SEQUENTIEL (pas en parallele, chaque /1to1 est un skill complet qui fait beaucoup d'appels).

Si aucun 1:1 n'est detecte, skip cette etape.

## Etape 3 — Gather

Lance `/gather` via l'outil Skill (sans argument = reprise automatique depuis le dernier gather).

Attends le resultat avant de continuer.

## Etape 4 — Plan d'action

Recupere le plan d'action depuis Notion :
- Data source : `collection://c4f17e42-c412-4b75-8f8e-588b9b7e5bea`
- Utilise `mcp__claude_ai_Notion__notion-search` avec data_source_url et query vide ou generique pour lister les cartes

Filtre les cartes qui ne sont PAS done/terminées. Pour chaque carte active, note :
- Titre
- Statut
- Priorite (si disponible)
- Date limite (si disponible)
- Owner / assignee

Si la recherche ne retourne pas assez de resultats, utilise `mcp__claude_ai_Notion__notion-fetch` directement sur le board (`f5b2bbdd-96c8-4431-bdbb-29cc6acb9121`) pour voir la structure.

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

1:1 DU JOUR
-----------
[Pour chaque 1:1 detecte, un mini-resume du briefing /1to1 :]

  1:1 Xavier (10:00) :
  - Points cles : [2-3 bullets du briefing]
  - Sujets a aborder : [les suggestions du briefing]

RATTRAPAGE (gather)
-------------------
[Resume du /gather — reprendre les sections REQUIERT TON ACTION et OUVERT]

PLAN D'ACTION
-------------
[Cartes actives du board, triees par priorite :]
- [carte 1] — statut, deadline si applicable
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
  - [items REQUIERT TON ACTION du gather]
  - [cartes plan d'action avec deadline proche]
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

Le message principal contient l'AGENDA DU JOUR (liste des reunions + temps libre + blocs libres).
Les sections suivantes sont envoyees en replies dans le thread (thread_ts du message principal) :
1. Les 1:1 du jour (resume de chaque briefing)
2. Le rattrapage (gather : REQUIERT TON ACTION, decisions prises, equipe)
3. MA JOURNEE (suggestions pour les blocs libres + actions urgentes)

REGLES :
- Pas d'accents dans les messages Slack (Slack API peut les rejeter selon l'encodage)
- Pas d'emojis unicode dans le texte (sauf si explicitement demande)
- Utiliser le formatting Slack standard : *bold* pour les titres, - pour les listes
- Max 4000 chars par message, decouper si necessaire
- Ne pas envoyer les sections vides
