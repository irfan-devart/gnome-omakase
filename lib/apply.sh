# One function per app. Each takes the theme file and applies it.
# Every app is optional: missing apps are skipped, not errors.

apply_gnome() {
  local t=$1 mode
  mode=$(om_get "$t" mode)
  if [[ $mode == "dark" ]]; then
    om_gset org.gnome.desktop.interface color-scheme "prefer-dark"
  else
    om_gset org.gnome.desktop.interface color-scheme "default"
  fi
  om_gset org.gnome.desktop.interface accent-color "$(om_get "$t" gnome_accent)"
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
    echo "Name=omakase-$id"
    for section in Light Dark; do
      echo
      echo "[$section]"
      echo "Background=$(om_get "$t" background)"
      echo "Foreground=$(om_get "$t" foreground)"
      echo "Cursor=$(om_get "$t" cursor)"
      for i in {0..15}; do
        echo "Color$i=$(om_get "$t" "color$i")"
      done
    done
  } | om_write "$palette_dir/omakase-$id.palette"

  om_gset "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$profile/" palette "omakase-$id"
  om_gset org.gnome.Ptyxis interface-style "$(om_get "$t" mode)"
}

apply_herdr() {
  local t=$1 config
  command -v herdr > /dev/null || return 0
  config=$(om_herdr_config)
  [[ -f $config ]] || return 0
  om_backup_once "$config" herdr-config.toml
  local old
  old=$(sed -n -E '/^\[theme\]/,/^\[/ s/^name[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$config" | head -1)
  [[ $old =~ ^[a-z0-9-]{1,40}$ ]] || old=""
  om_remember herdr "$config" name "$old"
  om_herdr_set_name "$config" "$(om_get "$t" herdr)"
}

om_herdr_config() {
  echo "${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
}

om_herdr_set_name() {
  local config=$1 name=$2

  # Set name = "..." inside the [theme] table only: replace it if present,
  # else add it under the header. Without a [theme] table, append one.
  if grep -qE '^\[theme\][[:space:]]*(#.*)?$' "$config"; then
    # shellcheck disable=SC2016 # awk program, not shell
    OM_NAME="$name" om_rewrite "$config" awk '
      BEGIN { name = ENVIRON["OM_NAME"] }
      /^\[/ { in_theme = ($0 ~ /^\[theme\][[:space:]]*(#.*)?$/) }
      in_theme && /^name[[:space:]]*=/ { has_name = 1 }
      { lines[NR] = $0; theme[NR] = in_theme }
      END {
        for (i = 1; i <= NR; i++) {
          if (theme[i] && lines[i] ~ /^name[[:space:]]*=/) { print "name = \"" name "\""; continue }
          print lines[i]
          if (!has_name && lines[i] ~ /^\[theme\]/) print "name = \"" name "\""
        }
      }
    ' "$config"
  else
    { cat "$config"; printf '\n[theme]\nname = "%s"\n' "$name"; } | om_write "$config"
  fi
  om_run herdr server reload-config > /dev/null 2>&1 || true
}

apply_claude() {
  local t=$1 settings value
  command -v jq > /dev/null || return 0
  settings="$HOME/.claude/settings.json"
  [[ -f $settings ]] || return 0
  value=$(om_get "$t" claude)
  jq -e . "$settings" > /dev/null 2>&1 || {
    echo "  skip Claude Code: $settings isn't plain JSON" >&2
    return 0
  }
  om_backup_once "$settings" claude-settings.json
  local old
  old=$(jq -r 'if (.theme | type) == "string" then .theme else "" end' "$settings")
  [[ $old =~ ^[a-z0-9-]{0,40}$ ]] || old=""
  om_remember claude "$settings" theme "$old"
  # shellcheck disable=SC2016 # jq variable, not shell
  om_rewrite "$settings" jq --arg theme "$value" '.theme = $theme' "$settings"
}

# Tactile tiling grid colours. Gaps and grids live in defaults/tactile.dconf. dconf is used
# because Tactile's schema lives in the user's extension folder, not system-wide.
apply_tactile() {
  local t=$1 accent fg r g b
  gnome-extensions info tactile@lundal.io > /dev/null 2>&1 || return 0
  accent=$(om_get "$t" accent)
  fg=$(om_get "$t" foreground)
  r=$((16#${accent:1:2})); g=$((16#${accent:3:2})); b=$((16#${accent:5:2}))
  om_dset /org/gnome/shell/extensions/tactile/background-color "'rgba($r,$g,$b,0.15)'"
  om_dset /org/gnome/shell/extensions/tactile/border-color "'rgba($r,$g,$b,0.8)'"
  r=$((16#${fg:1:2})); g=$((16#${fg:3:2})); b=$((16#${fg:5:2}))
  om_dset /org/gnome/shell/extensions/tactile/text-color "'rgba($r,$g,$b,1.0)'"
}

# Wallpaper: the first image in the user's folder for this theme, else one
# generated from the palette. Only plain file names are used, so the URI
# needs no escaping.
apply_wallpaper() {
  local t=$1 id=$2 image="" file uri
  local user_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gnome-omakase/backgrounds/$id"

  for file in "$user_dir"/*; do
    [[ -f $file && $(basename "$file") =~ ^[A-Za-z0-9._-]+\.(jpg|jpeg|png|svg|webp)$ ]] || continue
    image=$file
    break
  done

  if [[ -z $image ]]; then
    image="$OM_STATE/wallpapers/$id.svg"
    om_generate_wallpaper "$t" | om_write "$image"
  fi

  uri="file://$(om_uri_path "$image")"
  om_gset org.gnome.desktop.background picture-uri "$uri"
  om_gset org.gnome.desktop.background picture-uri-dark "$uri"
  om_gset org.gnome.desktop.background picture-options "zoom"
  om_gset org.gnome.desktop.screensaver picture-uri "$uri"
}

# Percent-encode a path for a file:// URI.
om_uri_path() {
  local path=$1 out="" c i
  for (( i = 0; i < ${#path}; i++ )); do
    c=${path:i:1}
    if [[ $c =~ [A-Za-z0-9/._~-] ]]; then
      out+=$c
    else
      out+=$(printf '%%%02X' "'$c")
    fi
  done
  echo "$out"
}

# A soft gradient with two blurred glows in the theme's accent colours.
om_generate_wallpaper() {
  local t=$1 bg c0 accent c5 c6
  bg=$(om_get "$t" background)
  c0=$(om_get "$t" color0)
  accent=$(om_get "$t" accent)
  c5=$(om_get "$t" color5)
  c6=$(om_get "$t" color6)
  cat << EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3200 2000" preserveAspectRatio="xMidYMid slice">
  <defs>
    <linearGradient id="base" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="$bg"/>
      <stop offset="1" stop-color="$c0"/>
    </linearGradient>
    <filter id="soft" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="220"/>
    </filter>
  </defs>
  <rect width="3200" height="2000" fill="url(#base)"/>
  <circle cx="2450" cy="520" r="620" fill="$accent" opacity="0.30" filter="url(#soft)"/>
  <circle cx="700" cy="1600" r="560" fill="$c5" opacity="0.22" filter="url(#soft)"/>
  <circle cx="1700" cy="1250" r="380" fill="$c6" opacity="0.14" filter="url(#soft)"/>
</svg>
EOF
}

apply_rofi() {
  local t=$1
  command -v rofi > /dev/null || return 0
  om_write "$OM_STATE/rofi.rasi" << EOF
* {
  bg: $(om_get "$t" background);
  fg: $(om_get "$t" foreground);
  accent: $(om_get "$t" accent);
  sel-fg: $(om_get "$t" selection_foreground);
  sel-bg: $(om_get "$t" selection_background);
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
