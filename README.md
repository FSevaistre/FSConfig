# FSConfig

Configuration de ma machine de dev.

## Disclaimer

Ce repo est optimise pour mon workflow chez Pretto. Les commandes Claude Code (`/1to1`, `/1to1-wrap-up`, `/gather`, `/morning-coffee`, `/lucca`, `/fix-sentry`, `/pr`) s'appuient sur les outils internes Pretto : Slack, Notion, Gmail, GitHub (org finspot), Google Calendar, Google Drive, Sentry, Lucca (absences), et le Board Produit-Tech Notion.

Si tu forks ce repo, voici ce qu'il faut adapter :

- `claude/team.json` -- arborescence de l'equipe (noms, Slack IDs, emails, GitHub handles, Notion user IDs, pages 1:1). A mettre a jour quand quelqu'un arrive, part, ou change d'equipe.
- `claude/commands/1to1.md` -- references aux canaux Slack, au board Notion, au repo GitHub. A adapter a ton org.
- `claude/commands/1to1-wrap-up.md` -- meme dependances que 1to1 + Google Calendar et Drive pour les transcripts.
- `claude/commands/gather.md` -- canaux Slack par priorite, ID Slack de l'utilisateur, logique de tri des emails. Tres specifique a mon role de CTO chez Pretto.
- `claude/commands/morning-coffee.md` -- agregat de /1to1, /gather, /lucca, Google Calendar et Board Notion.
- `claude/commands/lucca.md` -- appel API Lucca (absences). Necessite une cle API dans `~/.claude/.lucca-key` (voir setup ci-dessous). Adapter l'URL de l'instance Lucca.
- `claude/skills/pr/SKILL.md` -- commandes de test et lint specifiques au monorepo Pretto (make rspec, rubocop, etc.).

Les fichiers generiques (vim, tmux, git, shell, keyboard) fonctionnent tels quels sur n'importe quelle machine Ubuntu/Debian.

## Quick start

```bash
sudo apt install -y git gh && gh auth login && git clone https://github.com/FSevaistre/FSConfig.git ~/FSConfig && ~/FSConfig/install.sh
```

## Structure

```
FSConfig/
├── vim/
│   ├── vimrc              # Config Vim
│   └── colors/mustang.vim # Colorscheme
├── tmux/
│   └── tmux.conf          # Config tmux
├── git/
│   └── gitconfig          # Config Git
├── shell/
│   ├── bashrc             # Config Bash
│   └── profile            # Variables d'environnement
├── claude/
│   ├── settings.json      # Preferences Claude Code
│   ├── team.json           # Arborescence equipe (IDs Slack, Notion, GitHub, emails)
│   ├── commands/           # Slash commands custom (/1to1, /1to1-wrap-up, /gather, /morning-coffee, /lucca, /gdrive, /pleo, /fix-sentry)
│   └── skills/             # Skills auto-detectes (/pr, /transcribe)
├── keyboard/
│   └── setup.sh           # Caps Lock -> Escape
├── claudeignore            # Template .claudeignore pour les projets
└── README.md
```

## Installer la config sur une nouvelle machine

### 1. Logiciels

Installer ce dont on a besoin parmi les catégories suivantes :

**Dev essentiels :**
```bash
sudo apt install -y vim git tmux curl build-essential jq ripgrep make htop p7zip-full wl-clipboard
```

**Node.js (via nvm) :**
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install --lts
npm install -g yarn
```

**Rust :**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

**Docker :**
```bash
# Suivre https://docs.docker.com/engine/install/ubuntu/
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

**Cloud :**
```bash
# Google Cloud CLI : https://cloud.google.com/sdk/docs/install
sudo apt install -y google-cloud-cli

# AWS CLI
sudo snap install aws-cli --classic

# AWS Session Manager
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
```

**GitHub :**
```bash
sudo apt install -y gh git-crypt
gh auth login
```

**Ruby :**
```bash
sudo apt install -y ruby-bundler
```

**Claude Code (CLI) :**
```bash
npm install -g @anthropic-ai/claude-code
```

**Navigateurs :**
```bash
# Firefox (snap, souvent pre-installe sur Ubuntu)
sudo snap install firefox

# Chrome : https://www.google.com/chrome/
```

**Apps desktop :**
```bash
# 1Password : https://1password.com/downloads/linux
sudo apt install -y 1password 1password-cli

# Slack (deb, pas snap — le snap perd la session au reboot)
wget -O /tmp/slack.deb "https://slack.com/downloads/instructions/linux?ddl=1&build=deb"
sudo dpkg -i /tmp/slack.deb

# Spotify
sudo snap install spotify
```

### 2. Fichiers de config

```bash
# Vim
cp FSConfig/vim/vimrc ~/.vimrc
mkdir -p ~/.vim/colors
cp FSConfig/vim/colors/mustang.vim ~/.vim/colors/

# vim-plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim +PlugInstall +qall

# Tmux
cp FSConfig/tmux/tmux.conf ~/.tmux.conf
# Installer TPM
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Puis dans tmux : prefix + I pour installer les plugins

# Git
cp FSConfig/git/gitconfig ~/.gitconfig

# Shell
cp FSConfig/shell/bashrc ~/.bashrc
cp FSConfig/shell/profile ~/.profile
source ~/.bashrc

# Claude Code
mkdir -p ~/.claude
cp FSConfig/claude/settings.json ~/.claude/settings.json
cp -r FSConfig/claude/commands ~/.claude/
cp -r FSConfig/claude/skills ~/.claude/
# Template .claudeignore (a copier a la racine de chaque projet)
# cp ~/FSConfig/claudeignore mon-projet/.claudeignore

# Clavier (Caps Lock -> Escape)
bash FSConfig/keyboard/setup.sh
```

## Commands et skills Claude Code

