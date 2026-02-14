# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Plugins
source "$HOME/.plugins.zsh"

# Prompt (Completion, History, Autosuggestions, Theme)
source "$HOME/.prompt.zsh"

# Custom Aliases
source "$HOME/.aliases.zsh"

# Custom greeting message
source "$HOME/.greeting.zsh"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# OpenClaw Completion
source "/home/Nishant/.openclaw/completions/openclaw.zsh"
