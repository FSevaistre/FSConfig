#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

# --all flag : skip interactive prompts, install everything
ALL=false
if [[ "$1" == "--all" ]]; then
  ALL=true
fi

ask() {
  if $ALL; then return 0; fi
  read -rp "$1 [O/n] " answer
  [[ -z "$answer" || "$answer" =~ ^[oOyY]$ ]]
}

echo "=== FSConfig - Installation ==="
if $ALL; then echo "(mode --all : installation complete sans prompts)"; fi
echo ""

# ---------------------------------------------------------
# Fondation : 1Password (installe en premier, tout le reste en depend)
# ---------------------------------------------------------
echo "-- 1Password (fondation) --"
echo ""

if ask "1Password desktop + CLI ?"; then
  if ! command -v 1password &>/dev/null; then
    # Ajouter le repo 1Password
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list
    # Debsig policy pour les mises a jour
    sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/ /usr/share/debsig/keyrings/AC2D62742012EA22/
    curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
    sudo apt update && sudo apt install -y 1password 1password-cli
  else
    echo "-> 1Password deja installe."
  fi
  echo ""
  echo "   IMPORTANT : ouvre 1Password, connecte-toi, puis :"
  echo "   1. Settings > Developer > cocher 'Use the SSH agent'"
  echo "   2. Settings > Developer > cocher 'Integrate with 1Password CLI'"
  echo "   3. Reviens ici pour continuer."
  echo ""
  if ! $ALL; then read -rp "   Appuie sur Entree quand c'est fait..."; fi
fi

# ---------------------------------------------------------
# Logiciels
# ---------------------------------------------------------
echo ""
echo "-- Logiciels --"
echo ""

if ask "Dev essentiels (vim, git, tmux, curl, build-essential, jq, ripgrep, make, htop, p7zip-full, wl-clipboard) ?"; then
  sudo apt update
  sudo apt install -y vim git tmux curl build-essential jq ripgrep make htop p7zip-full wl-clipboard
fi

if ask "Python 3 + pip ?"; then
  sudo apt install -y python3 python3-pip python3-venv
fi

if ask "GitHub CLI (gh, git-crypt) ?"; then
  sudo apt install -y gh git-crypt
  if ! gh auth status &>/dev/null; then
    echo "-> Pense a lancer 'gh auth login' apres l'installation."
  fi
fi

if ask "Ruby (bundler) ?"; then
  sudo apt install -y ruby-bundler
fi

if ask "Node.js (nvm + LTS + yarn) ?"; then
  if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi
  export NVM_DIR="$HOME/.nvm"
  # Charger nvm dans le shell courant (indispensable apres un fresh install)
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  if command -v nvm &>/dev/null; then
    nvm install --lts
    npm install -g yarn
    echo "-> Node $(node -v) + npm $(npm -v) + yarn installes."
  else
    echo "!! ERREUR : nvm n'a pas pu etre charge. Relance un nouveau terminal puis :"
    echo "   nvm install --lts && npm install -g yarn"
  fi
fi

if ask "Rust (rustup) ?"; then
  if ! command -v rustup &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  else
    echo "-> Rust deja installe."
  fi
fi

if ask "Docker ?"; then
  if ! command -v docker &>/dev/null; then
    echo "-> Suis les instructions sur https://docs.docker.com/engine/install/ubuntu/"
    echo "   puis relance ce script pour continuer."
  else
    echo "-> Docker deja installe."
  fi
  # Post-install : ajouter l'utilisateur au groupe docker
  if ! groups | grep -q docker; then
    sudo usermod -aG docker "$USER"
    echo "-> Utilisateur ajoute au groupe docker. Redemarrer la session pour prendre effet."
  fi
fi

if ask "Google Cloud CLI (gcloud, bq, gsutil) ?"; then
  if ! command -v gcloud &>/dev/null; then
    # Methode 1 : snap (la plus simple sur Ubuntu)
    if command -v snap &>/dev/null; then
      sudo snap install google-cloud-cli --classic
    else
      # Methode 2 : apt avec le repo Google
      sudo apt install -y apt-transport-https ca-certificates gnupg
      curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
      sudo apt update && sudo apt install -y google-cloud-cli
    fi
  else
    echo "-> gcloud deja installe."
  fi
fi

if ask "AWS CLI + Session Manager ?"; then
  if ! command -v aws &>/dev/null; then
    sudo snap install aws-cli --classic
  else
    echo "-> AWS CLI deja installe."
  fi
  if ! command -v session-manager-plugin &>/dev/null; then
    echo "-> Session Manager plugin : https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
  else
    echo "-> Session Manager plugin deja installe."
  fi
fi

if ask "Claude Code (CLI) ?"; then
  # Charger nvm si dispo
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  if command -v npm &>/dev/null; then
    npm install -g @anthropic-ai/claude-code
  else
    echo "!! npm non trouve. Installe d'abord Node.js (section precedente) puis :"
    echo "   npm install -g @anthropic-ai/claude-code"
  fi
