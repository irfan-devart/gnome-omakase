# One function per app. Each takes the theme file and applies it.
# Every app is optional: missing apps are skipped, not errors.

apply_gnome() {
  local t=$1 mode
  mode=$(dk_get "$t" mode)
  if [[ $mode == "dark" ]]; then
    dk_run gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
  else
    dk_run gsettings set org.gnome.desktop.interface color-scheme "default"
  fi
  dk_run gsettings set org.gnome.desktop.interface accent-color "$(dk_get "$t" gnome_accent)"
}

apply_ptyxis() {
  local t=$1 id=$2 profile palette_dir i
  command -v ptyxis > /dev/null || return 0
  profile=$(gsettings get org.gnome.Ptyxis default-profile-uuid | tr -d "'")
  [[ $profile =~ ^[0-9a-f]+$ ]] || return 0
  palette_dir="${XDG_DATA_HOME:-$HOME/.local/share}/org.gnome.Ptyxis/palettes"

  # Same colours in both sections, so the palette holds whatever Ptyxis' own style is.
  {
    echo "[Palette]"
    echo "Name=dk-$id"
    for section in Light Dark; do
      echo
      echo "[$section]"
      echo "Background=$(dk_get "$t" background)"
      echo "Foreground=$(dk_get "$t" foreground)"
      echo "Cursor=$(dk_get "$t" cursor)"
      for i in {0..15}; do
        echo "Color$i=$(dk_get "$t" "color$i")"
      done
    done
  } | dk_write "$palette_dir/dk-$id.palette"

  dk_run gsettings set "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$profile/" palette "dk-$id"
  dk_run gsettings set org.gnome.Ptyxis interface-style "$(dk_get "$t" mode)"
}

apply_herdr() {
  local t=$1 config name
  command -v herdr > /dev/null || return 0
  config="${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
  [[ -f $config ]] || return 0
  name=$(dk_get "$t" herdr)
  dk_backup_once "$config" herdr-config.toml

  # Set name = "..." inside the [theme] table only: replace it if present,
  # else add it under the header. Without a [theme] table, append one.
  if grep -q '^\[theme\]' "$config"; then
    awk -v name="$name" '
      /^\[/ { in_theme = ($0 == "[theme]") }
      in_theme && /^name[[:space:]]*=/ { has_name = 1 }
      { lines[NR] = $0; theme[NR] = in_theme }
      END {
        for (i = 1; i <= NR; i++) {
          if (theme[i] && lines[i] ~ /^name[[:space:]]*=/) { print "name = \"" name "\""; continue }
          print lines[i]
          if (!has_name && lines[i] == "[theme]") print "name = \"" name "\""
        }
      }
    ' "$config" | dk_write "$config"
  else
    { cat "$config"; printf '\n[theme]\nname = "%s"\n' "$name"; } | dk_write "$config"
  fi
  dk_run herdr server reload-config > /dev/null 2>&1 || true
}

apply_claude() {
  local t=$1 settings value
  command -v jq > /dev/null || return 0
  settings="$HOME/.claude/settings.json"
  [[ -f $settings ]] || return 0
  value=$(dk_get "$t" claude)
  dk_backup_once "$settings" claude-settings.json
  jq --arg theme "$value" '.theme = $theme' "$settings" | dk_write "$settings"
}

apply_rofi() {
  local t=$1
  command -v rofi > /dev/null || return 0
  dk_write "$DK_STATE/rofi.rasi" << EOF
* {
  bg: $(dk_get "$t" background);
  fg: $(dk_get "$t" foreground);
  accent: $(dk_get "$t" accent);
  sel-fg: $(dk_get "$t" selection_foreground);
  sel-bg: $(dk_get "$t" selection_background);
  background-color: transparent;
  text-color: @fg;
  font: "Sans 12";
}
window { background-color: @bg; border: 2px; border-color: @accent; width: 40%; padding: 12px; }
inputbar { padding: 6px; children: [prompt, entry]; spacing: 8px; }
prompt { text-color: @accent; }
listview { lines: 10; scrollbar: false; padding: 6px 0 0; }
element { padding: 6px; spacing: 8px; }
element selected { background-color: @sel-bg; text-color: @sel-fg; }
element-text { text-color: inherit; }
element-icon { size: 1.2em; }
EOF
}
