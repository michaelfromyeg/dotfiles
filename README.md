# Dotfiles

Cross-platform (macOS, Linux/WSL, Windows) development environment: shell
configs, app configs, setup scripts, git hooks, and Claude Code configuration.

## Quick start

On a fresh macOS or Linux machine:

```sh
curl -fsSL https://raw.githubusercontent.com/michaelfromyeg/dotfiles/main/bootstrap.sh | bash
```

This installs git if needed, clones the repo to `~/code/dotfiles` (the path
the configs assume), and syncs configs to your home directory. Then:

```sh
dotfiles ui         # Homebrew CLI tools + apps (from Brewfile)
dotfiles languages  # language toolchains
exec $SHELL
```

On Windows: install WSL + Ubuntu from the Microsoft Store, run the Linux steps
inside WSL, and for native apps run `scripts/ui.ps1` in an elevated PowerShell
(`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` first).

## Usage

Everything runs through the `run.sh` harness (symlinked to `~/bin/dotfiles` by
`env.sh`):

```sh
dotfiles <script>            # run one script (exact name, e.g. `dotfiles env`)
dotfiles                     # run everything
dotfiles <script> --dry      # show what would run, run nothing
dotfiles <script> --drier    # scripts run, but log instead of executing
dotfiles <script> -- <args>  # pass args through to the script
```

### Scripts

| Script | What it does |
|---|---|
| `env` | Sync configs to `$HOME` (backs up anything it overwrites to `~/.dotfiles-backup/`) |
| `ui` | Install CLI tools and apps via `brew bundle` (see `Brewfile`) |
| `languages` | Install language toolchains (rust, go, etc.) |
| `update` | Update apt/brew packages |
| `homebrew` | Install Homebrew itself |
| `neovim` | Build Neovim from source |
| `claude-plugins` | Install Claude Code plugins declared in `claude/settings.json` |
| `test` | Sanity check |
| `test-changed` | Run tests for files changed vs a base branch (notion-next) |
| `tmux-dev` | Start a dev tmux session (claude + scratchpad + notion run) |
| `stats` | Git contribution stats |
| `cold-turkey` | Quit Cold Turkey Blocker (it breaks headless Chrome) |
| `getignore` | Download a gitignore template |
| `repo` | Show repo files as a tree |
| `toggle-dock` | Restart the macOS Dock |
| `font` | Install a Nerd Font via oh-my-posh |
| `notion` | Run Notion's environment setup |

## Layout

```
run.sh          # entry-point harness ($dry, $script_dir contract)
bootstrap.sh    # fresh-machine setup, curl-able
Brewfile        # Homebrew packages + casks (brew bundle)
scripts/        # setup scripts; lib.sh holds shared log/run_cmd helpers
dotfiles/       # home-directory configs (.shellrc, .zshrc, .gitconfig, ...)
config/         # XDG configs (nvim, ghostty, lazygit, bat, ohmyposh)
config/git/hooks/  # global git hooks (core.hooksPath)
claude/         # Claude Code user config (settings, CLAUDE.md, statusline)
```

Work-specific config (boxy helpers, Opal access requests, internal hostnames)
lives in a separate private repo and layers on top of this one: `.shellrc`
sources `~/.shellrc.notion` when it exists, and `~/.claude/CLAUDE.md` imports
`~/.claude/CLAUDE.notion.md`. Neither is required — this repo stands alone.

`env.sh` copies (not symlinks) configs into place and warns about repo files
it doesn't know how to sync. Shell config layering: `.zshrc`/`.bashrc` source
the shared `.shellrc`; mise manages language versions.

## Notes

- Window managers: Rectangle on macOS, FancyZones (PowerToys) on Windows.
- VS Code settings sync natively; `.vscode/` here is for this repo only.
- CI runs shellcheck, shfmt, JSON validation, and a harness smoke test on
  macOS and Ubuntu.
