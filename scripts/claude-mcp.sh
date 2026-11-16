#!/usr/bin/env bash

# Registers the user-scoped Claude Code MCP servers declared in
# claude/mcp-servers.json. User-scoped servers live in ~/.claude.json, which
# Claude Code also uses for its own mutable state, so it can't be copied over
# like settings.json; `claude mcp add-json --scope user` edits it in place.
#
# Additive only: servers already in ~/.claude.json are skipped (not updated),
# and servers removed from mcp-servers.json are left registered. To change a
# server's config, `claude mcp remove --scope user <name>` and rerun.

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

servers="${script_dir:-$(cd "$(dirname "$0")/.." && pwd)}/claude/mcp-servers.json"
claude_json="$HOME/.claude.json"

for tool in claude jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    log "$tool not found; skipping MCP setup"
    exit 0
  fi
done

server_registered() {
  [ -f "$claude_json" ] && jq -e --arg n "$1" '.mcpServers // {} | has($n)' "$claude_json" >/dev/null 2>&1
}

failures=0

while IFS=$'\t' read -r name config; do
  [[ -z "$name" ]] && continue
  server_registered "$name" && continue
  if ! run_cmd claude mcp add-json --scope user "$name" "$config"; then
    log "failed to add MCP server: $name"
    failures=$((failures + 1))
  fi
done < <(jq -r 'to_entries[] | "\(.key)\t\(.value | tojson)"' "$servers")

if [[ $failures -gt 0 ]]; then
  log "$failures server(s) failed"
  exit 1
fi

log "up to date"
