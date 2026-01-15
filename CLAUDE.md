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
dotfiles env           # Sync configs to home directory
dotfiles update        # Update package managers (apt, brew)
dotfiles test          # Sanity check
dotfiles homebrew      # Install tools/apps via Homebrew
dotfiles languages     # Install programming languages
dotfiles neovim        # Build Neovim from source
```

### Dry-Run Modes

- `--dry`: Harness-level dry run (shows what scripts would run)
- `--drier`: Script-level dry run (scripts log but don't execute)

### Testing Changed Files

```bash
./scripts/test-changed.sh [options]
# Options: -a (all tests), -i (integration only), -n (dry-run), -v (verbose)
# Default: runs unit tests for files changed vs main branch
```

## Architecture

```
run.sh                 # Main entry point harness
scripts/               # Modular setup scripts (.sh for POSIX, .ps1 for Windows)
config/                # XDG-compliant app configs (nvim, ghostty, lazygit)
dotfiles/              # Shell configs (.shellrc, .zshrc, .bashrc, .gitconfig)
```

### Key Design Patterns

**Shell Configuration Hierarchy:**
```
.zshrc / .bashrc (shell-specific)
  └─ sources .shellrc (universal)
      └─ language managers (nvm, pyenv, rvm, cargo)
      └─ environment variables
      └─ aliases and functions
```

**Script Pattern:** Scripts expect `$dry` and `$script_dir` from `run.sh`:
```bash
#!/usr/bin/env bash
echo "[script-name] Starting..."
# Check $dry == "1" or "2" before executing commands
```

**Config Deployment:** `env.sh` copies (not symlinks) configs from this repo to:
- `config/*` → `~/.config/`
- `dotfiles/*` → `~/`

## Key Files

| Purpose | File |
|---------|------|
| Universal shell config | `dotfiles/.shellrc` |
| Git settings & aliases | `dotfiles/.gitconfig` |
| Neovim config (LazyVim) | `config/nvim/init.lua` |
| Homebrew apps list | `scripts/homebrew.sh` |
| Language installers | `scripts/languages.sh` |

## Workflow

**Modifying configs:**
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
