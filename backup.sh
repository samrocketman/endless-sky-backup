#!/bin/bash
# Created by Sam Gleske
# Thu Mar 20 10:50:21 PM EDT 2025
# Ubuntu 22.04.4 LTS
# Linux 6.1.43 aarch64
# GNU bash, version 5.1.16(1)-release (aarch64-unknown-linux-gnu)

set -e

backup_scripts="${backup_scripts:-/mnt/fast/endless-sky-backup}"
backup_destination="${backup_destination:-/mnt/fast/endless-sky-mirror}"
intended_user="${intended_user:-root}"
# do not prompt for https password when checking for wikis
GIT_TERMINAL_PROMPT="${GIT_TERMINAL_PROMPT:-0}"
export backup_destination backup_scripts intended_user GIT_TERMINAL_PROMPT

if [ ! "$(whoami)" = "$intended_user" ]; then
  echo "This script is expected to be run as ${intended_user}."
  exit 1
fi

function is_repo_cloneable() (
  exec &> /dev/null
  timeout 1 git ls-remote "$1" HEAD
)
function check_and_clone() {
  local_dir="$1"
  if [ "${3:-}" = plugin ]; then
    username="$(cut -d/ -f4 <<< "$2")"
    if [ ! "${username}" = "endless-sky" ]; then
      local_dir="plugin--${username}--${local_dir}"
    fi
  fi
  if [ ! -d "$local_dir" ] && is_repo_cloneable "$2"; then
    git clone --mirror "$2" "$local_dir"
  fi
}
function clone_repos_and_wikis() {
  java -jar cloneable.jar \
    --github-token=/mnt/fast/endless-sky-backup/github-token \
    --owner=endless-sky | \
  while read -r repo; do
    (
      cd -- "$backup_destination"
      wiki="${repo}.wiki.git"
      bare_repo="${repo}.git"
      set -x
      check_and_clone "$wiki" https://github.com/endless-sky/"$wiki"
      check_and_clone "$bare_repo" https://github.com/endless-sky/"$bare_repo"
    )
  done
}
function update_backups() {
  find "$backup_destination" -maxdepth 1 -name '*.git' -print0 | \
    xargs -0 -P4 -I'{}' -- /bin/bash -exc 'cd -- "{}"; git fetch'
}
function list_plugins() (
  PATH="/mnt/fast/endless-sky-backup:$PATH"
  cd -- /mnt/fast/endless-sky-mirror/endless-sky-plugins.git
  git show HEAD:generated/plugins.yaml | yq '.[].homepage'
)
function clone_plugins() {
  list_plugins | while read -r repo; do
    (
      cd -- "$backup_destination"
      repo="${repo%/}"
      local_wiki="${repo##*/}"
      local_wiki="${local_wiki%.git}.wiki.git"
      local_repo="${repo##*/}"
      local_repo="${local_repo%.git}.git"
      check_and_clone "${local_wiki}" "${repo%/*}/${local_wiki}" plugin
      check_and_clone "${local_repo}" "${repo%/*}/${local_repo}" plugin
    )
  done
}
function create_reflog() (
  if [ -d "${backup_destination}/reflog/.git" ]; then
    # exit subshell
    exit 0
  fi
  cd -- "$backup_destination"
  if [ ! -d reflog ]; then
    mkdir reflog
  fi
  cd reflog
  if [ ! -d .git ]; then
    git init
    echo 'This is a daily track of the backup reflog' > README
    git add README
    git commit -m "initial commit"
  fi
)
function build_reflog() (
  cd -- "$backup_destination"
  for x in *.git; do
    (
      cd -- "$x"
      git show-ref
    ) > reflog/"${x%.git}"
  done
)
function commit_reflog() (
  cd -- "$backup_destination"/reflog
  git add .
  if ! git diff --exit-code --cached &> /dev/null; then
    git commit -m "Daily show-ref of bare repositories $(date +%Y-%d-%m)"
  fi
)
#
# MAIN
#
cd -- "$backup_scripts"
clone_repos_and_wikis
clone_plugins
update_backups
# track refs on a daily basis
create_reflog
build_reflog
commit_reflog
for x in "$backup_destination"/*.git; do
  git config -f "$x"/config --get remote.origin.url
done | LC_ALL=C sort -u > index.txt
