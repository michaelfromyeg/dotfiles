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

# Key bindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Load antidote plugin manager
source $(brew --prefix)/opt/antidote/share/antidote/antidote.zsh
antidote load ${ZDOTDIR:-$HOME}/.zsh_plugins.txt

# Added by `notion install`
eval "$(pyenv init - zsh)"
eval "$(direnv hook zsh)"
eval "$('/usr/local/bin/node' -r '/Users/mdemarco/code/notion-next/esbuild-runner.js' '/Users/mdemarco/code/notion-next/src/cli/main/notion.ts' completion --install)"

