#!/bin/sh

# Original code from: https://stackoverflow.com/questions/19576742/how-to-clone-all-repos-at-once-from-github

if [ $# -ne 1 ]
  then
    echo "Missing arguments; usage: sh clone_github_repos.sh GITHUB_USER_NAME"
    exit 1
fi

CNTX="users"; NAME="$1"; PAGE=1
curl "https://api.github.com/$CNTX/$NAME/repos?page=$PAGE&per_page=1000" |
  grep -e 'git_url*' |
  cut -d \" -f 4 |
  xargs -L1 git clone