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

## Prerequisites

- On Windows
  - Install WSL
  - Install Ubuntu (or another instance of choice)
  - `sudo apt install git`
  - Clone this repository to `~/code` via `git clone https://github.com/michaelfromyeg/dotfiles`
- On macOS
  - Run `xcode-select --install`
  - Clone this repository to `~/code`
- On Linux
  - `sudo apt install git`
  - Clone this repository to `~/code`

## Usage

Everything should be run through the `run.sh` harness. This universally takes care of argument parsing and provides some helpful guards.

Depending on your operating system, it'll call the appropriate script (`.sh` for POSIX systems, or `.ps1` for Windows).

To access `run.sh`, call it like...

```plaintext
# on macOS or Linux
bash ~/code/dotfiles/run.sh --dry
bash ~/code/dotfiles/run.sh test --drier
bash ~/code/dotfiles/run.sh

# on Windows
wsl bash -c "~/code/dotfiles/run.sh --dry"
wsl bash -c "~/code/dotfiles/run.sh test --drier"
wsl bash -c "~/code/dotfiles/run.sh"
```

## Window Managers

- Fancy Zones on Windows
  - TODO(michaelfromyeg): go through [this guide](https://learn.microsoft.com/en-us/windows/powertoys/fancyzones)
- Rectangles on macOS
