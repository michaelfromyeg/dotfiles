# To-dos

Things I should do. At some point.

- `macos.sh` defaults script (`defaults write` for Dock, Finder, key repeat, screenshots)
- Watch for: ssh `ControlMaster` (new in .ssh/config.local `Host *`) misbehaving with `notion boxy` connections -- scope it narrower if so
- Watch for: boxy tool pins going stale (boxy/init.sh pins versions + sha256s now; bump deliberately)
- tmux plugin manager + session persistence (tpm, tmux-resurrect) — useful for ephemeral boxies
- A winget manifest for `ui.ps1` (the Brewfile equivalent on Windows)
- Consider symlink-based deployment (or managed blocks) to end repo-vs-$HOME drift
- Prune old `~/.dotfiles-backup/` entries automatically (e.g. keep last 10)
- ~~Make the initial setup nicer~~ (bootstrap.sh)
- ~~`tmux` setup~~
- ~~`vscode` settings and extensions~~ (VS Code sync + `.vscode/` for this repo)
- ~~`terminal` and `ghostty` configs~~
- Centralize the OS check (`is_macos`/`is_wsl` in scripts/lib.sh; still ad hoc in run.sh, env.sh, ui.ps1)
- ~~`git worktree`~~
