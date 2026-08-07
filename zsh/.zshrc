# User specific environment
if ! [[ "$PATH" =~ "$HOME/.dotfiles/bin:$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.dotfiles/bin:$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Plugins
source "$HOME/.plugins.zsh"

# Prompt (Completion, History, Autosuggestions, Theme)
source "$HOME/.prompt.zsh"

# Custom Aliases
source "$HOME/.aliases.zsh"

# KDE Connect hotspot firewall
source "$HOME/.dotfiles/kdeconnect/kdeconnect.zsh"

# Custom greeting message
source "$HOME/.greeting.zsh"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH=$PATH:/snap/bin
export PATH=$PATH:/usr/local/go/bin


# Added by Antigravity CLI installer
export PATH="/home/Nishant/.local/bin:$PATH"

# Shared environment & modular aliases
if [ -f "$HOME/.envrc" ]; then
    source "$HOME/.envrc"
elif [ -f "$HOME/.dotfiles/shell/.envrc" ]; then
    source "$HOME/.dotfiles/shell/.envrc"
fi

# Auto-start tmux for interactive terminal sessions (hiding status bar via .tmux.conf)
if [[ -z "$TMUX" && -n "$PS1" && "$TERM_PROGRAM" != "vscode" && -z "$VSCODE_INJECTION" ]]; then
    exec tmux
fi