fi

if ask "Firefox ?"; then
  sudo snap install firefox 2>/dev/null || echo "-> Firefox deja installe ou snap non dispo."
fi

if ask "Chrome ?"; then
  if ! command -v google-chrome &>/dev/null; then
    wget -O /tmp/google-chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    sudo dpkg -i /tmp/google-chrome.deb || sudo apt install -f -y
    rm -f /tmp/google-chrome.deb
  else
    echo "-> Chrome deja installe."
  fi
fi

if ask "Slack ?"; then
  if ! command -v slack &>/dev/null; then
    # Telecharger le .deb depuis le CDN Slack (URL directe stable)
    SLACK_URL="https://downloads.slack-edge.com/desktop-releases/linux/x64/4.41.105/slack-desktop-4.41.105-amd64.deb"
    wget -O /tmp/slack.deb "$SLACK_URL" 2>/dev/null
    if [ -f /tmp/slack.deb ] && [ -s /tmp/slack.deb ]; then
      sudo dpkg -i /tmp/slack.deb || sudo apt install -f -y
      rm -f /tmp/slack.deb
    else
      echo "-> Le lien Slack est peut-etre obsolete. Alternatives :"
      echo "   - Telecharger depuis https://slack.com/intl/fr-fr/downloads/linux"
      echo "   - sudo snap install slack (perd parfois la session au reboot)"
    fi
  else
    echo "-> Slack deja installe."
  fi
fi

if ask "Spotify ?"; then
  sudo snap install spotify 2>/dev/null || echo "-> Spotify deja installe."
fi

# ---------------------------------------------------------
# Fichiers de config
# ---------------------------------------------------------
echo ""
echo "-- Fichiers de config --"
echo ""

if ask "Vim (vimrc + colorscheme + plugins) ?"; then
  cp "$DIR/vim/vimrc" ~/.vimrc
  mkdir -p ~/.vim/colors
  cp "$DIR/vim/colors/mustang.vim" ~/.vim/colors/
  if [ ! -f ~/.vim/autoload/plug.vim ]; then
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi
  vim --not-a-term +PlugInstall +qall
  echo "-> Vim installe."
fi

