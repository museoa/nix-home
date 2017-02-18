#!/usr/bin/env bash

set -e

warn() { echo WARNING: "$@" >&2; }
info() { echo          "$@" >&2; }

here=$(dirname "${BASH_SOURCE[0]}")
NIXHOME=${NIXHOME:-$here/lib}

performLink="true"
op=""

if [[ $# -eq 0 ]]; then
  op="--set"
fi

for i in "$@"; do
  case $i in
    --version)
      echo "0.3.1";
      exit
      ;;
    --dry-run)
      performLink="false"
      ;;
    # we only really need to list options which disable linking. Everything else
    # is passed directly to nix-env
    --list-generations)
      performLink="false"
      ;;
    --delete-generations)
      performLink="false"
      ;;
    --help)
      nix-env --help
      exit
      ;;
  esac
done

if [[ ! -e "$HOME/default.nix" ]]; then
  warn "No $HOME/default.nix file found, refusing to run"
  exit 1
fi

# TODO: we may want to complain if default.nix is a symlink. It can be a
# symlink but has some relative path issues.

# The trailing / is important for find to work properly
OLDOLDROOT=/var/run/user/$(id -u)/current-home/
OLDROOT=$HOME/.nix-home/
ROOT=/nix/var/nix/profiles/per-user/$USER/nix-home/

prefix=$ROOT
TMPFILE=$(mktemp -u --suffix=nixhome)

fail() {
  warn "Failed to run"
  rm -f "$TMPFILE"
  exit 1
}

if [[ "$performLink" = "true" ]]; then
  # enumerate over every file in current-home, store in TMPFILE
  touch "$TMPFILE"

  # 0.1.x
  if [[ -e "$OLDOLDROOT" ]]; then
    find "$OLDOLDROOT" -type f >> "$TMPFILE"
    find "$OLDOLDROOT" -type l >> "$TMPFILE"
  fi

  # 0.2.x
  if [[ -e "$OLDROOT" ]]; then
    find "$OLDROOT" -type f >> "$TMPFILE"
    find "$OLDROOT" -type l >> "$TMPFILE"
  fi

  # 0.3.x and beyond
  if [[ -e "$ROOT" ]]; then
    find "$ROOT" -type f >> "$TMPFILE"
    find "$ROOT" -type l >> "$TMPFILE"
  fi
fi

nix_env_cmd=(
  nix-env -I "$NIXHOME" -p "$ROOT" -f "$HOME" "$op" "$@"
)

if [[ "$PRINTCMDS" = "true" ]]; then
  info "${nix_env_cmd[@]}"
fi

# run the actual command
"${nix_env_cmd[@]}" || fail

# quit if we have skipped linking
if [[ "$performLink" != "true" ]]; then
  exit
fi

# link all symlinks in the overlay to $HOME
while IFS= read -r -d '' x; do
  dest=${x#$prefix}

  if [[ ! -h "$HOME/$dest" ]]; then
    if [[ -f "$HOME/$dest" ]]; then
      warn "$dest is a regular file; refusing to overwrite with link"
    elif [[ -d "$HOME/$dest" ]]; then
      warn "$dest is a regular directory; refusing to overwrite with link"
    else
      # dest does not exist
      info "linking $x to $dest"
      mkdir -p "$(dirname "$HOME/$dest")"
      ln -sf "$x" -t "$(dirname "$HOME/$dest")"
    fi
  else
    # dest file or dir is a symbolic link
    originalFile=$(readlink "$HOME/$dest") # ensure the existing link goes to a nix-home file, otherwise ignore it.
    case $originalFile in
      $ROOT* | $OLDROOT* | $OLDOLDROOT*)
        if [[ "$originalFile" != "$x" ]]; then
          info "linking $x to $dest"
          mkdir -p "$(dirname "$HOME/$dest")"
          ln -sf "$x" -t "$(dirname "$HOME/$dest")"
        fi
        ;;
      *)
        warn "$dest is a symlink to a non nix-home file; refusing to overwrite with link"
        ;;
    esac
  fi
done < <(find "$ROOT" -type l -print0)

# link all the regular files in the overlay to $HOME
while IFS= read -r -d '' x; do
  dest=${x#$prefix}

  if [[ ! -h "$HOME/$dest" ]]; then
    if [[ -f "$HOME/$dest" ]]; then
      warn "$dest is a regular file; refusing to overwrite with link"
    elif [[ -d "$HOME/$dest" ]]; then
      warn "$dest is a regular directory; refusing to overwrite with link"
    else
      # dest does not exist
      info "linking $x to $dest"
      mkdir -p "$(dirname "$HOME/$dest")"
      ln -sf "$x" -t "$(dirname "$HOME/$dest")"
    fi
  else
    # dest file or dir is a symbolic link
    originalFile=$(readlink "$HOME/$dest")
    case $originalFile in
      $ROOT* | $OLDROOT* | $OLDOLDROOT*)
        if [[ "$originalFile" != "$x" ]]; then
          info "linking $x to $dest"
          mkdir -p "$(dirname "$HOME/$dest")"
          ln -sf "$x" -t "$(dirname "$HOME/$dest")"
        fi
        ;;
      *)
        warn "$dest is a symlink to a non nix-home file; refusing to overwrite with link"
        ;;
    esac
  fi
done < <(find "$ROOT" -type f -print0)

# iterate over all files in TMPFILE
while IFS= read -r -d '' x; do
  if [[ ! -e "$x" ]]; then
    info "$x does not exist in new home"
    dest=${x#$prefix}

    if [[ -h "$HOME/$dest" ]]; then
      info "unlinking $HOME/$dest"
      rm "$HOME/$dest"
    else
      warn "$HOME/$dest is not a symbolic link, skipping"
    fi
  fi
done < "$TMPFILE"

# cleanup
rm "$TMPFILE"

info "Done!"
