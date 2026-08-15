# User specific environment
if ! [[ "$PATH" =~ "$HOME/.dotfiles/bin:$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.dotfiles/bin:$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Plugins
source "$HOME/.zsh-plugins.sh"

# Prompt (Completion, History, Autosuggestions, Theme)
source "$HOME/.zsh-prompt.sh"

# Shared environment
source "$HOME/.envrc"

# ---------------------------------------------------------
# Auto-start tmux
# ---------------------------------------------------------
if [[ -z "$TMUX" && $- == *i* ]]; then
	if [[ -n "$SSH_CONNECTION" ]]; then
        exec tmux new-session -A -s ssh
    elif [[ "$TERM_PROGRAM" == "vscode" ]]; then
        exec tmux new-session -A -s code
    elif [[ -n "$KITTY_WINDOW_ID" ]]; then
    	exec tmux new-session -A -s main
    else
        exec tmux new-session -A -s console
    fi
fi
