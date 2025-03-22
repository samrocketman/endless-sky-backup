#!/bin/bash
# Created by Sam Gleske
# Fri Mar 21 08:38:51 PM EDT 2025
# Ubuntu 22.04.4 LTS
# Linux 6.1.43 aarch64
# GNU bash, version 5.1.16(1)-release (aarch64-unknown-linux-gnu)
# git version 2.34.1
# DESCRIPTION
#   Deduplicates the backup storage in order to save space.  This script is a
#   work in progress.
#
#   Note: if a user manually runs `git prune` there will be temporary data loss
#   until the next backup is run.  This will have an impact on storage
#   efficiency.
#
# Maintenance should only be performed by this dedupe script.
#
# REFERENCES
#   https://gitlab.com/gitlab-com/gl-infra/production-engineering/-/issues/13228
#   https://docs.gitlab.com/development/git_object_deduplication/
#   https://git-scm.com/docs/gitrepository-layout#Documentation/gitrepository-layout.txt-objects
#   https://stackoverflow.com/questions/7348698/how-to-list-all-git-objects-in-the-database
set -euo pipefail
function create_reference_repo() (
  if [ ! -d "${1:-}" ]; then
    echo 'ERROR: expected directory in order to create subdirectory "reference-repo" but no directory provided.' >&2
    exit 1
  fi
  local current_dir
  current_dir="$(canonical_dir "$1")"
  cd "$current_dir"
  if [ ! -d reference-repo ]; then
    mkdir reference-repo
  fi

  cd reference-repo
  if [ "$(find . -maxdepth 1 -type f | wc -l | xargs)" = 0 ]; then
    git init --bare

    # Make a best effort to protect the reference repository from running
    # garbate collection.
    git config gc.auto 0
    git config gc.pruneExpire never
    git config gc.reflogExpire never
    git config gc.reflogExpireUnreachable never
    git config -f config esbackup.fullrepack true
    echo -e '#!/bin/bash\necho gc not supported\nexit 1' > hooks/pre-auto-gc
    chmod 755 hooks/pre-auto-gc
  else
    echo 'ERROR: "'"${current_dir}/reference-repo"'" is already initialized.' >&2
    exit 1
  fi
)

function canonical_dir() (
  cd "$1"
  pwd
)

function full_repack() (
  if [ -d "$1" ]; then
    cd "$1"
  else
    echo 'ERROR: '"$1"' is not a directory.'
  fi
  if [ ! -f config ] && \
     [ ! "$(git config -f config --get core.bare)" = true ]; then
    echo 'ERROR: '"$1"' must be a bare repository.' >&2
    exit 1
  fi
  local current_dir
  current_dir="$(canonical_dir "$PWD")"
  if [ ! "${current_dir##*/}" = "reference-repo" ]; then
    echo 'ERROR: Cannot perform a full repack because the current repository is not named "reference-repo".' >&2
    exit 1
  fi
  if [ ! "$(git config -f config --get esbackup.fullrepack)" = true ]; then
    # abort early because full repack is not available
    # perform a normal repack
    git repack -d
    exit
  fi
  git repack -a -d && \
    find objects/pack -maxdepth 1 -type f -name 'tmp_pack_*' -exec rm -f {} +
  git config -f config esbackup.fullrepack false
)

if [ "${1:-}" = "--init" ]; then
  create_reference_repo "${2:-}"
elif [ "${1:-}" = "--repack" ]; then
  full_repack "${2:-}"
else
  echo 'ERROR: unsupported options provided.' >&2
  exit 1
fi

# In general do not run git gc.  This is just dedupe experimentation.
# echo '../../reference-repo/objects' > endless-sky.git/objects/info/alternates
# cd endless-sky.git; git gc
