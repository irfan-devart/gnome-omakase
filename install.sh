#!/bin/bash

# Install gnome-omakase for the current user. No sudo, nothing outside $HOME.
# Usage: ./install.sh [--dry-run] [--extensions] [--theme <id>]
#   --extensions  ask GNOME to install Tactile and Focus changer from
#                 extensions.gnome.org (GNOME shows a confirmation for each)
#   --theme       theme to apply (default: tokyo-night, or keep the current one)

set -euo pipefail

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"
source "$OM_ROOT/lib/apply.sh"
source "$OM_ROOT/lib/keys.sh"

want_extensions=0
theme=""
while (( $# > 0 )); do
  case $1 in
    --dry-run) OM_DRY_RUN=1 ;;
    --extensions) want_extensions=1 ;;
    --theme)
      [[ -n ${2:-} ]] || om_die "--theme needs a theme id"
      theme=$2
      shift ;;
    -h | --help) sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) om_die "unknown option '$1'" ;;
  esac
  shift
done

EXTENSIONS=(tactile@lundal.io focus-changer@heartmire)

echo "== Checks"
[[ ${XDG_CURRENT_DESKTOP:-} == *GNOME* ]] || om_die "needs a GNOME session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})"
for cmd in gsettings dconf; do
  command -v "$cmd" > /dev/null || om_die "missing '$cmd'"
done
missing=()
for pkg in rofi jq; do
  command -v "$pkg" > /dev/null || missing+=("$pkg")
