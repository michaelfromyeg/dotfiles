#!/usr/bin/env bash

# Installs the Claude Code marketplaces and plugins declared in
# claude/settings.json, so the same set is present on every machine -- laptop
# and Boxy remote dev containers alike. env.sh calls this after syncing the
# Claude config, and Boxy's init.sh runs `dotfiles env`, so it reaches both.
#
# settings.json is the source of truth: enabledPlugins says which plugins to
# install, extraKnownMarketplaces says which github marketplaces they come
# from. The makenotion-plugins marketplace is sourced from a local notion-next
# checkout whose path differs per machine, so it's detected here rather than
# hardcoded in settings.json -- a missing local path makes Claude error loudly.
#
# Idempotent and cheap: skips marketplaces/plugins already present without
# spawning the claude CLI, so it's safe to run on every `dotfiles env`.

settings="${script_dir:-$(cd "$(dirname "$0")/.." && pwd)}/claude/settings.json"
plugins_dir="$HOME/.claude/plugins"
known="$plugins_dir/known_marketplaces.json"
installed="$plugins_dir/installed_plugins.json"

log() {
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    echo "[claude-plugins] [DRY_RUN] $*"
  else
    echo "[claude-plugins] $*"
  fi
}

run_cmd() {
  log "$*"
  [[ $dry == "1" ]] || [[ $dry == "2" ]] && return 0
  "$@"
}

for tool in claude jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    log "$tool not found; skipping plugin setup"
    exit 0
  fi
done

if [[ ! -f "$settings" ]]; then
  log "no settings.json at $settings; nothing to do"
  exit 0
fi

failures=0

marketplace_known() {
  [ -f "$known" ] && jq -e --arg n "$1" 'has($n)' "$known" >/dev/null 2>&1
}

plugin_installed() {
  [ -f "$installed" ] && jq -e --arg p "$1" '.plugins | has($p)' "$installed" >/dev/null 2>&1
}

add_marketplace() {
  local name="$1" source="$2"
  marketplace_known "$name" && return 0
  if ! run_cmd claude plugin marketplace add "$source"; then
    log "failed to add marketplace: $name ($source)"
    failures=$((failures + 1))
  fi
}

# 1. GitHub-sourced marketplaces declared in settings.json (public, no auth).
while IFS=$'\t' read -r name repo; do
  [[ -z "$name" || -z "$repo" ]] && continue
  add_marketplace "$name" "$repo"
done < <(jq -r '.extraKnownMarketplaces // {} | to_entries[] | select(.value.source.repo) | "\(.key)\t\(.value.source.repo)"' "$settings")

# 2. Notion's marketplace lives inside a notion-next checkout, whose path
#    varies by machine (/work on Boxy, ~/code on the laptop). Register the
#    first one we find; skip silently if there's no checkout here.
for candidate in /work/notion-next "$HOME/code/notion-next"; do
  if [ -f "$candidate/.claude-plugin/marketplace.json" ]; then
    add_marketplace makenotion-plugins "$candidate"
    break
  fi
done

# 3. Install every enabled plugin whose marketplace exists here and that isn't
#    already cached. Skipping plugins from absent marketplaces avoids retrying
#    (and failing) the install on every env sync.
while IFS= read -r plugin; do
  [[ -z "$plugin" ]] && continue
  plugin_installed "$plugin" && continue
  marketplace="${plugin##*@}"
  if ! marketplace_known "$marketplace"; then
    log "skipping $plugin (marketplace '$marketplace' not available on this machine)"
    continue
  fi
  if ! run_cmd claude plugin install "$plugin"; then
    log "failed to install plugin: $plugin"
    failures=$((failures + 1))
  fi
done < <(jq -r '.enabledPlugins // {} | keys[]' "$settings")

if [[ $failures -gt 0 ]]; then
  log "$failures item(s) failed"
  exit 1
fi

log "up to date"
