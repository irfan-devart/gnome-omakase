# Custom keybindings. Ours all live under one id prefix, so uninstall removes
# exactly what install added and leaves the user's own shortcuts alone.

OM_KB_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
OM_KB_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
OM_KB_PREFIX="gnome-omakase-"

# Print the custom-keybinding paths as one per line.
om_kb_list() {
  gsettings get "$OM_KB_SCHEMA" custom-keybindings | grep -oE "'[^']+'" | tr -d "'"
}

om_kb_set_list() {
  local paths=("$@") joined=""
  local p
  for p in "${paths[@]}"; do
    joined+="${joined:+, }'$p'"
  done
  om_run gsettings set "$OM_KB_SCHEMA" custom-keybindings "[$joined]"
}

# Is this key combination already used by a custom shortcut that isn't ours?
om_kb_taken() {
  local binding=$1 path
  while read -r path; do
    [[ -z $path || $path == "$OM_KB_PATH/$OM_KB_PREFIX"* ]] && continue
    if [[ $(gsettings get "$OM_KB_SCHEMA.custom-keybinding:$path" binding) == "'$binding'" ]]; then
      return 0
    fi
  done < <(om_kb_list)
  return 1
}

# Add or update one of our shortcuts.
om_kb_add() {
  local id=$1 name=$2 command=$3 binding=$4
  local path="$OM_KB_PATH/$OM_KB_PREFIX$id/"
  local schema="$OM_KB_SCHEMA.custom-keybinding:$path"

  if om_kb_taken "$binding"; then
    echo "  skip $name: $binding is already used by another custom shortcut"
    return 0
  fi

  local paths=()
  mapfile -t paths < <(om_kb_list)
  if [[ " ${paths[*]} " != *" $path "* ]]; then
    om_kb_set_list "${paths[@]}" "$path"
  fi
  om_run gsettings set "$schema" name "$name"
  om_run gsettings set "$schema" command "$command"
  om_run gsettings set "$schema" binding "$binding"
  echo "  $binding  $name"
}

# Remove all of our shortcuts, keeping everyone else's.
om_kb_remove_all() {
  local path keep=()
  while read -r path; do
    [[ -z $path ]] && continue
    if [[ $path == "$OM_KB_PATH/$OM_KB_PREFIX"* ]]; then
      om_run dconf reset -f "$path"
    else
      keep+=("$path")
    fi
  done < <(om_kb_list)
  om_kb_set_list "${keep[@]}"
}
