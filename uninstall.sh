#!/bin/bash

# Undo install.sh: remove our shortcuts and commands, and put every setting
# we changed back to the value it had before. Extensions stay installed.
# Usage: ./uninstall.sh [--dry-run]

set -euo pipefail

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"
source "$DK_ROOT/lib/apply.sh"
source "$DK_ROOT/lib/keys.sh"

[[ ${1:-} == "--dry-run" ]] && DK_DRY_RUN=1

echo "== Shortcuts"
dk_kb_remove_all

echo "== Settings"
if [[ -f $DK_PRIOR ]]; then
  # Newest first, so a setting changed twice ends on its oldest value.
  while IFS=$'\t' read -r kind where key value; do
    case $kind in
      gsettings)
        dk_run gsettings set "$where" "$key" "$value" ;;
      dconf)
        if [[ -z $value ]]; then
          dk_run dconf reset "$where/$key"
        else
          dk_run dconf write "$where/$key" "$value"
        fi ;;
      herdr)
        [[ -f $where && -n $value ]] && dk_herdr_set_name "$where" "$value" ;;
      claude)
        if [[ -f $where ]]; then
          if [[ -z $value ]]; then
            jq 'del(.theme)' "$where" | dk_write "$where"
          else
            jq --arg theme "$value" '.theme = $theme' "$where" | dk_write "$where"
          fi
        fi ;;
    esac
    echo "  restored $kind $key"
  done < <(tac "$DK_PRIOR")
  dk_run mv "$DK_PRIOR" "$DK_PRIOR.restored"
else
  echo "  nothing recorded"
fi

echo "== Files"
for link in "$HOME"/.local/bin/*; do
  if [[ -L $link && $(readlink -f "$link") == "$DK_ROOT"/bin/* ]]; then
    dk_run rm "$link"
    echo "  removed $(basename "$link")"
  fi
done
for palette in "${XDG_DATA_HOME:-$HOME/.local/share}"/org.gnome.Ptyxis/palettes/dk-*.palette; do
  [[ -f $palette ]] && dk_run rm "$palette"
done
dk_run rm -rf "$DK_STATE/wallpapers" "$DK_STATE/rofi.rasi" "$DK_STATE/current"

echo
echo "Done. Backups kept in $DK_BACKUPS."
echo "Extensions left installed; remove them in Extension Manager if you like."
