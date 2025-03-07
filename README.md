# Dotfiles

This repository includes the dotfiles I use for (cross-platform) Neovim, Visual Studio Code, Cursor, (Windows) WSL 2, Windows Terminal, PowerShell, (macOS) Ghostty.

> ⚠️ This is a work-in-progress!

There's one entry point for all of my setup `run.sh`. It can, in turn, run scripts in `scripts/`.

Some of the scripts I have today...

- `test`, for sanity
- `neovim`, to build `neovim` from source
- `env`, to set up my development environment
  - On Linux,
  - On macOS,
  - or on Windows

Plus some config files under `dotfiles/` and `config/`.

- The `vscode.json` is a read-only copy, since Visual Studio Code natively handles settings sync

## Prerequisites

- On Windows
  - Install WSL via the Microsoft Store
  - Install Ubuntu (or another instance of choice) similarly
  - (To install Windows GUI applications...)
    - Go to PowerShell, run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`, `cd ~`, `winget install --id=Git.Git -e`
    - Clone this repository to `~/code` on the Windows filesystem, and run `.\dotfiles\scripts\ui.ps1`
    - Let that run in the background while you do the rest
  - Open Ubuntu, and switch to the Linux instructions below
- On macOS
  - Run `xcode-select --install`
  - Clone this repository to `~/code`
  - `chmod +x scripts/*.sh`
  - Run `scripts/ui.sh`
- On Linux
  - `sudo apt install git`
  - Clone this repository to `~/code`
  - `chmod +x scripts/*.sh`
  - Run `scripts/ui.sh`

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
# NOTE: on Windows it's okay to run `ui.ps1` "directly" (i.e., via PowerShell)
wsl bash -c "~/code/dotfiles/run.sh --dry"
wsl bash -c "~/code/dotfiles/run.sh test --drier"
wsl bash -c "~/code/dotfiles/run.sh"
```

To get going initially, you'll want to run `run.sh env` to set up your environment.

Running the `env.sh` script will make the run script accessible everywhere, under `dotfiles`. For example, `dotfiles test` will output the test script!

## Window Managers

- Fancy Zones on Windows
  - TODO(michaelfromyeg): go through [this guide](https://learn.microsoft.com/en-us/windows/powertoys/fancyzones)
- Rectangles on macOS
