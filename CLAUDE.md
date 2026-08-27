# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Cross-platform dotfiles management system for macOS, Linux (Ubuntu/WSL), and Windows. Automates development environment setup including tools, languages, shell configs, and application settings.

## Commands

### Running Setup Scripts

```bash
# Via harness (preferred)
bash ~/code/dotfiles/run.sh <script-name> [--dry|--drier]

# After env.sh runs, use the symlink
dotfiles <script-name>

# Examples
dotfiles env           # Sync configs to home directory (backs up overwrites to ~/.dotfiles-backup/)
dotfiles update        # Update package managers (apt, brew)
dotfiles test          # Sanity check
dotfiles homebrew      # Install Homebrew itself
dotfiles ui            # Install CLI tools + apps via `brew bundle` (Brewfile)
dotfiles languages     # Install programming languages
dotfiles neovim        # Build Neovim from source
dotfiles claude-plugins # Install Claude Code plugins from claude/settings.json
```

Fresh machines bootstrap with `bootstrap.sh` (curl-able; clones to `~/code/dotfiles` and runs `env`).

The filter matches a script name exactly first (`dotfiles test` runs only test.sh), falling back to substring match.

### Dry-Run Modes

- `--dry`: Harness-level dry run (shows what scripts would run)
- `--drier`: Script-level dry run (scripts log but don't execute)

### Testing Changed Files

```bash
./scripts/test-changed.sh [options] [-- notion-test-args...]
# -b, --base BRANCH   Compare against BRANCH (av stack parent); discovers tests
#                     over BRANCH..HEAD. Unset: falls back to `notion test --branch`.
# -o, --output FILE   Tee combined output to FILE ( -t appends a timestamp)
# -u, --untracked     Also include untracked *.test.{ts,tsx,js,jsx} files
# -a, --all           Include integration tests (excluded by default)
# -i, --integration   Run ONLY integration tests
# -c, --cap N         Cap discovered tests at N (random sample; default 40, 0 = off)
# Everything after -- is forwarded to `notion test` (e.g. --coverage --bail)
```

## Architecture

```
run.sh                 # Main entry point harness
scripts/               # Modular setup scripts (.sh for POSIX, .ps1 for Windows)
config/                # XDG-compliant app configs (nvim, ghostty, lazygit, bat, ohmyposh)
dotfiles/              # Shell configs (.shellrc, .zshrc, .bashrc, .gitconfig, .tmux.conf)
claude/                # Claude Code user-level config (settings.json, CLAUDE.md, skills/)
```

### Key Design Patterns

**Shell Configuration Hierarchy:**

```
.zshrc / .bashrc (shell-specific)
  └─ sources .shellrc (universal)
      └─ mise (single version manager: node, erlang/elixir; nvm is lazy-stubbed)
      └─ environment variables
      └─ aliases and functions
```

**Script Pattern:** Scripts source shared helpers from `scripts/lib.sh` and expect `$dry` / `$script_dir` exported from `run.sh` (lib.sh defaults `dry` to "0" for direct invocation):

```bash
#!/usr/bin/env bash
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
log "Starting..."          # prefixed with [script-name], notes DRY_RUN
run_cmd some command       # logs, then runs unless $dry is 1 or 2
# $dry == "0" -> normal, "1" -> harness dry run, "2" -> script-level dry run
# lib.sh is deliberately NOT executable: run.sh runs every executable *.sh in scripts/
```

**Config Deployment:** `env.sh` copies (not symlinks) configs from this repo to:

- `config/*` → `~/.config/`
- `dotfiles/*` → `~/`
- `dotfiles/.ssh/config.local` → `~/.ssh/` (auto-included via `~/.ssh/config`)
- `claude/*` → `~/.claude/`
- On macOS: also syncs a boxy remote dev profile to `~/.boxy/profile/` (its
  init script comes from the private layer, not this repo)

## Key Files

| Purpose                 | File                   |
| ----------------------- | ---------------------- |
| Universal shell config  | `dotfiles/.shellrc`    |
| Git settings & aliases  | `dotfiles/.gitconfig`  |
| Neovim config (LazyVim) | `config/nvim/init.lua` |
| Homebrew packages/apps  | `Brewfile` (installed by `scripts/ui.sh`) |
| Language installers     | `scripts/languages.sh` |
| Shared script helpers   | `scripts/lib.sh`       |

## Workflow

### Git and Branch Management

I use both vanilla git and av (Aviator CLI, `av`) for branch/PR management. Detect which is in use before running commands:

- **av stack:** Run `av tree` — if it recognizes the current branch as part of a stack, use av. Use `av` commands (`av branch`, `av pr`, `av sync`, `av restack`, etc.) instead of raw git for branch creation, rebasing, and PR submission.
- **Vanilla git:** Use standard git commands and `gh` for PRs.

Don't mix: e.g., don't `git rebase` an av-managed stack or `av pr` a vanilla branch.

### Modifying configs:

1. Edit files in `dotfiles/` or `config/`
2. Run `dotfiles env` to sync to home
3. Reload shell: `exec zsh`

**Adding new setup script:**

1. Create `scripts/my-script.sh` following the pattern above
2. `chmod +x scripts/my-script.sh`
3. Run via `dotfiles my-script`

## Platform Notes

- **macOS:** Homebrew, zsh default, xcode-select required
- **Linux:** apt, bash primary, Linuxbrew optional
- **Windows:** WSL 2 (Ubuntu), PowerShell scripts for native tasks
