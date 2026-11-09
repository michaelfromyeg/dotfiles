# Homebrew Bundle manifest. Install with `dotfiles ui`, or directly:
#   brew bundle --file=~/code/dotfiles/Brewfile
# Audit drift (things installed but not listed here):
#   brew bundle cleanup --file=~/code/dotfiles/Brewfile

tap "aviator-co/tap"
tap "jandedobbeleer/oh-my-posh"
tap "michaelfromorg/tiled"

# Core command line tools
brew "gcc"
brew "git"
brew "gh"
brew "michaelfromorg/tiled/til"
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
# tldr formula was removed from Homebrew; tlrc is the official client (`tldr` command)
brew "tlrc"
brew "zoxide"
# zsh plugin manager (a formula, not a cask)
brew "antidote"
brew "hyperfine"
brew "direnv"
# version manager (node, ...); config in config/mise, activated in .shellrc
brew "mise"
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
  # Leave apps alone when something other than Homebrew installed them (e.g. IT
  # pushing Zoom via MDM on a work laptop): brew can't upgrade over those.
  def installed_outside_brew?(token, app)
    File.exist?("/Applications/#{app}") && !File.exist?("#{HOMEBREW_PREFIX}/Caskroom/#{token}")
  end

  # Core Utilities
  cask "ghostty"
  # Ghostty's font (config/ghostty/config)
  cask "font-cascadia-code-nf"
  cask "rectangle"
  # Windows-style keys; config in config/karabiner
  cask "karabiner-elements"
  cask "alt-tab"

  # Development
  cask "visual-studio-code"
  cask "zed"
  cask "zed-delta"
  # Coding agent CLIs
  cask "claude-code"
  cask "codex"
  cask "docker-desktop" unless installed_outside_brew?("docker-desktop", "Docker.app")

  # Browsers and Communication
  cask "firefox"
  cask "google-chrome"
  cask "slack" unless installed_outside_brew?("slack", "Slack.app")
  cask "zoom" unless installed_outside_brew?("zoom", "zoom.us.app")
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
  cask "notion-calendar"
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
  # dupeguru and qbittorrent casks were disabled by Homebrew (fail Gatekeeper); install manually if needed
  cask "private-internet-access"

  # Additional Mac-specific tools
  cask "alfred"
  cask "bartender"
  cask "monitorcontrol"
  cask "app-cleaner"
end
