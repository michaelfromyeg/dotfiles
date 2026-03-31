#!/usr/bin/env zsh

# zsh-specific configuration
# NOTE: I do not use oh-my-zsh! This uses antidote instead. Much faster.

source ~/.shellrc

# Basic zsh settings
setopt AUTO_CD              # Just type directory name to cd
setopt EXTENDED_GLOB        # Use extended globbing
setopt NO_CASE_GLOB        # Case insensitive globbing
setopt NUMERIC_GLOB_SORT   # Sort filenames numerically
setopt EXTENDED_HISTORY    # Write timestamps to history
setopt HIST_IGNORE_DUPS    # Don't store duplicates
setopt HIST_FIND_NO_DUPS   # Ignore duplicates in search
setopt HIST_REDUCE_BLANKS  # Remove blank lines

# Initialize completions
autoload -Uz compinit
compinit

# Better completion styles
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # Case insensitive
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}     # Colored completion

# Load antidote plugin manager
_antidote_dir=""
if type brew &>/dev/null; then
  _antidote_dir="$(brew --prefix)/opt/antidote/share/antidote"
elif [[ -d /usr/local/share/antidote ]]; then
  _antidote_dir="/usr/local/share/antidote"
fi
if [[ -n "$_antidote_dir" ]] && [[ -f "$_antidote_dir/antidote.zsh" ]]; then
  source "$_antidote_dir/antidote.zsh"
  antidote load ${ZDOTDIR:-$HOME}/.zsh_plugins.txt
fi
unset _antidote_dir

# Key bindings (after antidote so history-substring-search widgets exist)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Auto-start tmux-dev on boxy SSH sessions
if [[ -n "$NOTION_BOXY_NAME" && -z "$TMUX" && -n "$SSH_CONNECTION" ]]; then
  ~/code/dotfiles/scripts/tmux-dev.sh && reset
fi

# Added by `notion install` (guarded for portability)
command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init - zsh)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

