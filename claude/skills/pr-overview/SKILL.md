---
name: pr-overview
description: Tableaux récapitulatifs des PRs ouvertes et des reviews par membre de l'équipe
disable-model-invocation: true
allowed-tools: Bash(gh *), Read
---

## PR Overview - Équipe Pretto

Génère deux tableaux markdown récapitulatifs pour chaque membre de l'équipe :
1. Les PRs ouvertes en tant qu'auteur
2. La charge de review

### Étapes

1. Lis le fichier d'équipe `~/.claude/team.json` pour récupérer tous les membres (managees et leurs sous-équipes) avec leurs GitHub handles. Le champ `me` contient l'utilisateur courant, à afficher aussi.

2. Pour gagner du temps, lance les requêtes en parallèle via un seul script bash.

#### Tableau 1 : PRs ouvertes par auteur

Pour chaque personne ayant un champ `github`, lance :
```
gh pr list --repo finspot/pretto --author <github_handle> --state open --json number,isDraft,reviewDecision
```

Classe chaque PR dans une des 3 catégories :
- Draft : `isDraft == true`
- En attente de review : `isDraft == false` ET `reviewDecision != "APPROVED"`
- Approuvées : `isDraft == false` ET `reviewDecision == "APPROVED"`

#### Tableau 2 : Charge de review

Pour chaque personne, lance deux requêtes :
```
gh pr list --repo finspot/pretto --state open --search "review-requested:<github_handle>" --json number --jq 'length'
gh pr list --repo finspot/pretto --state open --search "reviewed-by:<github_handle>" --json number --jq 'length'
```

- "En attente" = PRs ou la personne est sollicitée mais n'a pas encore répondu
- "Déjà reviewées" = PRs ou la personne a déjà soumis une review (PR encore ouverte)

### Affichage

Affiche les deux tableaux l'un après l'autre, groupés par équipe (manager). Omets les personnes qui ont 0 dans toutes les colonnes d'un tableau. Ajoute une ligne TOTAL en bas de chaque tableau.

#### Format tableau 1 : PRs ouvertes

```
Équipe          | Nom              | Draft | Review | Appro | Total
----------------|------------------| -----:| ------:| -----:| -----:
Équipe Manager  | Personne 1       |     X |      X |     X |     X
                | Personne 2       |     X |      X |     X |     X
----------------|------------------| -----:| ------:| -----:| -----:
                | TOTAL            |     X |      X |     X |     X
```

#### Format tableau 2 : Charge de review

```
Équipe          | Nom              | En attente | Déjà reviewées | Total
----------------|------------------| ----------:| --------------:| -----:
Équipe Manager  | Personne 1       |          X |              X |     X
                | Personne 2       |          X |              X |     X
----------------|------------------| ----------:| --------------:| -----:
                | TOTAL            |          X |              X |     X
```

Après les tableaux, ajoute un bref commentaire sur les points d'attention :
- Nombre élevé de drafts (potentiel nettoyage nécessaire)
- PRs approuvées non mergées (à débloquer)
- Backlog de reviews en attente élevé
- Déséquilibre de charge entre membres d'une même équipe

Utilise du texte simple, pas de gras ni d'émojis.
