#!/bin/sh

brew update
brew upgrade
BREW_PREFIX=$(brew --prefix)

brew install --cask visual-studio-code
brew install --cask slack
brew install --cask discord
brew install --cask postman
brew install --cask spotify
brew install --cask docker
brew install --cask mongodb-compass
brew install --cask iterm2

brew cleanup
