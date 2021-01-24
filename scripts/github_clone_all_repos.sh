# Original code from: https://stackoverflow.com/questions/19576742/how-to-clone-all-repos-at-once-from-github

if [ $# -ne 2 ]
  then
    echo "Missing arguments; usage: sh clone_github_repos.sh GITHUB_USER_NAME GITHUB_API_TOKEN"
    exit 1
fi

curl -H "Authorization: token $2" -s "https://api.github.com/users/$1/repos?per_page=1000" | grep -w clone_url | grep -o '[^"]\+://.\+.git' | xargs -L1 git -C ~/code clone 