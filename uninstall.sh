#!/bin/bash

# Undo install.sh: remove our shortcuts and commands, and put every setting
# we changed back to the value it had before. Extensions stay installed.
# Usage: ./uninstall.sh [--dry-run]

set -euo pipefail

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"
source "$OM_ROOT/lib/apply.sh"
source "$OM_ROOT/lib/keys.sh"

case ${1:-} in
  "") ;;
  --dry-run) OM_DRY_RUN=1 ;;
  -h | --help) sed -n '3,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) om_die "unknown option '$1' (only --dry-run)" ;;
esac

echo "== Shortcuts"
om_kb_remove_all

echo "== Settings"
if [[ -f $OM_PRIOR ]]; then
  # One bad entry must not block the rest, so each restore runs in a
  # subshell and failures are reported, not fatal.
  failed=0
  while IFS=$'\t' read -r kind where key value; do
    if (
      case $kind in
        gsettings)
          om_run gsettings set "$where" "$key" "$value" ;;
        dconf)
          if [[ -z $value ]]; then
            om_run dconf reset "$where/$key"
          else
            om_run dconf write "$where/$key" "$value"
          fi ;;
        herdr)
          [[ -f $where ]] || exit 0
          if [[ -n $value ]]; then
            om_herdr_set_name "$where" "$value"
          else
            # shellcheck disable=SC2016 # awk program, not shell
            om_rewrite "$where" awk '
              /^\[/ { in_theme = ($0 ~ /^\[theme\]/) }
              in_theme && /^name[[:space:]]*=/ { next }
              { print }' "$where"
            om_run herdr server reload-config > /dev/null 2>&1 || true
          fi ;;
        claude)
          [[ -f $where ]] && command -v jq > /dev/null || exit 0
          if [[ -z $value ]]; then
            om_rewrite "$where" jq 'del(.theme)' "$where"
          else
            # shellcheck disable=SC2016 # jq variable, not shell
            om_rewrite "$where" jq --arg theme "$value" '.theme = $theme' "$where"
          fi ;;
      esac
    ); then
      echo "  restored $kind $key"
    else
      echo "  could not restore $kind $where $key (original: $value)" >&2
      failed=1
    fi
  done < "$OM_PRIOR"
  if (( failed )); then
    echo "  Some settings were not restored; prior.tsv is kept so you can retry." >&2
  else
    om_run mv "$OM_PRIOR" "$OM_PRIOR.restored"
  fi
else
  echo "  nothing recorded"
fi

echo "== Files"
for link in "$HOME"/.local/bin/*; do
  if [[ -L $link && $(readlink -f "$link") == "$OM_ROOT"/bin/* ]]; then
    om_run rm "$link"
    echo "  removed $(basename "$link")"
  fi
done
ptyxis_override="${XDG_DATA_HOME:-$HOME/.local/share}/applications/org.gnome.Ptyxis.desktop"
if [[ -f $ptyxis_override ]] && grep -q '^# gnome-omakase' "$ptyxis_override"; then
  om_run rm "$ptyxis_override"
  echo "  removed Terminal launcher override"
fi
while read -r id; do
  palette="${XDG_DATA_HOME:-$HOME/.local/share}/org.gnome.Ptyxis/palettes/omakase-$id.palette"
  if [[ -f $palette ]]; then
    om_run rm "$palette"
  fi
done < <(om_theme_ids)
om_run rm -rf "$OM_STATE/wallpapers" "$OM_STATE/rofi.rasi" "$OM_STATE/current"

echo
echo "Done. Backups kept in $OM_BACKUPS."
echo "Extensions left installed; remove them in Extension Manager if you like."
