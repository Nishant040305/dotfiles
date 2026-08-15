# ---------------------------------------------------------
# Completion, History & Autosuggestions
# ---------------------------------------------------------

# ----- Completion -----
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|?=**'
zstyle ':completion:*' list-colors ''

# ----- Autosuggestions -----
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#555555'

# ----- History settings -----
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# ---------------------------------------------------------
# Powerlevel10k Theme
# ---------------------------------------------------------

source ~/.powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# ---------------------------------------------------------
# Oh My Posh
# ---------------------------------------------------------

# eval "$(oh-my-posh init zsh --config ~/.prompt.omp.json)"
