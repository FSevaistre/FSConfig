#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

ask() {
  read -rp "$1 [O/n] " answer
  [[ -z "$answer" || "$answer" =~ ^[oOyY]$ ]]
}

echo "=== FSConfig - Installation ==="
echo ""

# ---------------------------------------------------------
# Logiciels
# ---------------------------------------------------------
echo "-- Logiciels --"
echo ""

if ask "Dev essentiels (vim, git, tmux, curl, build-essential, jq, ripgrep, make, htop, p7zip-full, wl-clipboard) ?"; then
  sudo apt update
  sudo apt install -y vim git tmux curl build-essential jq ripgrep make htop p7zip-full wl-clipboard
fi

if ask "GitHub CLI (gh, git-crypt) ?"; then
  sudo apt install -y gh git-crypt
  echo "-> Pense a lancer 'gh auth login' apres l'installation."
fi

if ask "Ruby (bundler) ?"; then
  sudo apt install -y ruby-bundler
fi

if ask "Node.js (nvm + LTS + yarn) ?"; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install --lts
  npm install -g yarn
fi

if ask "Rust (rustup) ?"; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi

if ask "Docker ?"; then
  echo "-> Suis les instructions sur https://docs.docker.com/engine/install/ubuntu/"
  echo "   puis relance ce script pour continuer."
fi

if ask "Google Cloud CLI ?"; then
  sudo apt install -y google-cloud-cli
fi

if ask "AWS CLI ?"; then
  sudo snap install aws-cli --classic
fi

if ask "Claude Code (CLI) ?"; then
  npm install -g @anthropic-ai/claude-code
fi

if ask "Firefox ?"; then
  sudo snap install firefox
fi

if ask "Chrome ?"; then
  echo "-> Telecharge depuis https://www.google.com/chrome/"
fi

if ask "1Password + CLI ?"; then
  echo "-> Suis les instructions sur https://1password.com/downloads/linux"
fi

if ask "Slack ?"; then
  wget -O /tmp/slack.deb "https://slack.com/downloads/instructions/linux?ddl=1&build=deb"
  sudo dpkg -i /tmp/slack.deb
  rm /tmp/slack.deb
fi

if ask "Spotify ?"; then
  sudo snap install spotify
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
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
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

if ask "Claude Code (settings + skills) ?"; then
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
  echo "-> Claude Code configure (settings + skills)."
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

echo ""
echo "=== Installation terminee ==="
