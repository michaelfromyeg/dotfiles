# Dotfiles Repository Architecture Guide

## Overview

This is a cross-platform dotfiles management system designed to bootstrap and configure development environments across macOS, Linux (Ubuntu via WSL), and Windows. The system automates the installation of tools, languages, shell configurations, and application settings.

**Creator:** Michael DeMarco  
**Purpose:** Personal development environment automation  
**Status:** Work-in-progress (WIP)

## High-Level Architecture

```
dotfiles/
├── run.sh (main entry point)
├── scripts/ (setup scripts)
├── config/ (application configs)
├── dotfiles/ (shell & git configs)
└── archive/ (legacy configs)
```

### Core Components

1. **run.sh**: Universal harness script that orchestrates all setup
2. **scripts/**: Collection of modular setup scripts for different tasks
3. **config/**: Application configuration directories (neovim, ghostty, lazygit)
4. **dotfiles/**: Shell configuration and core dotfiles

---

## Part 1: The run.sh Harness System

### Purpose
Central entry point that provides:
- Argument parsing and filtering
- Platform detection (Windows vs POSIX)
- Dry-run modes for safety
- Script execution with unified logging
- Color-coded output per script

### Key Features

**Dry-Run Modes:**
- `--dry`: Only shows what would run (harness-level)
- `--drier`: Shows what would run AND passes to scripts (script-level)

**Platform Detection:**
```bash
# Runs .sh scripts on macOS/Linux
# Runs .ps1 scripts on Windows
```

**Argument Passing:**
```bash
# Pass arguments through to scripts using --
run.sh env -- --some-flag
```

### Usage Examples

```bash
# Test run (see what would happen)
bash ~/code/dotfiles/run.sh --dry

# Run only the 'env' setup script
bash ~/code/dotfiles/run.sh env

# Run with dry-run at script level
bash ~/code/dotfiles/run.sh test --drier

# On Windows via WSL
wsl bash -c "~/code/dotfiles/run.sh env"
```

### How It Works

1. Detects OS (Windows vs POSIX)
2. Finds executable scripts:
   - `.sh` files on macOS/Linux
   - `.ps1` files on Windows
3. Filters scripts based on argument (if provided)
4. Assigns unique colors to each script
5. Executes scripts with `execute()` function (respects dry-run modes)
6. Logs all actions with `[dotfiles]` prefix

---

## Part 2: Scripts Directory (scripts/)

The modular setup scripts. Most should be run through `run.sh`, though some (like `ui.sh`) can be run directly.

### Core Scripts

#### **env.sh** (Setup Development Environment)
**Purpose:** Initial system setup - copies configs and installs Vim/Neovim infrastructure  
**What it does:**
- Copies `config/` directory contents to `$XDG_CONFIG_HOME` (~/.config)
- Copies dotfiles to home directory (.shellrc, .zshrc, .bashrc, .gitconfig, etc.)
- Creates vim/neovim directories and undo/backup/swap folders
- Installs vim-plug (Vim package manager)
- Installs Vim plugins via PlugInstall
- Creates symlink `~/bin/dotfiles` → `run.sh` for global access

**Dependencies:** None (core)  
**Dry-run safe:** Yes  
**OS:** POSIX

#### **ui.sh / ui.ps1** (Initial Setup Orchestrator)
**Purpose:** First script to run after cloning repository  
**What it does:** Acts as setup orchestrator
- Likely chains together multiple setup steps
- Would be run directly: `bash scripts/ui.sh`

**Dependencies:** Other scripts (env, etc.)  
**OS:** Both (sh and ps1 variants)

#### **languages.sh** (Programming Language Environments)
**Purpose:** Install and configure multiple programming languages  
**Installs:**
- Rust (via rustup) + cargo-edit, cargo-watch
- Golang (specific version)
- Node.js (via nvm - Node Version Manager)
- Python (via uv)
- Ruby (via rvm - Ruby Version Manager)
- PowerShell (macOS only via Homebrew)

**Also Installs:**
- Language-specific Neovim support: neovim npm package, pynvim, neovim gem
- ghstack (GitHub stacked PR tool)

**Adds to .shellrc:** PATH exports and initialization code for all language managers

**Dependencies:** curl, package managers  
**Dry-run safe:** Yes  
**OS:** POSIX (Linux-focused, has Go download hardcoded for Linux)

#### **homebrew.sh / ui.sh** (Application Installation)
**Purpose:** Install core tools and GUI applications via Homebrew  
**Installs Core CLI Tools:**
- gcc, git, gh (GitHub CLI), vim
- Build tools: make, sqlite, qpdf, wget
- Utilities: fzf, lazygit, ripgrep, fd, git-delta, tree
- Rendering: imagemagick, ghostscript, tectonic
- oh-my-posh (prompt theme)

**macOS GUI Applications:**
- Terminal: ghostty, rectangle, alt-tab
- Development: vscode, docker, cursor
- Browsers: firefox, chrome, slack, zoom
- Media: vlc, gimp, obs, spotify
- Productivity: notion, figma, libreoffice
- System utilities: alfred, bartender, monitorcontrol

**Dependencies:** Homebrew installed  
**OS:** macOS/Linux  
**Dry-run safe:** Yes (mostly - has external commands)

#### **neovim.sh** (Build Neovim from Source)
**Purpose:** Build latest Neovim from GitHub nightly branch  
**What it does:**
- Installs build dependencies (cmake, gettext, lua)
- Clones nightly branch to ~/apps/neovim
- Builds with `make CMAKE_BUILD_TYPE=RelWithDebInfo`
- Sudo installs to system

**Dependencies:** Build tools, git  
**OS:** macOS/Linux (different deps per OS)  
**Dry-run safe:** Exits early if dry-run mode (doesn't support it)

#### **update.sh / update.ps1** (System Updates)
**Purpose:** Update all package managers  
**Updates:**
- apt (if on Linux)
- Homebrew (if available)

**OS:** Both  
**Dry-run safe:** Yes

#### **test.sh / test.ps1** (Sanity Check)
**Purpose:** Minimal test to verify harness works  
**Output:** Simple "Hello world!" message  
**Use case:** Verify run.sh harness before running real setup

#### **Utility Scripts**

- **stats.sh**: Show git contributor statistics (commits, files, insertions/deletions)
- **getignore.sh**: Download .gitignore templates from GitHub's template repo
- **repo.sh**: Display repo file tree using `git ls-tree`
- **font.sh / font.ps1**: Font installation (placeholder scripts)
- **notion.sh**: Notion-specific setup (placeholder/stub)
- **toggle-dock.sh**: Toggle macOS dock visibility

### Script Execution Pattern

Scripts follow a consistent pattern:
```bash
#!/usr/bin/env bash
echo "[script-name] Message..."

# Check for required variables from run.sh
if [[ -z "$dry" ]] || [[ -z "$script_dir" ]]; then
  echo "[script-name] Error: Required variables..."
  exit 1
fi

# Define local logging function
log() {
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    echo "[script-name] [DRY_RUN] $*"
  else
    echo "[script-name] $*"
  fi
}

# Define execution wrapper
execute() {
  log "Executing... $*"
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    return
  fi
  "$@"
}
```

---

## Part 3: Configuration Directories

### config/ Directory Structure

**config/nvim/** - Neovim Configuration (LazyVim)
- Forked from LazyVim on 2025-02-19
- Structure:
  - `init.lua`: Main entry point
  - `lua/config/`: Core configuration
    - `autocmds.lua`: Autocommands
    - `keymaps.lua`: Key bindings
    - `options.lua`: Editor options
    - `lazy.lua`: Package manager setup
  - `lua/plugins/`: Plugin definitions
    - `theme.lua`: Color scheme
    - `example.lua`: Example plugin template
  - `stylua.toml`: Lua formatter config

**config/ghostty/** - Terminal Emulator Configuration
- `config`: Ghostty terminal configuration (macOS-specific)
- Minimal setup, single config file

**config/lazygit/** - Git TUI Configuration
- `config.yml`: LazyGit configuration
- Git operations UI customization

### dotfiles/ Directory Structure

**Shell & Shell Integration:**
- `.shellrc`: Universal shell config (bash/zsh compatible)
  - History settings
  - Environment variables (XDG_CONFIG_HOME, RIPGREP_CONFIG_PATH, EDITOR)
  - Common aliases (ls, grep, git shortcuts)
  - Git aliases and functions (gnb for branch creation, ga_fzf for interactive adds)
  - Language manager initialization (nvm, pyenv, rvm, Rust cargo)
  - OS-specific setup (macOS Homebrew, Linux Linuxbrew)
  - Application-specific setup (Notion, Gemini, Claude CLI)

- `.zshrc`: Zsh-specific configuration
  - Sources `.shellrc` first
  - Zsh options (AUTO_CD, EXTENDED_GLOB, history settings)
  - Completion setup and styling
  - Antidote plugin manager integration
  - Plugin list: zsh-completions, zsh-autosuggestions, zsh-syntax-highlighting, zsh-history-substring-search
  - Pyenv, direnv, Notion CLI initialization

- `.bashrc`: Bash configuration
  - Sources `.shellrc`
  - Bash-specific options

- `.zsh_plugins.txt`: Plugin manifest for antidote
  - zsh-users/zsh-completions
  - zsh-users/zsh-autosuggestions
  - zsh-users/zsh-syntax-highlighting
  - zsh-users/zsh-history-substring-search

**Git Configuration:**
- `.gitconfig`: Git settings and aliases
  - User: michaelfromyeg / michaelfromyeg@gmail.com
  - Core: delta pager, nvim editor, precomposeunicode, untrackedCache, case-insensitive
  - Default excludes global: ~/.gitignore_global
  - Pull: rebase by default
  - Push: current branch, follow tags
  - Diff: detect renames/copies, histogram algorithm
  - Merge: log, diff3 conflict style, auto-stash
  - Aliases: pushup, lg (pretty graph log), ignored, undo, aliases, standup, lasttag, files, cleanup

- `.gitignore_global`: Global git ignore patterns
  - Applied to all repositories
  - Common: .DS_Store, editor configs, OS files

**Other Configurations:**
- `.vimrc`: Vim configuration
- `.ghstackrc`: GitHub stack PR tool config
- `.ripgreprc`: Ripgrep configuration
- `.bashrc`: Bash shell config
- `.gitignore_global`: Global gitignore patterns
- `windows-terminal.json`: Windows Terminal configuration
- `windows-vscode.json`: VSCode Windows settings
- `cold-turkey-block-lists.ctbbl`: Cold Turkey blocker lists

### archive/ Directory
Legacy configurations from previous iterations. Not currently used.

---

## Part 4: Core Workflow & Common Use Cases

### Initial Setup (First Time)

```bash
# 1. Clone repository
cd ~ && mkdir -p code
git clone https://github.com/michaelfromyeg/dotfiles.git ~/code/dotfiles

# 2. Make scripts executable
chmod +x ~/code/dotfiles/scripts/*.sh

# 3. Prerequisites (OS-specific)
# macOS:
xcode-select --install

# Linux:
sudo apt install git

# Windows:
# Install WSL via Microsoft Store, then run in WSL

# 4. Run initial setup
bash ~/code/dotfiles/run.sh ui

# or more granular:
bash ~/code/dotfiles/run.sh env      # Setup configs
bash ~/code/dotfiles/run.sh languages # Install languages
bash ~/code/dotfiles/run.sh homebrew # Install apps (if on macOS)
bash ~/code/dotfiles/run.sh neovim   # Build Neovim
```

### Making run.sh Available Globally

After `env.sh` runs:
```bash
# symlink created at ~/bin/dotfiles
export PATH="$HOME/bin:$PATH"

# Now can run from anywhere:
dotfiles test
dotfiles update
```

### Safe Testing Before Applying

```bash
# See what would happen without actually doing it
bash ~/code/dotfiles/run.sh --dry

# Run specific script in dry mode
bash ~/code/dotfiles/run.sh env --dry

# Script-level dry run (more verbose at script level)
bash ~/code/dotfiles/run.sh test --drier
```

### System Maintenance

```bash
# Update everything (apt, brew)
bash ~/code/dotfiles/run.sh update

# Get git statistics for current repo
bash ~/code/dotfiles/run.sh stats

# View repo file tree
bash ~/code/dotfiles/run.sh repo
```

### Git-Related Tasks

```bash
# Download gitignore template
bash ~/code/dotfiles/run.sh getignore -- Python

# Use git aliases (from .gitconfig and .shellrc)
g status              # git status
glg                   # pretty git log
gd                    # git diff
gaf                   # interactive git add via fzf
gnb my-feature        # create branch: michaelfromyeg--my-feature
gts                   # gh stack sync
```

---

## Part 5: Platform-Specific Considerations

### macOS
- Homebrew is the package manager
- GUI applications installed via Homebrew Cask
- Supports: zsh (default), bash
- Tools: rectangle (window management), ghostty (terminal)
- Build tools from xcode-select

### Linux (Ubuntu/WSL)
- apt is the package manager
- Linuxbrew available as alternative
- Primarily bash
- Build tools via apt

### Windows
- Uses WSL 2 (Ubuntu instance)
- PowerShell scripts (.ps1) for Windows-native tasks
- Run from WSL bash for Linux tasks
- GUI apps installed via winget or direct download

### Cross-Platform Features
- Shell configs work in bash and zsh
- Git configuration universal
- Environment variables normalized via .shellrc
- Language managers support all platforms

---

## Part 6: Development Workflow & Architecture Patterns

### Modular Script Design
- Each script is independent and can run standalone
- `run.sh` filters which scripts to run
- Scripts use `$dry`, `$script_dir` from environment
- Consistent logging with `[script-name]` prefix

### Configuration Management
- Configs copied (not symlinked) to standard locations
- `env.sh` handles the sync
- Application-specific configs in `config/` (XDG Base Directory compliant)
- User configs in `dotfiles/` (standard Unix dotfiles)

### Shell Configuration Hierarchy
```
.zshrc / .bashrc (shell-specific)
  └─ source .shellrc (universal)
      └─ sources language managers
      └─ sets environment variables
      └─ defines aliases and functions
```

### Language Integration
- Each language manager initialized in `.shellrc`
- Rust: `~/.cargo/env`
- Node: nvm with completion
- Python: pyenv
- Ruby: rvm
- Go: PATH setup for /usr/local/go/bin

---

## Part 7: Key Design Decisions & Notable Features

### Strengths
1. **Unified Harness**: Single `run.sh` for all platforms
2. **Modular Scripts**: Can run individually or all together
3. **Dry-Run Safe**: Two-level dry-run support
4. **Cross-Platform**: Same configs on macOS, Linux, Windows
5. **Shell-Agnostic**: Works with bash and zsh
6. **XDG Compliant**: Respects XDG Base Directory spec
7. **Git-Centric**: Sophisticated git aliases and helpers

### Current Limitations (From TODO.md)
- Initial setup requires manual running of `ui` script
- Missing: tmux setup
- Missing: Terminal and Ghostty full configs
- Missing: Complete vscode settings and extensions
- OS detection logic could be centralized further
- git worktree support not yet implemented

### Personalization Notes
- Aliases hardcoded with author name "michaelfromyeg" in some places
- Notion-specific setup included (not generic)
- Gemini (Google Cloud) and Claude CLI aliases included
- May need customization for different users

---

## Part 8: Key Files Quick Reference

| File | Purpose | Type |
|------|---------|------|
| run.sh | Main entry point harness | Bash |
| scripts/env.sh | Initial environment setup | Bash |
| scripts/ui.sh | First-run orchestrator | Bash |
| scripts/languages.sh | Install programming languages | Bash |
| scripts/homebrew.sh | Install tools and apps | Bash |
| scripts/neovim.sh | Build Neovim from source | Bash |
| scripts/update.sh | System updates | Bash |
| config/nvim/init.lua | Neovim main config | Lua |
| dotfiles/.shellrc | Universal shell config | Bash/Zsh |
| dotfiles/.zshrc | Zsh config | Zsh |
| dotfiles/.gitconfig | Git settings | INI |
| dotfiles/.bashrc | Bash config | Bash |

---

## Typical Developer Workflow

### After Initial Setup
```bash
# 1. Update system
dotfiles update

# 2. Check status (if working on dotfiles changes)
cd ~/code/dotfiles
git status
dotfiles stats

# 3. Edit configs as needed (e.g., Neovim)
vim config/nvim/lua/config/options.lua

# 4. Sync changes to home directory
dotfiles env

# 5. Reload shell or open new terminal
exec zsh
```

### Adding New Setup Script
```bash
# 1. Create new script in scripts/
# 2. Follow the pattern: #!/usr/bin/env bash, check $dry and $script_dir
# 3. Use log() and execute() functions
# 4. Make executable: chmod +x scripts/my-new-script.sh
# 5. Run via harness: dotfiles my-new-script
```

---

## For Claude Code Assistants

### Key Context for Common Tasks

**To understand what will happen when running a command:**
1. Start with `run.sh` - it determines platform and finds scripts
2. Check if script exists in `scripts/` 
3. Read the specific script to see what it does
4. Be aware of `$dry` modes for safety

**To modify dotfiles:**
1. Edit files in `dotfiles/` or `config/`
2. Run `dotfiles env` or `run.sh env` to sync to home
3. Restart shell with `exec zsh` to pick up changes

**To add new tools/languages:**
1. Consider if it should be in existing script or new script
2. Follow the logging pattern in existing scripts
3. Test with `--dry` flag first

**To debug issues:**
1. Run with `--drier` for verbose output
2. Check if platform-specific (macOS vs Linux)
3. Verify required commands are installed
4. Check file permissions (scripts need +x)

### Important Assumptions
- Repository cloned to `~/code/dotfiles`
- Homebrew on macOS, apt on Linux
- XDG Base Directory spec supported
- POSIX-compliant shell on Linux/macOS
- WSL 2 on Windows with Ubuntu instance

---

## References & Related Files

- README.md - User-facing documentation
- TODO.md - Future improvements and TODOs
- LICENSE - MIT license
- .gitignore - Repository-level ignores
- .gitmodules - Git submodules (if any)
- .editorconfig - Editor formatting standards
- .markdownlint.json - Markdown linting rules

