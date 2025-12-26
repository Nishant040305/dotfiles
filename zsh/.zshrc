# ---------------------------------------------------------
# Plugins
# ---------------------------------------------------------

# --- Zoxide ---
eval "$(zoxide init zsh)"
alias cd="z"

# --- Eza ---
alias ls="eza --icons --group-directories-first"
alias la="eza -lah --icons --group-directories-first"
alias lt="eza -T --icons --level=3"

# --- Batman ---
export MANPAGER="sh -c 'col -bx | bat --paging=always --language=man'"
export MANROFFOPT="-c"
export LESS='-R --mouse'  # Fix scrollwheel in less/man/bat  

# ----- Autosuggestions -----
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#555555'

# ----- Enhanced completion -----
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|?=**'
zstyle ':completion:*' list-colors ''

# ----- History settings -----
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# ----- Fish-style up/down arrow search -----
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Syntax highlighting (must be last plugin)
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/usr/share/zsh-syntax-highlighting/highlighters

# ---------------------------------------------------------
# Powerlevel10k Theme
# ---------------------------------------------------------
source ~/.powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ---------------------------------------------------------
# Auto-start tmux
# ---------------------------------------------------------
if [[ -z "$TMUX" && -t 1 ]]; then
  exec tmux new-session -A -s main
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
