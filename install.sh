#!/bin/bash

# Install desktop-kit for the current user. No sudo, nothing outside $HOME.
# Usage: ./install.sh [--dry-run] [--extensions] [--theme <id>]
#   --extensions  ask GNOME to install Tactile and Focus changer from
#                 extensions.gnome.org (GNOME shows a confirmation for each)
#   --theme       theme to apply (default: tokyo-night, or keep the current one)

set -euo pipefail

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"
source "$DK_ROOT/lib/apply.sh"
source "$DK_ROOT/lib/keys.sh"

want_extensions=0
theme=""
while (( $# > 0 )); do
  case $1 in
    --dry-run) DK_DRY_RUN=1 ;;
    --extensions) want_extensions=1 ;;
    --theme)
      [[ -n ${2:-} ]] || dk_die "--theme needs a theme id"
      theme=$2
      shift ;;
    -h | --help) sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) dk_die "unknown option '$1'" ;;
  esac
  shift
done

EXTENSIONS=(tactile@lundal.io focus-changer@heartmire)

echo "== Checks"
[[ ${XDG_CURRENT_DESKTOP:-} == *GNOME* ]] || dk_die "needs a GNOME session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})"
for cmd in gsettings dconf; do
  command -v "$cmd" > /dev/null || dk_die "missing '$cmd'"
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
backup="$DK_BACKUPS/gnome-$(date +%Y%m%d-%H%M%S).dconf"
if [[ $DK_DRY_RUN == "1" ]]; then
  echo "dry-run: dconf dump /org/gnome/ > $backup"
else
  mkdir -p "$DK_BACKUPS"
  dconf dump /org/gnome/ > "$backup"
  echo "  $backup"
fi

echo "== Commands in ~/.local/bin"
for cmd in "$DK_ROOT"/bin/*; do
  link="$HOME/.local/bin/$(basename "$cmd")"
  if [[ -e $link || -L $link ]] && [[ $(readlink -f "$link") != "$cmd" ]]; then
    echo "  skip $(basename "$cmd"): $link exists and isn't ours"
    continue
  fi
  dk_run mkdir -p "$HOME/.local/bin"
  dk_run ln -sfn "$cmd" "$link"
  echo "  $(basename "$cmd")"
done

echo "== Window keys"
# Super+Space becomes the launcher, so input-source switching moves over.
if [[ $(gsettings get org.gnome.desktop.wm.keybindings switch-input-source) == *"'<Super>space'"* ]]; then
  dk_gset org.gnome.desktop.wm.keybindings switch-input-source "['<Shift><Super>space', 'XF86Keyboard']"
  dk_gset org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift><Super><Alt>space', '<Shift>XF86Keyboard']"
  echo "  <Shift><Super>space  switch input source (was <Super>space)"
fi
if [[ $(gsettings get org.gnome.desktop.wm.keybindings close) != *"'<Super>w'"* ]]; then
  dk_gset org.gnome.desktop.wm.keybindings close "['<Super>w', '<Alt>F4']"
  echo "  <Super>w  close window"
fi

echo "== Shortcuts"
bin="$HOME/.local/bin"
dk_kb_add launcher "Launcher" "$bin/launcher-toggle" "<Super>space"
dk_kb_add theme-menu "Theme menu" "$bin/theme-menu" "<Shift><Control><Super>space"
for term in ptyxis gnome-terminal kgx; do
  if command -v "$term" > /dev/null; then
    dk_kb_add terminal "Terminal" "$term --new-window" "<Super>Return"
    break
  fi
done
for browser in google-chrome firefox chromium; do
  if command -v "$browser" > /dev/null; then
    dk_kb_add browser "Browser" "$browser --new-window" "<Shift><Super>b"
    break
  fi
done
command -v nautilus > /dev/null && dk_kb_add files "Files" "nautilus --new-window" "<Shift><Super>f"

echo "== Extensions"
for ext in "${EXTENSIONS[@]}"; do
  if gnome-extensions info "$ext" > /dev/null 2>&1; then
    echo "  $ext installed"
  elif (( want_extensions )); then
    echo "  $ext: asking GNOME to install it (confirm in the dialog)"
    dk_run gdbus call --session --dest org.gnome.Shell.Extensions \
      --object-path /org/gnome/Shell/Extensions \
      --method org.gnome.Shell.Extensions.InstallRemoteExtension "$ext" > /dev/null || true
  else
    echo "  $ext missing: rerun with --extensions, or install it from Extension Manager"
  fi
done

# Load our defaults for each installed extension, one key at a time so
# uninstall can restore every original value.
for file in "$DK_ROOT"/defaults/*.dconf; do
  name=$(basename "$file" .dconf)
  ext=$(printf '%s\n' "${EXTENSIONS[@]}" | grep "^$name@" || true)
  [[ -n $ext ]] && gnome-extensions info "$ext" > /dev/null 2>&1 || continue
  while IFS='=' read -r key value; do
    [[ $key =~ ^[a-z0-9-]+$ ]] || continue
    dk_dset "/org/gnome/shell/extensions/$name/$key" "$value"
  done < "$file"
  echo "  $name defaults applied"
done

echo "== Theme"
if [[ -z $theme ]]; then
  theme=$(cat "$DK_STATE/current" 2> /dev/null || echo tokyo-night)
fi
if [[ $DK_DRY_RUN == "1" ]]; then
  "$DK_ROOT/bin/theme-set" --dry-run "$theme"
else
  "$DK_ROOT/bin/theme-set" "$theme"
fi

echo
echo "Done. Super+Space: launcher. Shift+Ctrl+Super+Space: themes. Undo: ./uninstall.sh"
