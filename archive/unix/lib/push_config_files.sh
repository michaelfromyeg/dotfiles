#!/bin/sh

echo "Copying files..."
cp ../../config/.vimrc ~/.vimrc
cp ../../config/.bashrc ~/.bashrc
cp ../../config/.gitconfig ~/.gitconfig
cp ../../config/.hushlogin ~/.hushlogin
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  cp ../../config/.zshrc.linux ~/.zshrc
elif [[ "$OSTYPE" == "darwin"* ]]; then
  cp ../../config/.zshrc.osx ~/.zshrc
fi
echo "Done!"