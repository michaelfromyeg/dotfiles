# Homebrew Bundle manifest. Install with `dotfiles ui`, or directly:
#   brew bundle --file=~/code/dotfiles/Brewfile
# Audit drift (things installed but not listed here):
#   brew bundle cleanup --file=~/code/dotfiles/Brewfile

tap "aviator-co/tap"
tap "jandedobbeleer/oh-my-posh"

# Core command line tools
brew "gcc"
brew "git"
brew "gh"
brew "vim"
brew "make"
# NOTE: neovim is built from source (`dotfiles neovim`), not installed here
brew "sqlite"
brew "qpdf"
brew "wget"
# GNU find; macOS's BSD find is limited
brew "findutils"
brew "fzf"
brew "lazygit"
brew "ripgrep"
brew "fd"
brew "git-delta"
brew "tree"
brew "tmux"
brew "xclip"
brew "jq"
brew "bat"
brew "eza"
brew "htop"
brew "tldr"
brew "zoxide"
brew "hyperfine"
brew "direnv"
brew "shellcheck"
brew "shfmt"
brew "git-branchless"
# av (Aviator CLI) for stacked PRs
brew "aviator-co/tap/av"
# Rendering stuff
brew "imagemagick"
brew "ghostscript"
brew "tectonic"
brew "jandedobbeleer/oh-my-posh/oh-my-posh"

if OS.mac?
  # Core Utilities
  cask "ghostty"
  cask "rectangle"
  cask "alt-tab"

  # Development
  cask "visual-studio-code"
  cask "docker"
  cask "antidote"

  # Browsers and Communication
  cask "firefox"
  cask "google-chrome"
  cask "slack"
  cask "zoom"
  cask "thunderbird"

  # Media and File Management
  cask "vlc"
  cask "gimp"
  cask "handbrake"
  cask "obs"
  cask "spotify"
  cask "skim"

  # Office and Productivity
  cask "libreoffice"
  cask "notion"
  cask "figma"
  cask "beeper"
  cask "cold-turkey-blocker"
  cask "logitech-options"
  cask "keepassxc"

  # Cloud Storage
  cask "dropbox"
  cask "google-drive"

  # Utilities
  cask "calibre"
  cask "the-unarchiver"
  cask "cursor"
  cask "dupeguru"
  cask "private-internet-access"
  cask "qbittorrent"

  # Additional Mac-specific tools
  cask "alfred"
  cask "bartender"
  cask "monitorcontrol"
  cask "app-cleaner"
end
