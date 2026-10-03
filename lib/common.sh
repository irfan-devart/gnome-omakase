# Shared paths and helpers. Sourced, not executed.

DK_ROOT="${DK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DK_THEMES="$DK_ROOT/themes"
DK_USER_THEMES="${XDG_CONFIG_HOME:-$HOME/.config}/desktop-kit/themes"
DK_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/desktop-kit"
DK_BACKUPS="$DK_STATE/backups"
DK_DRY_RUN="${DK_DRY_RUN:-0}"

GNOME_ACCENTS="blue teal green yellow orange red pink purple slate"

dk_die() {
  echo "desktop-kit: $*" >&2
  exit 1
}

# Run a command, or only print it in dry-run mode.
dk_run() {
  if [[ $DK_DRY_RUN == "1" ]]; then
    printf 'dry-run:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

# Write stdin to a file atomically, or print the target in dry-run mode.
# Refuses empty input, and writes through symlinks so dotfile links survive.
dk_write() {
  local target=$1
  if [[ $DK_DRY_RUN == "1" ]]; then
    echo "dry-run: write $target"
    cat > /dev/null
    return
  fi
  [[ -L $target ]] && target=$(readlink -f "$target")
  mkdir -p "$(dirname "$target")"
  local staged
  staged=$(mktemp "$target.XXXXXX")
  cat > "$staged"
  if [[ ! -s $staged ]]; then
    rm -f "$staged"
    dk_die "refusing to write an empty $target"
  fi
  [[ -f $target ]] && chmod --reference="$target" "$staged"
  mv "$staged" "$target"
}

# Run a command that prints a file's new content, and write it only if the
# command succeeded. A failed jq or awk never empties the target.
dk_rewrite() {
  local target=$1 out
  shift
  out=$("$@") || dk_die "could not update $target (left unchanged)"
  printf '%s\n' "$out" | dk_write "$target"
}

# Copy a file into the backup folder once, before the first change we make to it.
dk_backup_once() {
  local file=$1 name=$2
  [[ -f $file ]] || return 0
  [[ -f $DK_BACKUPS/$name ]] && return 0
  dk_run mkdir -p "$DK_BACKUPS"
  dk_run cp -p "$file" "$DK_BACKUPS/$name"
}

# The first time we change a setting, record its original value in prior.tsv,
# so uninstall can put it back. Later changes don't overwrite the record.
DK_PRIOR="$DK_STATE/prior.tsv"

dk_remember() {
  local kind=$1 where=$2 key=$3 value=$4
  [[ $DK_DRY_RUN == "1" ]] && return 0
  mkdir -p "$DK_STATE"
  if [[ -f $DK_PRIOR ]] && grep -qF -- "$kind"$'\t'"$where"$'\t'"$key"$'\t' "$DK_PRIOR"; then
    return 0
  fi
  printf '%s\t%s\t%s\t%s\n' "$kind" "$where" "$key" "$value" >> "$DK_PRIOR"
}

# gsettings set, remembering the original value first.
# Keys that don't exist on this GNOME version (e.g. accent-color before 47)
# are skipped, so nothing is half-applied or recorded empty.
dk_gset() {
  local schema=$1 key=$2 value=$3 old
  old=$(gsettings get "$schema" "$key" 2> /dev/null) || {
    echo "  skip $key: not available on this GNOME" >&2
    return 0
  }
  dk_remember gsettings "$schema" "$key" "$old"
  dk_run gsettings set "$schema" "$key" "$value"
}

# dconf write, remembering the original value (empty means unset) first.
dk_dset() {
  local path=$1 value=$2
  dk_remember dconf "$(dirname "$path")" "$(basename "$path")" "$(dconf read "$path")"
  dk_run dconf write "$path" "$value"
}

# Resolve a theme id to its folder. User themes override bundled ones.
dk_theme_dir() {
  local id=$1
  [[ $id =~ ^[a-z0-9-]+$ ]] || dk_die "invalid theme id '$id'"
  if [[ -f $DK_USER_THEMES/$id/theme.toml ]]; then
    echo "$DK_USER_THEMES/$id"
  elif [[ -f $DK_THEMES/$id/theme.toml ]]; then
    echo "$DK_THEMES/$id"
  else
    dk_die "theme '$id' not found (try: theme-list)"
  fi
}

dk_theme_ids() {
  local dir
  for dir in "$DK_THEMES"/*/ "$DK_USER_THEMES"/*/; do
    [[ -f $dir/theme.toml ]] && basename "$dir"
  done | sort -u
}

# Read one key = "value" line from a theme file. Values are validated here,
# because they end up in gsettings, sed and config files.
dk_get() {
  local file=$1 key=$2 value
  value=$(sed -n -E "s/^${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*$/\1/p" "$file" | head -1)
  [[ -n $value ]] || dk_die "$file: missing '$key'"

  case $key in
    name)
      [[ $value =~ ^[A-Za-z0-9\ ._-]{1,40}$ ]] || dk_die "$file: bad name" ;;
    mode)
      [[ $value == "light" || $value == "dark" ]] || dk_die "$file: mode must be light or dark" ;;
    gnome_accent)
      [[ " $GNOME_ACCENTS " == *" $value "* ]] || dk_die "$file: gnome_accent must be one of: $GNOME_ACCENTS" ;;
    herdr | claude)
      [[ $value =~ ^[a-z0-9-]{1,40}$ ]] || dk_die "$file: bad $key value" ;;
    *)
      [[ $value =~ ^#[0-9a-fA-F]{6}$ ]] || dk_die "$file: $key must be a #rrggbb colour" ;;
  esac
  echo "$value"
}
