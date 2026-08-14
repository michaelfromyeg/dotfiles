#!/usr/bin/env zsh

# zsh-specific configuration
# NOTE: I do not use oh-my-zsh! This uses antidote instead. Much faster.

source ~/.shellrc

# History -- zsh ignores the bash HIST* vars in .shellrc, so set its own.
# Without SAVEHIST/HISTFILE, macOS's /etc/zshrc caps persistence at 1000 lines
# and a bare Linux box persists nothing.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY      # Share history across sessions
setopt HIST_IGNORE_SPACE  # Don't record commands starting with a space
setopt HIST_VERIFY        # Expand ! history into the prompt, don't run blind

# Basic zsh settings
setopt AUTO_CD            # Just type directory name to cd
setopt EXTENDED_GLOB      # Use extended globbing
setopt NO_CASE_GLOB       # Case insensitive globbing
setopt NUMERIC_GLOB_SORT  # Sort filenames numerically
setopt EXTENDED_HISTORY   # Write timestamps to history
setopt HIST_IGNORE_DUPS   # Don't store duplicates
setopt HIST_FIND_NO_DUPS  # Ignore duplicates in search
setopt HIST_REDUCE_BLANKS # Remove blank lines

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

# Initialize completions. Must run AFTER antidote so plugin fpath additions
# (zsh-completions) actually register. -C skips the compaudit; do the full
# (slow) rebuild at most once a day.
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh-24) ]]; then
  compinit -C
else
  compinit
fi

# Better completion styles
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # Case insensitive
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}     # Colored completion

# Key bindings (after antidote so history-substring-search widgets exist)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# fzf keybindings: CTRL-R history, CTRL-T files, ALT-C cd
command -v fzf >/dev/null 2>&1 && eval "$(fzf --zsh)"

export NOTION_BOXY_TYPECHECK_SLOTS=3

# Auto-start tmux-dev on boxy remote sessions. Don't gate on $SSH_CONNECTION:
# `notion boxy sshv2` connects via `kubectl exec` and `notion boxy mosh` runs
# under mosh-server, neither of which sets it. $NOTION_BOXY_NAME (on a boxy),
# -z $TMUX (not already in tmux), and -t 0 (interactive tty) are enough.
if [[ -n "$NOTION_BOXY_NAME" && -z "$TMUX" && -t 0 ]]; then
  ~/code/dotfiles/scripts/tmux-dev.sh && reset
fi

# pnpm (macOS install location)
if [[ -d "$HOME/Library/pnpm" ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
  export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"
fi

# rv (ruby version manager)
command -v rv >/dev/null 2>&1 && eval "$(rv shell init zsh)"
