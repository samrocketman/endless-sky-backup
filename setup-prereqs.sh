#!/bin/bash
# Created by Sam Gleske
# Thu Mar 20 10:37:53 PM EDT 2025
# Ubuntu 22.04.4 LTS
# Linux 6.1.43 aarch64
# GNU bash, version 5.1.16(1)-release (aarch64-unknown-linux-gnu)

set -exuo pipefail

if [ ! -f download-utilities.sh ]; then
  curl -sSfLO https://raw.githubusercontent.com/samrocketman/yml-install-files/b82aebfc9407fdcaf251ad843554f3d374d67080/download-utilities.sh
  chmod 755 download-utilities.sh
fi

./download-utilities.sh download-utilities.yml

if ! type -P java; then
  echo 'java is missing; sudo apt install openjdk-11-jre' >&2
  exit 1
fi

if [ ! -f github-token ]; then
  echo './github-token should contain a personal access token.'
  exit 1
fi
