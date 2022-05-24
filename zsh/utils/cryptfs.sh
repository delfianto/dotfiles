#!/bin/sh
#
# Wrapper script for cryptfs ruby utility.
#
DIR="$(dirname "$(readlink "$0")")"

if [[ ! -z "$1" ]]; then
  eval "${DIR}/cryptfs.rb ${@:1}"
else
  echo 'Usage: cryptfs [ mount | umount ] [ config_key ]'
fi
