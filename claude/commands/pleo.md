---
description: Récupère les reçus manquants sur Pleo depuis Gmail et les portails fournisseurs, puis les uploade
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, mcp__claude_ai_Gmail__gmail_search_messages, mcp__claude_ai_Gmail__gmail_read_message, mcp__claude_ai_Gmail__gmail_read_thread, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer, mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__find, mcp__claude-in-chrome__get_page_text
---

Tu es un assistant comptable qui automatise la récupération et l'upload de reçus manquants sur Pleo.

## Workflow

### 1. Ouvrir Pleo et lister les dépenses sans reçu

- Ouvre https://app.pleo.io/expenses dans Chrome (via tabs_create_mcp + navigate)
- Filtre par "Reçu manquant" (bouton Reçu > Manquant > Appliquer)
- Lis la liste des dépenses : pour chaque dépense, note le fournisseur, le montant, la date

### 2. Chercher les reçus dans Gmail

Pour chaque fournisseur, cherche dans Gmail avec gmail_search_messages :
- `from:<fournisseur> subject:(invoice OR receipt OR billing) after:<date-7j>`
- Lis les emails trouvés avec gmail_read_message pour extraire les liens de téléchargement Stripe ou identifier les pièces jointes

### 3. Mapping fournisseurs connus

Voici les sources de factures pour les fournisseurs habituels de Pretto :

| Fournisseur | Source reçu | Méthode |
|---|---|---|
| Anthropic (Claude Team) | Email (Stripe) | Extraire le lien `pay.stripe.com/invoice/.../pdf` du body de l'email |
| Anthropic (API) | Console billing | Ouvrir https://platform.claude.com/settings/billing, cliquer "View" sur chaque facture, convertir l'URL `invoice.stripe.com/i/...` en `pay.stripe.com/invoice/.../pdf` |
| GitHub | Email (pièce jointe) | Ouvrir l'email dans Gmail Chrome, hover sur la PJ, cliquer le bouton download |
| Expo | Email (Stripe) | Lien `pay.stripe.com` dans le body |
| Retool | Email (Stripe) | Lien `pay.stripe.com` dans le body |
| Cloudinary | Email (pièce jointe) | Télécharger depuis Gmail Chrome |
| New Relic | Email (pièce jointe) | Télécharger depuis Gmail Chrome |
| Microsoft/Azure | Portail Azure | Ouvrir https://portal.azure.com > Facturation > Historique des paiements, cliquer l'icône download |
| ConvertAPI | Email (Paddle) + headless Chrome | Chercher dans Gmail `from:convertapi subject:receipt`. Extraire le lien `my.paddle.com/receipt/...` du body. Générer le PDF via headless Chrome : `google-chrome --headless --disable-gpu --no-sandbox --print-to-pdf=/tmp/<nom>.pdf "<url_paddle>"` (le site Paddle est bloqué par l'extension Chrome, mais headless Chrome y accède sans problème) |
| OpenAI/ChatGPT | Email (Stripe) | Chercher dans Gmail `from:openai receipt`. Interface ChatGPT ne propose pas de billing history |
| Algolia | Email (pièce jointe) | Chercher dans Gmail `from:algolia subject:invoice`. Télécharger la PJ depuis Gmail Chrome (hover sur la PJ, cliquer download) |
| Twilio | Console billing (receipt PDF) | Naviguer vers `https://console.twilio.com/us1/billing/manage-billing/billing-overview?frameUrl=%2Fconsole%2Fbilling%2Fapi%2Freceipt%3Fm%3D<MM>%26y%3D<YYYY>%26x-target-region%3Dus1` (remplacer MM et YYYY par le mois/annee). IMPORTANT : switcher sur le sous-compte "oleen-mortgagors-login-verify" dans le dropdown en haut de page. Le lien telecharge directement un PDF |

### 4. Télécharger et convertir les PDFs

Pour les factures avec lien Stripe :
```bash
curl -sL -o /tmp/<nom>.pdf "<url_stripe>/pdf?s=em"
pdftoppm -png -r 200 -singlefile /tmp/<nom>.pdf /tmp/<nom>
```

Pour les pièces jointes Gmail : ouvrir l'email dans Chrome, scroller jusqu'à la PJ, hover pour faire apparaître le bouton download, cliquer, puis :
```bash
pdftoppm -png -r 200 -singlefile ~/Downloads/<fichier>.pdf /tmp/<nom>
```

Pour les factures Paddle (ConvertAPI, etc.) dont le site est bloqué par l'extension Chrome, utiliser headless Chrome pour générer un PDF depuis l'URL du receipt :
```bash
google-chrome --headless --disable-gpu --no-sandbox --print-to-pdf=/tmp/<nom>.pdf "<url_paddle_receipt>"
pdftoppm -png -r 200 -singlefile /tmp/<nom>.pdf /tmp/<nom>
```

### 5. Démarrer un serveur HTTP CORS local

```bash
cat > /tmp/cors_server.py << 'PYEOF'
from http.server import HTTPServer, SimpleHTTPRequestHandler
import os
os.chdir('/tmp')
class CORSHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET')
        super().end_headers()
    def log_message(self, format, *args):
        pass
HTTPServer(('', 8765), CORSHandler).serve_forever()
PYEOF
python3 /tmp/cors_server.py &
```

### 6. Uploader les reçus sur Pleo

Pour chaque dépense avec un reçu disponible :
1. Cliquer sur la dépense dans la liste Pleo
2. Injecter le fichier PNG via JavaScript :

```javascript
(async () => {
  const response = await fetch('http://localhost:8765/<fichier>.png');
  const blob = await response.blob();
  const file = new File([blob], '<nom_facture>.png', { type: 'image/png' });
  const dt = new DataTransfer();
  dt.items.add(file);
  const fi = document.querySelector('input[type="file"]');
  if (!fi) return 'No file input found';
  fi.files = dt.files;
  fi.dispatchEvent(new Event('change', { bubbles: true }));
  return 'OK: ' + file.name;
})()
```

3. Vérifier que la dépense disparaît de la liste filtrée (= reçu accepté)
4. Passer à la suivante

### 7. Nettoyage

- Arrêter le serveur HTTP : `kill $(lsof -ti:8765) 2>/dev/null`
- Afficher un bilan final : nombre de reçus uploadés, dépenses restantes sans reçu et pourquoi

## Règles importantes

- Matcher les reçus par montant ET date pour éviter les erreurs
- Les factures Anthropic Team et Anthropic API sont sur des comptes différents (Team = email Stripe, API = console billing)
- Pour les URLs Stripe `invoice.stripe.com/i/acct_xxx/live_xxx?s=ap`, convertir en `pay.stripe.com/invoice/acct_xxx/live_xxx/pdf?s=ap` pour télécharger le PDF
- L'extension Chrome peut se déconnecter : si un screenshot échoue, retenter avec tabs_context_mcp puis réessayer
- Ne jamais utiliser le forward Pleo (forward@fetch.pleo.io) -- ça ne marche pas
- Toujours vérifier le fichier téléchargé avec `file <path>` pour s'assurer que c'est bien un PDF avant de convertir
- Ne pas chercher les factures Microsoft de moins de 8 € (les petits prélèvements Microsoft type Copilot/M365 n'ont pas de reçu facilement récupérable). Les lister dans le bilan final comme "ignoré".
