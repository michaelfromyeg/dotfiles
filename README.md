# Dotfiles

This repository includes the dotfiles I use for (cross-platform) Neovim, Visual Studio Code, Cursor, (Windows) WSL 2, Windows Terminal, PowerShell, (macOS) Ghostty, Zsh.

There's one entry point for all of my setup `run.sh`. It can, in turn, run scripts in `scripts/`.

Some of the scripts I have today...

- `test`, for sanity
- `neovim`, to build `neovim` from source
- `env`, to set up my development environment
  - On Linux,
  - On macOS,
  - On Windows
- The `vscode.json` is a read-only copy, since Visual Studio Code natively handles settings sync

## Window Managers

- Fancy Zones on Windows
  - TODO(michaelfromyeg): go through [this guide](https://learn.microsoft.com/en-us/windows/powertoys/fancyzones)
- Rectangles on macOS
