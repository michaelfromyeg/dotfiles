#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $(basename "$0") <template-name>"
  echo "Example: $(basename "$0") Python"
  exit 1
fi

template="$1"
base_url="https://raw.githubusercontent.com/github/gitignore/main"

# If .gitignore is appended, remove it
template="${template%.gitignore}"

# Construct URL - first try with first letter capitalized
url="$base_url/${template^}.gitignore"

# Download the template
if ! curl -f -s "$url" -o .gitignore; then
  # If that fails, try exact name
  url="$base_url/$template.gitignore"
  if ! curl -f -s "$url" -o .gitignore; then
    echo "Error: Could not find gitignore template for '$template'"
    echo "Check available templates at: https://github.com/github/gitignore"
    exit 1
  fi
fi

echo "Successfully downloaded ${template^}.gitignore to current directory"
