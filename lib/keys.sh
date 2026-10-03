# Custom keybindings. Ours all live under one id prefix, so uninstall removes
# exactly what install added and leaves the user's own shortcuts alone.

DK_KB_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
DK_KB_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
DK_KB_PREFIX="desktop-kit-"

# Print the custom-keybinding paths as one per line.
dk_kb_list() {
  gsettings get "$DK_KB_SCHEMA" custom-keybindings | grep -oE "'[^']+'" | tr -d "'"
}

dk_kb_set_list() {
  local paths=("$@") joined=""
  local p
  for p in "${paths[@]}"; do
    joined+="${joined:+, }'$p'"
  done
  dk_run gsettings set "$DK_KB_SCHEMA" custom-keybindings "[$joined]"
}

# Is this key combination already used by a custom shortcut that isn't ours?
dk_kb_taken() {
  local binding=$1 path
  while read -r path; do
    [[ -z $path || $path == "$DK_KB_PATH/$DK_KB_PREFIX"* ]] && continue
    if [[ $(gsettings get "$DK_KB_SCHEMA.custom-keybinding:$path" binding) == "'$binding'" ]]; then
      return 0
    fi
  done < <(dk_kb_list)
  return 1
}

# Add or update one of our shortcuts.
dk_kb_add() {
  local id=$1 name=$2 command=$3 binding=$4
  local path="$DK_KB_PATH/$DK_KB_PREFIX$id/"
  local schema="$DK_KB_SCHEMA.custom-keybinding:$path"

  if dk_kb_taken "$binding"; then
    echo "  skip $name: $binding is already used by another custom shortcut"
    return 0
  fi

  local paths=()
  mapfile -t paths < <(dk_kb_list)
  if [[ " ${paths[*]} " != *" $path "* ]]; then
    dk_kb_set_list "${paths[@]}" "$path"
  fi
  dk_run gsettings set "$schema" name "$name"
  dk_run gsettings set "$schema" command "$command"
  dk_run gsettings set "$schema" binding "$binding"
  echo "  $binding  $name"
}

# Remove all of our shortcuts, keeping everyone else's.
dk_kb_remove_all() {
  local path keep=()
  while read -r path; do
    [[ -z $path ]] && continue
    if [[ $path == "$DK_KB_PATH/$DK_KB_PREFIX"* ]]; then
      dk_run dconf reset -f "$path"
    else
      keep+=("$path")
    fi
  done < <(dk_kb_list)
  dk_kb_set_list "${keep[@]}"
}
