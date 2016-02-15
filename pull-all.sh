#!/bin/sh

set -eu

function readlink_f() {
  if [ $(uname) = 'Darwin' ]
  then
    DIR=$(echo "${1%/*}")
    FILE=$(basename "$1")
    (cd "$DIR" && echo "$(pwd -P)/$FILE")
  else
    readlink -f "$1"
  fi
}

parentdir=$(dirname $(dirname $(readlink_f "$0")))

dirs=$(echo "$parentdir/"*"/.git")

for d in $dirs
do
  cd "$d/.."
  git pull
done
