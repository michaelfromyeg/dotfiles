#!/usr/bin/bash

# List the files in a git repository in a tree-like format.

git ls-tree -r --name-only HEAD | tree --fromfile
