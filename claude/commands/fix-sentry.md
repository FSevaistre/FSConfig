---
description: Récupère les top erreurs Sentry non assignées, analyse et corrige avec une PR par erreur
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, ToolSearch, mcp__claude_ai_Sentry__find_organizations, mcp__claude_ai_Sentry__find_projects, mcp__claude_ai_Sentry__search_issues, mcp__claude_ai_Sentry__get_issue_details, mcp__claude_ai_Sentry__search_events
---

L'utilisateur veut corriger les erreurs Sentry les plus fréquentes. Arguments optionnels : $ARGUMENTS

## Configuration par défaut

- Organisation Sentry : `pretto-6b` (regionUrl: `https://us.sentry.io`)
- Projets à scanner : `finspot-api`, `pretto-api`, `oleen-backend`
- Nombre d'erreurs à traiter : 10
- Filtres d'exclusion : issues assignées, issues contenant `EventBus::Error`
- Période : 24 dernières heures
- PRs créées en **draft**

Si l'utilisateur passe des arguments, adapte la configuration (ex: "5 erreurs sur finspot-api", "pretto-api seulement", "48h").

## Étape 1 — Collecte des issues Sentry

Charge les outils Sentry via ToolSearch si nécessaire.

Pour chaque projet configuré, en parallèle :
1. Appelle `mcp__claude_ai_Sentry__search_issues` avec :
   - `naturalLanguageQuery`: "unresolved issues in last 24 hours sorted by frequency"
   - `limit`: 30
2. Collecte tous les résultats

## Étape 2 — Filtrage et tri

Depuis les résultats bruts :
1. **Exclure** les issues assignées (champ "Assigned to" présent)
2. **Exclure** les issues dont le titre contient `EventBus::Error`
3. **Trier** par nombre d'events décroissant (tous projets confondus)
4. **Garder** les N premières (10 par défaut)

Affiche le classement à l'utilisateur avec : rang, ID Sentry, nombre d'events, titre court, projet.

## Étape 3 — Analyse détaillée

Pour chaque issue retenue, en parallèle (par batch de 5 max) :
1. Appelle `mcp__claude_ai_Sentry__get_issue_details` pour récupérer la stacktrace
2. Identifie le fichier et la ligne du code first-party responsable
3. Classe l'issue dans une catégorie :
   - **code-fix** : bug corrigible dans le code (enum manquant, traduction manquante, N+1, race condition, state machine, etc.)
   - **infra** : timeout, connexion redis/DB, API externe indisponible — pas corrigible dans le code
   - **noise** : warning/log envoyé à Sentry par erreur, comportement normal logué comme erreur

Affiche le diagnostic à l'utilisateur. Demande confirmation avant de passer aux corrections.

## Étape 4 — Corrections

Pour chaque issue classée **code-fix** ou **noise** :

### 4a. Lire le code

1. Lis le(s) fichier(s) identifié(s) dans la stacktrace
2. Comprends le contexte : modèles associés, associations, state machines, enums, i18n, etc.
3. Détermine la correction minimale nécessaire

### 4b. Créer la branche et le fix

Pour chaque fix, séquentiellement :

1. `git checkout master` et vérifier qu'on est clean
2. `git checkout -b fix/<SENTRY-ID>-<description-courte>`
3. Appliquer le fix (Edit/Write)
4. `git add <fichiers>` puis commit :
   ```
   fix(<app>): <description courte>

   Fixes <SENTRY-ID>

   Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
   ```
5. `git push -u origin <branche>`
6. Créer la PR draft avec `gh pr create --draft` :
   - Titre : `fix(<app>): <description courte>`
   - Body avec ce template :
     ```
     ## Summary
     - <1-3 bullet points expliquant le fix>

     ## Sentry
     https://pretto-6b.sentry.io/issues/<SENTRY-ID> (<N> events)

     ## Test plan
     - [ ] <vérifications à faire>

     🤖 Generated with [Claude Code](https://claude.com/claude-code)
     ```
7. Vérifier que `git branch --show-current` correspond bien à la branche attendue avant chaque commit (protection contre les switchs de branche parasites)

### 4c. Issues infra

Pour les issues **infra**, ne rien faire mais les lister dans le récap final avec une suggestion (ex: "augmenter le timeout", "ajouter un retry", "vérifier la config Redis").

## Étape 5 — Récap final

Affiche un tableau récapitulatif :

| Sentry ID | Events | Projet | Catégorie | Action | PR |
|-----------|--------|--------|-----------|--------|----|
| PRETTO-API-XX | 5000 | pretto-api | code-fix | fix enum validation | #42236 |
| OLEEN-BACKEND-YY | 1200 | oleen-backend | infra | lock contention DB | - |

## Règles importantes

- Ne jamais modifier du code sans l'avoir lu d'abord
- Privilégier les fixes minimaux et ciblés (pas de refactoring)
- Si un fix nécessite de comprendre beaucoup de contexte, lancer un Agent Explore
- Si un fix semble risqué ou ambigu, le signaler à l'utilisateur plutôt que de deviner
- Toujours vérifier la branche courante avant de commit (git branch --show-current)
- Ne pas toucher aux fichiers qui ne sont pas directement liés au fix
- Mettre à jour les specs si le fix modifie un comportement testé
