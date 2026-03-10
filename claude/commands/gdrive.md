---
description: Télécharge un fichier depuis Google Drive à partir d'un lien ou ID
allowed-tools: Bash, Read
---

L'utilisateur veut télécharger un fichier Google Drive. L'argument fourni est: $ARGUMENTS

Utilise le script `~/.local/bin/gdrive-dl` pour télécharger le fichier.

Étapes :
1. Extrais l'URL ou l'ID du fichier depuis les arguments
2. Lance `~/.local/bin/gdrive-dl "<url_ou_id>"` avec Bash
3. Si l'utilisateur a précisé un chemin de sortie, ajoute `-o <chemin>`
4. Si le script demande une configuration (credentials manquants), affiche les instructions à l'utilisateur
5. Si le script ouvre un navigateur pour l'authentification, informe l'utilisateur qu'il doit autoriser l'accès dans le navigateur
6. Confirme le téléchargement une fois terminé

Le token est conservé dans ~/.config/gdrive-dl/token.json et sera réutilisé automatiquement.