if ask "Tmux (config + TPM) ?"; then
  cp "$DIR/tmux/tmux.conf" ~/.tmux.conf
  if [ ! -d ~/.tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  fi
  echo "-> Tmux installe. Lance tmux puis prefix + I pour installer les plugins."
fi

if ask "Git (gitconfig) ?"; then
  cp "$DIR/git/gitconfig" ~/.gitconfig
  echo "-> Pense a mettre a jour ton email/nom si besoin dans ~/.gitconfig"
fi

if ask "Shell (bashrc + profile) ?"; then
  cp "$DIR/shell/bashrc" ~/.bashrc
  cp "$DIR/shell/profile" ~/.profile
  echo "-> Shell installe. Lance 'source ~/.bashrc' ou ouvre un nouveau terminal."
fi

if ask "Claude Code (settings + commands + skills + scripts) ?"; then
  mkdir -p ~/.claude
  cp "$DIR/claude/settings.json" ~/.claude/settings.json
  # Commands
  if [ -d "$DIR/claude/commands" ]; then
    mkdir -p ~/.claude/commands
    cp "$DIR/claude/commands/"*.md ~/.claude/commands/
  fi
  # Skills
  if [ -d "$DIR/claude/skills" ]; then
    cp -r "$DIR/claude/skills/" ~/.claude/skills/
  fi
  # Scripts (gdrive-dl, etc.)
  if [ -d "$DIR/scripts" ]; then
    mkdir -p ~/.local/bin
    cp "$DIR/scripts/"* ~/.local/bin/
    chmod +x ~/.local/bin/*
  fi
  # Python dependencies (gdrive-dl, whisper)
  if [ -f "$DIR/requirements.txt" ]; then
    pip3 install --user -r "$DIR/requirements.txt" 2>/dev/null || \
      pip3 install --break-system-packages -r "$DIR/requirements.txt" 2>/dev/null || \
      echo "-> ATTENTION : pip install a echoue. Installe manuellement : pip3 install -r $DIR/requirements.txt"
  fi
  echo "-> Claude Code configure (settings + commands + skills + scripts)."
  echo ""
  echo "   SECRETS A CONFIGURER MANUELLEMENT :"
  echo "   1. Cle API Lucca :  echo 'VOTRE_CLE' > ~/.claude/.lucca-key && chmod 600 ~/.claude/.lucca-key"
  echo "   2. team.json :      cp votre-team.json ~/.claude/team.json"
  echo "   3. gdrive-dl OAuth : lancer 'gdrive-dl search test' une premiere fois pour autoriser"
fi

if ask "Clavier (Caps Lock -> Escape) ?"; then
  bash "$DIR/keyboard/setup.sh"
fi

if ask "GNOME (extensions + focus fix) ?"; then
  gsettings set org.gnome.desktop.wm.preferences focus-new-windows 'strict'
  sudo apt install -y gnome-shell-extension-manager
  echo "-> Focus strict active."
  echo "-> Ouvre Extension Manager et installe les extensions suivantes :"
  echo "   - noannoyance (corrige le 'is ready' sur Slack et apps Electron)"
  echo "   - Caffeine (empeche la mise en veille)"
  echo "   - Vitals (CPU/RAM/temp dans la barre)"
  echo "   - Clipboard Indicator (historique presse-papier)"
fi

if ask "SSH (1Password agent ou cle locale) ?"; then
  mkdir -p ~/.ssh
  if command -v op &>/dev/null && [ -S "$HOME/.1password/agent.sock" ]; then
    # 1Password SSH agent detecte : l'utiliser
    if [ ! -f ~/.ssh/config ] || ! grep -q "1password" ~/.ssh/config 2>/dev/null; then
      cat >> ~/.ssh/config <<'SSHEOF'

# 1Password SSH agent
Host *
  IdentityAgent ~/.1password/agent.sock
SSHEOF
      chmod 600 ~/.ssh/config
    fi
    echo "-> SSH configure avec l'agent 1Password."
    echo "   Les cles SSH stockees dans 1Password sont automatiquement disponibles."
  else
    # Pas de 1Password agent : generer une cle locale
    if [ ! -f ~/.ssh/id_ed25519 ]; then
      ssh-keygen -t ed25519 -C "$USER@$(hostname)" -f ~/.ssh/id_ed25519 -N ""
      echo "-> Cle SSH generee. Ajoute-la sur GitHub :"
      echo "   gh ssh-key add ~/.ssh/id_ed25519.pub"
    else
      echo "-> Cle SSH deja presente."
    fi
  fi
fi

if ask "Secrets depuis 1Password (Lucca, team.json) ?"; then
  if command -v op &>/dev/null; then
    # Cle API Lucca
    if [ ! -f ~/.claude/.lucca-key ]; then
      LUCCA_KEY=$(op item get "Ilucca" --fields password 2>/dev/null || true)
      if [ -n "$LUCCA_KEY" ]; then
        echo "$LUCCA_KEY" > ~/.claude/.lucca-key
        chmod 600 ~/.claude/.lucca-key
        echo "-> Cle Lucca recuperee depuis 1Password."
      else
        echo "-> Item 'Ilucca' non trouve dans 1Password. Configurer manuellement :"
        echo "   echo 'VOTRE_CLE' > ~/.claude/.lucca-key && chmod 600 ~/.claude/.lucca-key"
      fi
    else
      echo "-> Cle Lucca deja presente."
    fi
    # team.json (copie depuis la machine courante si dispo, sinon rappel)
    if [ ! -f ~/.claude/team.json ]; then
      echo "-> team.json manquant. Copier depuis une autre machine :"
      echo "   scp ancienne-machine:~/.claude/team.json ~/.claude/team.json"
    else
      echo "-> team.json deja present."
    fi
  else
    echo "-> 1Password CLI non disponible. Configurer les secrets manuellement."
  fi
fi

# ---------------------------------------------------------
# Post-install : checklist authentification
# ---------------------------------------------------------
echo ""
echo "=== Installation terminee ==="
echo ""
echo "CHECKLIST POST-INSTALL :"
echo "========================"
echo ""
if command -v op &>/dev/null && [ -S "$HOME/.1password/agent.sock" ]; then
  echo "  [x] 1Password + SSH agent                      (deja configure)"
else
  echo "  [ ] 1Password : activer SSH agent + CLI integration"
fi
if [ -f ~/.claude/.lucca-key ]; then
  echo "  [x] Cle Lucca                                  (deja presente)"
else
  echo "  [ ] Cle Lucca : echo 'CLE' > ~/.claude/.lucca-key"
fi
if [ -f ~/.claude/team.json ]; then
  echo "  [x] team.json                                  (deja present)"
else
  echo "  [ ] team.json : scp ancienne-machine:~/.claude/team.json ~/.claude/"
fi
echo "  [ ] gh auth login                              (GitHub CLI)"
echo "  [ ] gcloud auth login                          (Google Cloud)"
echo "  [ ] gcloud config set project <GCP_PROJECT>    (BigQuery, etc.)"
echo "  [ ] aws configure sso                          (AWS SSO)"
echo "  [ ] gdrive-dl search test                       (OAuth Google Drive)"
echo "  [ ] claude                                      (Premier lancement Claude Code)"
echo ""
echo "Pour tout installer d'un coup sans prompts : $0 --all"
