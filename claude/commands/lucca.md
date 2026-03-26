---
description: Absences Lucca — équipe, personne, ou période
allowed-tools: Bash, Read
---

Consulte les absences sur Lucca. L'argument fourni est : $ARGUMENTS

## Parsing de l'argument

L'argument peut être :
- **Vide** : afficher les absences de toute l'équipe pour la semaine en cours
- **Un prénom ou nom** : afficher les absences de cette personne (match partiel insensible à la casse sur le prénom, le nom, ou les aliases dans team.json)
- **Une date** : afficher les absences de toute l'équipe pour la semaine contenant cette date
- **Un prénom + une date** : combiner les deux filtres
- **"aujourd'hui"** ou **"demain"** : raccourcis pour la date du jour ou du lendemain
- **"semaine prochaine"** : la semaine suivante (lundi à vendredi)

Exemples :
- `/lucca` → absences de l'équipe cette semaine
- `/lucca Xavier` → absences de Xavier cette semaine
- `/lucca semaine prochaine` → absences de l'équipe semaine prochaine
- `/lucca Etienne 2026-04-15` → absences d'Etienne pour la semaine du 15 avril

## Étape 1 — Heure locale et dates

Exécute `date +"%Y-%m-%d %u"` pour connaître la date du jour et le jour de la semaine (1=lundi).

Calcule le lundi et le vendredi de la semaine cible :
- Si pas de date spécifiée : semaine en cours
- Si "semaine prochaine" : lundi suivant → vendredi suivant
- Si date spécifiée : lundi et vendredi de la semaine contenant cette date

## Étape 2 — Charger l'équipe

Lis `~/.claude/team.json` pour obtenir la liste complète de l'équipe (me + managees + leurs teams). Collecte tous les `lucca_id` et les noms.

Si un nom est spécifié dans l'argument, filtre pour ne garder que cette personne (match sur first_name, name, ou aliases).

## Étape 3 — Appeler l'API Lucca

Appelle l'API Lucca pour récupérer les périodes d'absence confirmées qui chevauchent la semaine cible :

```bash
LUCCA_KEY=$(cat ~/.claude/.lucca-key)
curl -s -H "Authorization: lucca application=$LUCCA_KEY" \
  "https://pretto.ilucca.net/api/v3/leaveperiods?paging=0,500&fields=id,startsOn,startsAM,endsOn,endsAM,ownerId,owner.name&startsOn=until,VENDREDI&endsOn=since,LUNDI&isConfirmed=true"
```

Remplace LUNDI et VENDREDI par les dates calculées (format YYYY-MM-DD). Ajoute 1 jour au vendredi pour inclure le vendredi lui-même (endsOn=since,SAMEDI ou ajuster si besoin).

## Étape 4 — Filtrer et formater

### Si pas de filtre par personne (vue équipe)

Filtre les résultats pour ne garder que les ownerId qui correspondent à un lucca_id dans team.json.

Affiche jour par jour :

```
ABSENCES ÉQUIPE — Semaine du [lundi] au [vendredi]
===================================================
  Lundi [date]    : Kévin Morpain, Alban Diguer
  Mardi [date]    : Kévin Morpain
  Mercredi [date] : (personne)
  Jeudi [date]    : Olivier Remy
  Vendredi [date] : Olivier Remy, Maxime Vincent

  Absent(e)s aujourd'hui : Kévin Morpain, Alban Diguer
```

Regrouper aussi par équipe (managee → ses reports) pour une vue hiérarchique :

```
PAR ÉQUIPE
----------
  Xavier : Thomas (lun-mar), Alban (lun)
  Etienne : Kévin (toute la semaine), Olivier (jeu-ven)
  FH : (personne)
  Ophélie : (personne)
  David : (personne)
```

### Si filtre par personne (vue individuelle)

Affiche toutes les absences à venir de cette personne (pas seulement la semaine cible). Pour ça, appeler :

```bash
LUCCA_KEY=$(cat ~/.claude/.lucca-key)
curl -s -H "Authorization: lucca application=$LUCCA_KEY" \
  "https://pretto.ilucca.net/api/v3/leaveperiods?paging=0,50&fields=id,startsOn,startsAM,endsOn,endsAM,ownerId,owner.name&ownerId=LUCCA_ID&startsOn=since,AUJOURD_HUI&isConfirmed=true"
```

Affiche :

```
ABSENCES — [Prénom Nom]
========================
  23-27 mars : Congés payés (5 jours)
  14 avril : RTT (1 jour)
  ...

  Prochaine absence : [date] ([dans X jours])
```

Note : l'API ne renvoie pas le type de congé (leaveAccount) sur les leaveperiods avec cette clé. Afficher juste les dates.

## Règles

- Utiliser les accents dans tout le texte affiché
- Si l'API renvoie une erreur, afficher l'erreur et suggérer de vérifier la clé API
- Si aucune absence n'est trouvée, le dire clairement
- La ligne "Absent(e)s aujourd'hui" ne s'affiche que si la semaine cible contient aujourd'hui