done
if (( ${#missing[@]} > 0 )); then
  echo "  Optional packages missing; their features are skipped until installed:"
  echo "    sudo apt install ${missing[*]}"
fi

echo "== Backup"
backup="$OM_BACKUPS/gnome-$(date +%Y%m%d-%H%M%S).dconf"
if [[ $OM_DRY_RUN == "1" ]]; then
  echo "dry-run: dconf dump /org/gnome/ > $backup"
else
  mkdir -p "$OM_BACKUPS"
  dconf dump /org/gnome/ > "$backup"
  echo "  $backup"
fi

echo "== Commands in ~/.local/bin"
for cmd in "$OM_ROOT"/bin/*; do
  link="$HOME/.local/bin/$(basename "$cmd")"
  if [[ -e $link || -L $link ]] && [[ $(readlink -f "$link") != "$cmd" ]]; then
    echo "  skip $(basename "$cmd"): $link exists and isn't ours"
    continue
  fi
  om_run mkdir -p "$HOME/.local/bin"
  om_run ln -sfn "$cmd" "$link"
  echo "  $(basename "$cmd")"
done

echo "== Launcher entries"
# Ptyxis' own entry only raises an open window, so picking Terminal in the
# launcher seems to do nothing. A user-level copy opens a new window instead.
# Marked so uninstall removes only our copy.
ptyxis_desktop=/usr/share/applications/org.gnome.Ptyxis.desktop
ptyxis_override="${XDG_DATA_HOME:-$HOME/.local/share}/applications/org.gnome.Ptyxis.desktop"
if [[ -f $ptyxis_desktop ]]; then
  if [[ -f $ptyxis_override ]] && ! grep -q '^# gnome-omakase' "$ptyxis_override"; then
    echo "  skip Terminal: $ptyxis_override exists and isn't ours"
  else
    # shellcheck disable=SC2016 # awk program, not shell
    om_rewrite "$ptyxis_override" awk '
      NR == 1 { print "# gnome-omakase: opens a new window instead of raising the open one" }
      /^\[/ { main = ($0 == "[Desktop Entry]") }
      main && /^Exec=/ { print "Exec=ptyxis --new-window"; next }
      main && /^DBusActivatable=/ { print "DBusActivatable=false"; next }
      { print }' "$ptyxis_desktop"
    echo "  Terminal opens a new window"
  fi
fi

# Ghostty: borderless, themed. Our lines sit in a marked block so uninstall
# removes exactly them and nothing else in the user's config.
ghostty_config="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
if command -v ghostty > /dev/null && ! grep -q '^# gnome-omakase start' "$ghostty_config" 2> /dev/null; then
  {
    [[ -f $ghostty_config ]] && cat "$ghostty_config"
    echo "# gnome-omakase start"
    echo "window-decoration = false"
    echo "config-file = ?omakase-theme"
    echo "# gnome-omakase end"
  } | om_write "$ghostty_config"
  echo "  Ghostty: borderless, follows the theme"
fi

echo "== Window keys"
# Super+Space becomes the launcher, so input-source switching moves over.
if [[ $(gsettings get org.gnome.desktop.wm.keybindings switch-input-source) == *"'<Super>space'"* ]]; then
  om_gset org.gnome.desktop.wm.keybindings switch-input-source "['<Shift><Super>space', 'XF86Keyboard']"
  om_gset org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift><Super><Alt>space', '<Shift>XF86Keyboard']"
  echo "  <Shift><Super>space  switch input source (was <Super>space)"
fi
if [[ $(gsettings get org.gnome.desktop.wm.keybindings close) != *"'<Super>w'"* ]]; then
  om_gset org.gnome.desktop.wm.keybindings close "['<Super>w', '<Alt>F4']"
  echo "  <Super>w  close window"
fi

# Workspaces on Super+Alt+number: Super+number stays with pinned apps and
# Dash to Panel uses Super+Shift+number.
for n in 1 2 3 4; do
  current=$(gsettings get org.gnome.desktop.wm.keybindings "switch-to-workspace-$n")
  if [[ $current != *"<Super><Alt>$n"* ]]; then
    om_gset org.gnome.desktop.wm.keybindings "switch-to-workspace-$n" "['<Super><Alt>$n']"
    om_gset org.gnome.desktop.wm.keybindings "move-to-workspace-$n" "['<Super><Alt><Shift>$n']"
    echo "  <Super><Alt>$n  workspace $n (add Shift to move the window)"
  fi
done

echo "== Shortcuts"
bin="$HOME/.local/bin"
om_kb_add launcher "Launcher" "$bin/launcher-toggle" "<Super>space"
om_kb_add theme-menu "Theme menu" "$bin/theme-menu" "<Shift><Control><Super>space"
# Ghostty first: it's the borderless one. The others open a new window.
if command -v ghostty > /dev/null; then
  om_kb_add terminal "Terminal" "ghostty" "<Super>Return"
else
  for term in ptyxis gnome-terminal kgx; do
    if command -v "$term" > /dev/null; then
      om_kb_add terminal "Terminal" "$term --new-window" "<Super>Return"
      break
    fi
  done
fi
om_kb_add browser "Browser" "$bin/browser" "<Shift><Super>b"
command -v nautilus > /dev/null && om_kb_add files "Files" "nautilus --new-window" "<Shift><Super>f"

echo "== Extensions"
for ext in "${EXTENSIONS[@]}"; do
  if gnome-extensions info "$ext" > /dev/null 2>&1; then
    echo "  $ext installed"
  elif (( want_extensions )); then
    echo "  $ext: asking GNOME to install it (confirm in the dialog)"
    om_run gdbus call --session --dest org.gnome.Shell.Extensions \
      --object-path /org/gnome/Shell/Extensions \
      --method org.gnome.Shell.Extensions.InstallRemoteExtension "$ext" > /dev/null || true
  else
    echo "  $ext missing: rerun with --extensions, or install it from Extension Manager"
  fi
done

# GNOME's own Workspace Indicator ships in Ubuntu's gnome-shell-extensions
# package, so it's enabled when present rather than downloaded.
indicator=workspace-indicator@gnome-shell-extensions.gcampax.github.com
if gnome-extensions info "$indicator" > /dev/null 2>&1; then
  om_run gnome-extensions enable "$indicator"
  om_gset org.gnome.shell.extensions.workspace-indicator embed-previews false
  echo "  workspace indicator enabled"
else
  echo "  workspace indicator: sudo apt install gnome-shell-extensions, then log in again"
fi

# Load our defaults for each installed extension, one key at a time so
# uninstall can restore every original value.
for file in "$OM_ROOT"/defaults/*.dconf; do
  name=$(basename "$file" .dconf)
  ext=$(printf '%s\n' "${EXTENSIONS[@]}" | grep "^$name@" || true)
  if [[ -z $ext ]] || ! gnome-extensions info "$ext" > /dev/null 2>&1; then
    continue
  fi
  while IFS='=' read -r key value; do
    [[ $key =~ ^[a-z0-9-]+$ ]] || continue
    om_dset "/org/gnome/shell/extensions/$name/$key" "$value"
  done < "$file"
  echo "  $name defaults applied"
done

echo "== Theme"
if [[ -z $theme ]]; then
  theme=$(cat "$OM_STATE/current" 2> /dev/null || echo tokyo-night)
fi
if [[ $OM_DRY_RUN == "1" ]]; then
  "$OM_ROOT/bin/theme-set" --dry-run "$theme"
else
  "$OM_ROOT/bin/theme-set" "$theme"
fi

echo
echo "Done. Super+Space: launcher. Shift+Ctrl+Super+Space: themes. Undo: ./uninstall.sh"
