#!/usr/bin/env bash

# nix-build-home builds the $HOME directory using
# the NIXHOME library. A shortcut for testing
# your nix-home config without linking it.

set -e

for i in "$@"; do
  case $i in
    --version)
      echo "0.3.1";
      exit
    ;;
  esac
done

here=$(dirname "${BASH_SOURCE[0]}")
NIXHOME=${NIXHOME:-$here/lib}

nix-build --no-out-link -I "$NIXHOME" "$HOME" "$@" || exit $?
