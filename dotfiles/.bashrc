#!/usr/bin/env bash

source ~/.shellrc

# fzf keybindings: CTRL-R history, CTRL-T files, ALT-C cd
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash)"
