#!/bin/bash
# Created by Sam Gleske
# Thu Mar 20 10:50:21 PM EDT 2025
# Ubuntu 22.04.4 LTS
# Linux 6.1.43 aarch64
# GNU bash, version 5.1.16(1)-release (aarch64-unknown-linux-gnu)

if [ ! "$(whoami)" = root ]; then
  echo 'This script is expected to be run as root.'
  exit 1
fi

function is_repo_cloneable() {
  timeout 1 git ls-remote "$1" HEAD &> /dev/null
}
function check_and_clone() {
    if [ ! -d "$1" ] && is_repo_cloneable "$2"; then
      git clone --mirror "$2"
    fi

}
function clone_repos_and_wikis() {
  java -jar cloneable.jar \
    --github-token=/mnt/fast/endless-sky-backup/github-token \
    --owner=endless-sky | \
  while read -r repo; do
    (
      cd "$backup_destination"
      wiki="${repo}.wiki.git"
      bare_repo="${repo}.git"
      set -x
      check_and_clone "$wiki" https://github.com/endless-sky/"$wiki"
      check_and_clone "$bare_repo" https://github.com/endless-sky/"$bare_repo"
    )
  done
}
function update_backups() {
  find . -maxdepth 1 -name '*.git' -print0 | \
    xargs -0 -n1 -P4 -I'{}' -- /bin/bash -exc 'cd "{}"; git fetch'
}
function list_plugins() (
  PATH="/mnt/fast/endless-sky-backup:$PATH"
  cd /mnt/fast/endless-sky-mirror/endless-sky-plugins.git
  git show HEAD:generated/plugins.yaml | yq '.[].homepage'
)
function clone_plugins() {
  list_plugins | while read -r repo; do
    (
      cd "$backup_destination"
      local_wiki="${repo##*/}"
      local_wiki="${local_wiki%.git}.wiki.git"
      local_repo="${repo##*/}"
      local_repo="${local_wiki%.git}.git"
      check_and_clone "$local_wiki" "${repo%.git}".wiki.git
      check_and_clone "$local_repo" "${repo%.git}".git
    )
  done
}
function create_reflog() (
  cd "$backup_destination"
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
  cd "$backup_destination"
  for x in *.git; do
    (
      cd "$x"
      git show-ref
    ) > reflog/"${x%.git}"
  done
)
function commit_reflog() (
  cd "$backup_destination"/reflog
  git add .
  if ! git diff --exit-code --cached &> /dev/null; then
    git commit -m "Daily show-ref of bare repositories $(date +%Y-%d-%m)"
  fi
)
#
# MAIN
#
cd /mnt/fast/endless-sky-backup/
backup_destination=/mnt/fast/endless-sky-mirror
export backup_destination
clone_repos_and_wikis
clone_plugins
# track refs on a daily basis
create_reflog
build_reflog
commit_reflog
for x in "$backup_destination"/*.git; do
  git config -f "$x"/config --get remote.origin.url
done > index.txt
