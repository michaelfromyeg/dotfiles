#!/usr/bin/env bash

# Keeps the git repos listed below cheap to fetch. env.sh runs this on each
# sync, so fresh clones (including Boxy's) pick it up.
#
# 1. Narrows the fetch refspec to the default branch plus my own branches.
#    Big monorepos like notion-next have ~40k branches, so git clone's default
#    +refs/heads/* makes every fetch download everyone's pushes (large blobs
#    included): a few days away meant a 100k-object fetch at GitHub's
#    sub-MiB/s pack speeds. This can't live in .gitconfig:
#    remote.origin.fetch is multi-valued, so a global value is added alongside
#    the clone's +refs/heads/* instead of replacing it.
#
#    Also deletes the remote-tracking refs the narrowed refspec no longer
#    updates. Keeping them wouldn't help: git maps @{u} through the refspec,
#    so a local branch tracking someone else's branch loses its upstream
#    either way. Reach anyone else's branch with `git fetch origin <branch>`.
#
# 2. On macOS, schedules `git maintenance` (hourly prefetch and commit-graph,
#    daily incremental repack), so foreground fetches find little left to
#    download and packs don't pile up. The repo list goes in
#    ~/.gitconfig.local, not ~/.gitconfig: env.sh overwrites ~/.gitconfig,
#    which would silently unregister every repo.
#
# Idempotent; safe to run on every sync.

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

# Repos to manage. Paths that don't exist are skipped, so one list covers the
# laptop and Boxy.
repos=(
  "$HOME/code/notion-next"
  /work/notion-next
)

# Branches of mine to keep fetching, alongside each repo's default branch.
my_branches="michaelfromyeg--*"

# Machine-local git config, included by .gitconfig.
local_config="$HOME/.gitconfig.local"

# Set per repo by the main loop.
refspecs=()

# True if the ref is updated by one of $refspecs (matches a destination glob).
tracked_by_refspec() {
  local spec
  for spec in "${refspecs[@]}"; do
    # Unquoted RHS so the refspec's * acts as a glob; like git's, it matches
    # across slashes.
    # shellcheck disable=SC2053
    [[ $1 == ${spec#*:} ]] && return 0
  done
  return 1
}

# The remote's default branch, as recorded by clone in origin/HEAD.
default_branch() {
  local head
  head="$(git -C "$1" symbolic-ref --quiet --short refs/remotes/origin/HEAD)"
  echo "${head#origin/}"
}

narrow_refspec() {
  local repo="$1"

  if [[ "$(git -C "$repo" config --get-all remote.origin.fetch)" != "$(printf '%s\n' "${refspecs[@]}")" ]]; then
    run_cmd git -C "$repo" config --replace-all remote.origin.fetch "${refspecs[0]}"
    for spec in "${refspecs[@]:1}"; do
      run_cmd git -C "$repo" config --add remote.origin.fetch "$spec"
    done
  fi

  # Maintenance's prefetch task mirrors the refspec under refs/prefetch/, so
  # a repo prefetched under the old wildcard has a stale copy of every branch.
  local stale ref dst
  stale="$(
    git -C "$repo" for-each-ref --format='%(refname)' refs/remotes/origin refs/prefetch/remotes/origin |
      while read -r ref; do
        [[ $ref == refs/remotes/origin/HEAD ]] && continue
        dst="$ref"
        [[ $ref == refs/prefetch/* ]] && dst="refs/${ref#refs/prefetch/}"
        tracked_by_refspec "$dst" && continue
        echo "delete $ref"
      done
  )"
  if [[ -n "$stale" ]]; then
    log "$repo: deleting $(wc -l <<<"$stale" | tr -d ' ') remote-tracking/prefetch refs outside the refspec"
    run_cmd git -C "$repo" update-ref --stdin <<<"$stale"
  fi
}

schedule_maintenance() {
  local repo="$1"

  # Boxies are short-lived containers without a scheduler worth relying on.
  if [[ "$(uname -s)" != "Darwin" ]]; then
    return 0
  fi

  if git config --file "$local_config" --get-all maintenance.repo 2>/dev/null | grep -qxF "$repo" &&
    [[ -f "$HOME/Library/LaunchAgents/org.git-scm.git.hourly.plist" ]]; then
    return 0
  fi

  # `maintenance start` registers the repo in the global config file and
  # installs the launchd agents; pointing GIT_CONFIG_GLOBAL at the local file
  # makes the registration land there.
  run_cmd env GIT_CONFIG_GLOBAL="$local_config" git -C "$repo" maintenance start
}

for repo in "${repos[@]}"; do
  [[ -e "$repo/.git" ]] || continue

  trunk="$(default_branch "$repo")"
  if [[ -z "$trunk" ]]; then
    log "$repo: no origin/HEAD; assuming main (fix with \`git remote set-head origin --auto\`)"
    trunk=main
  fi
  refspecs=(
    "+refs/heads/$trunk:refs/remotes/origin/$trunk"
    "+refs/heads/$my_branches:refs/remotes/origin/$my_branches"
  )

  narrow_refspec "$repo"
  schedule_maintenance "$repo"
  log "$repo: up to date"
done
