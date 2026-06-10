#!/usr/bin/env python3
"""Sync MCP servers into Claude Desktop's config.

Reads the MCP server template from claude/desktop-mcp-servers.json,
resolves placeholders using beeminder-utils/.env, and merges into
Claude Desktop's claude_desktop_config.json.

Works on both macOS and WSL (writing to the Windows filesystem).
"""

from __future__ import annotations

import json
import os
import platform
import subprocess
import sys
from pathlib import Path

DOTFILES_DIR = Path(__file__).resolve().parent.parent
TEMPLATE = DOTFILES_DIR / "claude" / "desktop-mcp-servers.json"
BEEMINDER_UTILS = Path.home() / "code" / "beeminder-utils"
BEEMINDER_ENV = BEEMINDER_UTILS / ".env"


def read_env(path: Path) -> dict[str, str]:
    env = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip()
    return env


def get_claude_desktop_config_path() -> Path | None:
    if platform.system() == "Darwin":
        return Path.home() / "Library" / "Application Support" / "Claude" / "claude_desktop_config.json"

    # WSL → Windows
    if "microsoft" in platform.uname().release.lower():
        try:
            win_user = subprocess.check_output(
                ["cmd.exe", "/C", "echo %USERNAME%"],
                stderr=subprocess.DEVNULL,
            ).decode().strip()
        except Exception:
            return None
        return Path(f"/mnt/c/Users/{win_user}/AppData/Roaming/Claude/claude_desktop_config.json")

    return None


def get_beeminder_utils_path() -> str:
    """Return the native OS path to beeminder-utils (Windows path on WSL)."""
    if platform.system() == "Darwin":
        return str(BEEMINDER_UTILS)

    if "microsoft" in platform.uname().release.lower():
        try:
            win_user = subprocess.check_output(
                ["cmd.exe", "/C", "echo %USERNAME%"],
                stderr=subprocess.DEVNULL,
            ).decode().strip()
        except Exception:
            return str(BEEMINDER_UTILS)
        return f"C:\\Users\\{win_user}\\code\\beeminder-utils"

    return str(BEEMINDER_UTILS)


def main():
    dry_run = os.environ.get("dry", "0") in ("1", "2")

    if not BEEMINDER_ENV.is_file():
        print("[env] beeminder-utils not found at ~/code/beeminder-utils, skipping MCP sync")
        return

    config_path = get_claude_desktop_config_path()
    if config_path is None or not config_path.is_file():
        print("[env] Claude Desktop config not found, skipping MCP sync")
        return

    print("[env] Syncing Claude Desktop MCP servers...")

    env = read_env(BEEMINDER_ENV)
    repo_path = get_beeminder_utils_path()

    new_servers = json.loads(TEMPLATE.read_text())

    sep = "\\" if "\\" in repo_path else "/"
    mcp_server_path = repo_path + sep + "mcp_server.py"

    def replace_placeholders(obj):
        if isinstance(obj, str):
            return (obj
                .replace("__BEEMINDER_MCP_SERVER__", mcp_server_path)
                .replace("__BEEMINDER_USERNAME__", env.get("BEEMINDER_USERNAME", ""))
                .replace("__BEEMINDER_AUTH_TOKEN__", env.get("BEEMINDER_AUTH_TOKEN", "")))
        if isinstance(obj, dict):
            return {k: replace_placeholders(v) for k, v in obj.items()}
        if isinstance(obj, list):
            return [replace_placeholders(v) for v in obj]
        return obj

    new_servers = replace_placeholders(new_servers)

    config = json.loads(config_path.read_text())
    existing_servers = config.get("mcpServers", {})
    existing_servers.update(new_servers)
    config["mcpServers"] = existing_servers

    if dry_run:
        print("[env] [DRY_RUN] Would write:", json.dumps(config["mcpServers"], indent=2))
    else:
        config_path.write_text(json.dumps(config, indent=2) + "\n")
        print("[env] Claude Desktop config updated")


if __name__ == "__main__":
    main()
