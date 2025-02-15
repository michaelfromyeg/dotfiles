#!/bin/sh

brew update
brew upgrade

BREW_PREFIX=$(brew --prefix)

brew install coreutils
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

brew install moreutils
brew install findutils
brew install gnu-sed --with-default-names
brew install bash
brew install bash-completion2

# Switch to using brew-installed bash as default shell
if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then
  echo "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells;
  # chsh -s "${BREW_PREFIX}/bin/bash";
fi;

brew install wget --with-iri
brew install gnupg

# Override MacOS
brew install vim --with-override-system-vi
brew install grep
brew install openssh
brew install screen

# Fonts
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install sfnt2woff-zopfli
brew install woff2

# Extra utilities
brew install ack
brew install git
brew install git-lfs
brew install imagemagick --with-webp
brew install tree

# zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

brew cleanup
