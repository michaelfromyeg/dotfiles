#!/bin/sh

# Inspired by: https://github.com/source-foundry/hack-linux-installer/blob/master/hack-linux-installer.sh
# Only downloads the latest version

# Note that to actually use fonts with Windows Terminal, etc, they need to be installed in Windows

echo "Attempting to download and install Cascadia Code..."

url=$(
  curl -s "https://api.github.com/repos/microsoft/cascadia-code/releases/latest" \
  | grep '"browser_download_url": ' \
  | sed -E 's/.*"([^"]+)".*/\1/'
)

echo $url

# Download files
echo "Downloading files..."
wget $url

# Unpack files
filename=$(echo ${url##*/})
echo "Unzipping $filename from $url..."
unzip $filename

# Move the binary
mv ttf/CascadiaMonoPL.ttf  ~/.local/share/fonts/CascadiaMonoPL.ttf

# Regenerate font cache
sudo fc-cache -f -v

# Verify installation
fc-list | grep "Cascadia"

# Cleanup installation
rm -rf otf
rm -rf ttf
rm -rf woff2
rm $filename

echo "Finished! Cascadia Code is now installed."