### Liste des commandes disponibles

`/1to1 <prenom>` -- Prepare un 1:1 avec un managee. Verifie d'abord que le 1:1 precedent a ete documente (sinon telecharge le transcript et remplit la page Notion). Puis collecte en parallele : page 1:1 Notion, Slack (messages de la semaine), Gmail, cartes du Board Produit-Tech, PRs GitHub. Si le managee est manager, fait la meme chose pour chaque membre de son equipe et produit un briefing complet avec points d'attention et sujets a aborder. Publie dans Notion. Utilise `team.json` pour les IDs.

`/1to1-wrap-up [prenom]` -- Wrap-up d'un 1:1 recent. Cherche le 1:1 le plus recent dans l'agenda (dernières 4h ou journee), telecharge le transcript Gemini, extrait les infos par section du template et met a jour la page Notion. Ne touche pas aux sections deja remplies. Si l'entree du jour n'existe pas, la cree avec le bon template.

`/gather [date]` -- Rassemble tout ce qui s'est passe depuis une date (defaut : reprend depuis le dernier gather). Parcourt le calendrier Google + transcripts Gemini, Notion (1:1, pages recentes), Slack (canaux par priorite), Gmail (tri auto notifications vs emails importants), GitHub (PRs mergees + PRs en attente de review), Board Produit-Tech, radar business (canaux hors perimetre direct). Produit un resume strategique structure et le publie dans Notion.

`/morning-coffee` -- Briefing du matin. Agregat de l'agenda du jour, absences Lucca (/lucca), detection et preparation des 1:1, /gather depuis le dernier gather, plan d'action Notion. Calcule le temps libre et suggere comment l'utiliser.

`/lucca [personne] [date]` -- Consulte les absences sur Lucca. Sans argument : absences de l'equipe pour la semaine en cours. Avec un prenom : absences de cette personne. Avec une date ou "semaine prochaine" : absences de la semaine cible. La cle API Lucca est lue depuis `~/.claude/.lucca-key` (non versionne). Les `lucca_id` sont dans `team.json`.

`/gdrive <url_ou_id>` -- Telecharge un fichier depuis Google Drive via le script `~/.local/bin/gdrive-dl`.

`/pleo` -- Recupere les recus manquants sur Pleo depuis Gmail et les portails fournisseurs, puis les uploade.

`/fix-sentry [options]` -- Recupere les top erreurs Sentry non assignees sur les projets backend (finspot-api, pretto-api, oleen-backend), analyse les stacktraces, classe chaque issue (code-fix, infra, noise), et cree une PR draft par fix avec le lien Sentry dans la description. Par defaut : 10 erreurs, 24h. Accepte des arguments pour personnaliser (ex: `/fix-sentry 5 erreurs sur pretto-api 48h`).

### Liste des skills (detection automatique)

`/pr` -- Cree une PR. Lance les tests et le linter, corrige les erreurs, cree une branche, commit, push, ouvre la PR sur GitHub, et poste le lien dans Slack.

`/transcribe` -- Transcrit le dernier fichier .ogg telecharge (vocal) avec whisper et en fait un resume en francais.

### Fichiers de config

`team.json` -- Arborescence de l'equipe tech avec pour chaque personne : nom, Slack ID, email, GitHub handle, Notion user ID, Lucca ID, page 1:1 Notion. Utilise par `/1to1`, `/lucca` et potentiellement d'autres commandes.

### Comment creer des commands et skills

#### Commands (simples)

Fichier markdown dans `~/.claude/commands/`. Le nom du fichier = le nom de la commande.

Creer un fichier `~/.claude/commands/ma-commande.md` :

```markdown
---
description: Description courte affichee dans la liste des commandes
allowed-tools: Bash, Read
---

Instructions pour Claude quand la commande est appelee.
$ARGUMENTS contient les arguments passes par l'utilisateur.
```

Utilisation : `/ma-commande mon argument`

#### Skills (avec detection auto)

Fichier `SKILL.md` dans un sous-dossier de `~/.claude/skills/`. Claude les declenche automatiquement quand le contexte correspond.

Creer `~/.claude/skills/mon-skill/SKILL.md` :

```markdown
---
name: mon-skill
description: Description utilisee pour decider quand declencher le skill
---

Instructions pour Claude.
```

#### Versionner dans FSConfig

Apres avoir cree ou modifie un skill/command sur la machine :

```bash
# Command
cp ~/.claude/commands/ma-commande.md ~/FSConfig/claude/commands/

# Skill
cp -r ~/.claude/skills/mon-skill ~/FSConfig/claude/skills/
```

## Mettre a jour FSConfig apres un changement

Quand on modifie une config sur la machine, copier le fichier modifie dans FSConfig :

```bash
# Exemples :
cp ~/.vimrc ~/FSConfig/vim/vimrc
cp ~/.tmux.conf ~/FSConfig/tmux/tmux.conf
cp ~/.gitconfig ~/FSConfig/git/gitconfig
cp ~/.bashrc ~/FSConfig/shell/bashrc
```

Pour ajouter un nouveau logiciel a la liste, l'ajouter dans la section correspondante de ce README.

**Cle API Lucca (pour /lucca et /morning-coffee) :**
```bash
# Generer une cle API depuis l'admin Lucca (https://your-company.ilucca.net/identity/api-keys)
# Puis la stocker localement :
echo "votre-cle-api" > ~/.claude/.lucca-key
chmod 600 ~/.claude/.lucca-key
```

**Attention :** ne jamais versionner :
- `~/.claude/config.json` (contient la cle API)
- `~/.claude/settings.local.json` (contient des permissions avec URLs signees et emails)
- `~/.claude/.lucca-key` (contient la cle API Lucca)

Verifier qu'aucun fichier ne contient de credentials avant de commit.
