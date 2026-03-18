---
description: Wrap-up d'un 1/1 récent — télécharge le transcript et met à jour la page Notion
allowed-tools: Bash, Read, Glob, Grep, mcp__claude_ai_Google_Calendar__gcal_list_events, mcp__claude_ai_Notion__notion-fetch, mcp__claude_ai_Notion__notion-update-page, mcp__claude_ai_Notion__notion-create-pages
---

L'utilisateur veut faire le wrap-up d'un 1/1 récent. L'argument optionnel est : $ARGUMENTS

## Étape 0 — Heure locale et configuration

Exécute `date +"%Y-%m-%d %H:%M %Z"` pour connaître l'heure et la date du jour.

Lis `~/.claude/team.json` pour charger la liste des managees avec leurs `notion_1to1_page`.

## Étape 1 — Trouver le 1/1 dans l'agenda

### Si un argument est fourni
L'argument est le prénom du managee. Chercher dans l'agenda du jour un 1/1 avec cette personne.

### Si aucun argument
Chercher dans l'agenda les 1/1 récents (dernières 4 heures) avec un managee.

Utilise `mcp__claude_ai_Google_Calendar__gcal_list_events` :
- timeMin = aujourd'hui 00:00:00 (ou 4h avant maintenant si pas d'argument)
- timeMax = maintenant
- timeZone = Europe/Paris
- condenseEventDetails = false

Identifier les events qui sont des 1/1 avec un managee :
- Le titre contient "1:1", "1/1", "one on one", ou le prénom d'un managee
- Un des attendees a l'email d'un managee

Si plusieurs 1/1 trouvés, prendre le plus récent (ou celui qui correspond à l'argument).

Si aucun 1/1 trouvé, élargir à la journée entière, puis à hier. Si toujours rien, demander à l'utilisateur.

## Étape 2 — Télécharger le transcript

Chercher le transcript/notes Gemini pour ce meeting :

1. D'abord regarder les `attachments` de l'event (hasAttachments, fichiers Google Docs liés)
2. Si pas d'attachment, chercher sur Drive :
```bash
~/.local/bin/gdrive-dl search "Notes par Gemini" --after=YYYY-MM-DD --max=10
```
3. Corréler par nom du meeting et heure

Télécharger le transcript :
```bash
mkdir -p /tmp/1to1-wrapup
~/.local/bin/gdrive-dl "<url_ou_id>" -o "/tmp/1to1-wrapup/transcript.pdf"
```

Lire le PDF complet avec l'outil Read (toutes les pages).

## Étape 3 — Analyser le transcript

Extraire du transcript les informations correspondant à chaque section du template 1/1 :

- 🌈 **Comment je me sens** : état émotionnel, énergie, moral exprimé par le managee
- 👨‍👩‍👧‍👦 **Mon équipe** : ce qui a été dit sur les membres de son équipe
- 🏃‍♂️ **Suivi des objectifs** : avancement sur les objectifs, métriques
- 🙌 **Mes succès de la semaine** : réussites, wins, choses dont le managee est fier
- 🔥 **Mes priorités de la semaine** : ce sur quoi il/elle va se concentrer
- 🔨 **Mes blocages & difficulté** : problèmes, frustrations, ce qui coince
- ☕️ **Autres sujets** : tout le reste (sujets divers, questions, infos)
- **Next steps** : actions à faire, décisions prises, follow-ups

Rester fidèle à ce qui a été dit. Utiliser des bullet points concis. Ne pas inventer de contenu. Si une section n'a pas été abordée dans le transcript, la laisser vide.

## Étape 4 — Mettre à jour la page Notion

### 4a — Fetch la page 1/1 actuelle

Utilise `mcp__claude_ai_Notion__notion-fetch` avec le `notion_1to1_page` du managee identifié.

### 4b — Trouver l'entrée du jour

Chercher dans le contenu de la page une entrée datée du jour : `### <mention-date start="YYYY-MM-DD"/>`

**CAS 1 : L'entrée du jour existe déjà**

Lire le contenu existant de chaque section. Pour chaque section :
- Si la section est VIDE (juste le titre sans contenu en dessous, ou un contenu placeholder) → la remplir avec les données du transcript
- Si la section a DÉJÀ du contenu substantiel → NE PAS écraser. Ajouter le contenu du transcript EN DESSOUS du contenu existant, séparé par une ligne vide, avec un préfixe `(transcript)` pour distinguer.

Utilise `mcp__claude_ai_Notion__notion-update-page` avec la commande `update_content` pour faire des remplacements ciblés (old_str → new_str).

**CAS 2 : L'entrée du jour n'existe PAS**

Créer une nouvelle entrée avec la date du jour, en respectant le template exact :

```
### <mention-date start="YYYY-MM-DD"/>
### Agenda
🌈**  Comment je me sens**
[contenu du transcript]
👨‍👩‍👧‍👦  **Mon équipe**
[contenu du transcript]
🏃‍♂️ **Suivi des objectifs**
[contenu du transcript]
**🙌  Mes succès de la semaine**
[contenu du transcript]
**🔥  Mes priorités de la semaine**
[contenu du transcript]
**🔨 Mes blocages & difficulté**
[contenu du transcript]
**☕️  Autres sujets**
[contenu du transcript]
### Next steps
[actions extraites du transcript]
```

Insérer cette nouvelle entrée JUSTE APRÈS le bouton (balise `<unknown ... alt="button"/>`) et AVANT l'entrée précédente. Utilise `update_content` pour trouver le bon point d'insertion :
- old_str = la première entrée datée existante (ex: `### <mention-date start="2026-03-11"/>`)
- new_str = nouvelle entrée + ancienne entrée

### 4c — Règles d'écriture

- Respecter EXACTEMENT le format des emojis et titres du template (copier depuis les entrées précédentes)
- Bullet points avec `-` pour le contenu
- Indentation avec tab pour les sous-points
- Pas de markdown riche (pas de liens, pas de gras dans le contenu, seulement dans les titres)
- Rester concis : le transcript est verbeux, les notes doivent être des bullet points courts
- Capturer le ton/sentiment quand c'est pertinent ("un peu fatigué", "motivé", "frustré par X")

## Étape 5 — Confirmation

Afficher un résumé de ce qui a été mis à jour :
- Managee
- Date du 1/1
- Sections remplies / sections déjà remplies (non touchées) / sections vides (pas abordé dans le transcript)
- Lien vers la page Notion
