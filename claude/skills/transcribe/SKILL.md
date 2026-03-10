---
name: transcribe
description: Transcris le dernier vocal .ogg téléchargé avec whisper et fais un résumé
---

Transcris le dernier vocal téléchargé et fais-en un résumé.

Étapes :

1. Trouve le fichier .ogg le plus récent dans ~/Downloads avec `ls -t ~/Downloads/*.ogg | head -1`
2. Affiche le nom du fichier trouvé à l'utilisateur
3. Transcris-le avec whisper en exécutant : `whisper "<chemin_du_fichier>" --language fr --model turbo --output_format txt --output_dir /tmp/whisper_out`
4. Lis le fichier .txt généré dans /tmp/whisper_out/
5. Affiche la transcription complète à l'utilisateur
6. Fais un résumé concis du contenu en français, en dégageant les points clés et les éventuelles actions à mener
