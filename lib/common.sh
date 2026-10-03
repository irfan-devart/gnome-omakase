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
dk_write() {
  local target=$1
  if [[ $DK_DRY_RUN == "1" ]]; then
    echo "dry-run: write $target"
    cat > /dev/null
    return
  fi
  mkdir -p "$(dirname "$target")"
  local tmp
  tmp=$(mktemp "$target.XXXXXX")
  cat > "$tmp"
  mv "$tmp" "$target"
}

# Copy a file into the backup folder once, before the first change we make to it.
dk_backup_once() {
  local file=$1 name=$2
  [[ -f $file ]] || return 0
  [[ -f $DK_BACKUPS/$name ]] && return 0
  dk_run mkdir -p "$DK_BACKUPS"
  dk_run cp -p "$file" "$DK_BACKUPS/$name"
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
  value=$(sed -n -E "s/^$key[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*$/\1/p" "$file" | head -1)
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
