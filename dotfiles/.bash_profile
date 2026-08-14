#!/usr/bin/env bash

# Read by login shells, including the non-interactive `bash -lc` that
# `notion boxy mosh` uses to launch mosh-server (that path does NOT read
# .bashrc). mosh-server needs a UTF-8 locale at launch or it runs in 8-bit
# mode and mangles powerline / Nerd Font glyphs in the prompt, so set one
# here, before anything else, so mosh-server and the shell it spawns inherit
# it. C.UTF-8 is always available on glibc without locale-gen.
export LANG=C.UTF-8

# Only load the full interactive config for interactive bash; keep the
# mosh-server launcher's startup silent and side-effect-free.
case $- in
*i*) [ -f ~/.bashrc ] && source ~/.bashrc ;;
esac
