#!/bin/bash

# Checks that need no GNOME session changes: syntax, theme validation,
# dry runs, and the Herdr config edit. Run from anywhere: test/run.sh

set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0

check() {
  local name=$1
  shift
  if "$@" > "$tmp/out" 2>&1; then
    echo "ok    $name"
  else
    echo "FAIL  $name"
    sed 's/^/      /' "$tmp/out"
    fails=$((fails + 1))
  fi
}

refuses() {
  ! "$@"
}

# Run the kit against a throwaway state folder.
export XDG_STATE_HOME="$tmp/state" XDG_CONFIG_HOME="$tmp/config"

# Guard: tests may read GNOME settings but never change them. Any write
# through gsettings or dconf fails, so a broken test can't touch the desktop.
mkdir -p "$tmp/shim"
for tool in gsettings dconf; do
  real=$(command -v "$tool" || true)
  {
    echo '#!/bin/bash'
    echo 'case $1 in'
    echo "  get | list-keys | list-recursively | read | dump | list) exec \"$real\" \"\$@\" ;;"
    echo "  *) echo \"test guard: blocked $tool \$1\" >&2; exit 99 ;;"
    echo 'esac'
  } > "$tmp/shim/$tool"
  chmod +x "$tmp/shim/$tool"
done
export PATH="$tmp/shim:$PATH"

for f in "$root"/bin/* "$root"/lib/*.sh "$root"/*.sh "$root"/test/*.sh; do
  check "syntax $(basename "$f")" bash -n "$f"
done

if command -v shellcheck > /dev/null; then
  check "shellcheck" shellcheck -x -e SC1091 "$root"/bin/* "$root"/*.sh "$root"/test/*.sh
else
  echo "skip  shellcheck (not installed)"
fi

for dir in "$root"/themes/*/; do
  check "dry run $(basename "$dir")" "$root/bin/theme-set" --dry-run "$(basename "$dir")"
done

check "refuses path in theme id" refuses "$root/bin/theme-set" --dry-run "../etc"
check "refuses unknown theme" refuses "$root/bin/theme-set" --dry-run "no-such-theme"

bad="$XDG_CONFIG_HOME/desktop-kit/themes/bad"
mkdir -p "$bad"
sed 's/^background = .*/background = "red; rm -rf ~"/' "$root/themes/tokyo-night/theme.toml" > "$bad/theme.toml"
check "refuses non-colour value" refuses "$root/bin/theme-set" --dry-run bad
sed 's/^gnome_accent = .*/gnome_accent = "neon"/' "$root/themes/tokyo-night/theme.toml" > "$bad/theme.toml"
check "refuses unknown GNOME accent" refuses "$root/bin/theme-set" --dry-run bad

# Herdr: name inside [theme] changes, a name in another table doesn't.
herdr_case() {
  local input=$1 expected=$2
  printf '%b' "$input" > "$tmp/herdr.toml"
  (
    source "$root/lib/common.sh"
    source "$root/lib/apply.sh"
    herdr() { :; }
    dk_herdr_set_name "$tmp/herdr.toml" "tokyo-night"
  )
  [[ $(cat "$tmp/herdr.toml") == "$(printf '%b' "$expected")" ]]
}
check "herdr replaces name" herdr_case \
  '[theme]\nname = "x"\n[keys]\nname = "y"\n' '[theme]\nname = "tokyo-night"\n[keys]\nname = "y"'
check "herdr adds name" herdr_case \
  '[theme]\nauto_switch = false\n' '[theme]\nname = "tokyo-night"\nauto_switch = false'
check "herdr adds table" herdr_case \
  'onboarding = false\n' 'onboarding = false\n\n[theme]\nname = "tokyo-night"'

check "herdr header with comment" herdr_case \
  '[theme] # mine\nname = "x"\n' '[theme] # mine\nname = "tokyo-night"'

# A failed jq must leave the file untouched, never empty it.
broken_json() {
  printf '{ "theme": "dark", }\n' > "$tmp/settings.json"
  (
    source "$root/lib/common.sh"
    dk_rewrite "$tmp/settings.json" jq '.theme = "x"' "$tmp/settings.json"
  ) 2> /dev/null && return 1
  [[ $(cat "$tmp/settings.json") == '{ "theme": "dark", }' ]]
}
check "failed jq leaves file intact" broken_json

# Writes go through symlinks instead of replacing them.
through_symlink() {
  printf 'a\n' > "$tmp/real.txt"
  ln -sf "$tmp/real.txt" "$tmp/link.txt"
  ( source "$root/lib/common.sh"; printf 'b\n' | dk_write "$tmp/link.txt" )
  [[ -L $tmp/link.txt && $(cat "$tmp/real.txt") == "b" ]]
}
check "writes through symlinks" through_symlink

uri_encoding() {
  local out
  out=$( source "$root/lib/common.sh"; source "$root/lib/apply.sh"; dk_uri_path "/home/a b/50%.svg" )
  [[ $out == "/home/a%20b/50%25.svg" ]]
}
check "wallpaper path is URI-encoded" uri_encoding

check "uninstall rejects unknown option" refuses "$root/uninstall.sh" --dryrun
check "install rejects --theme without id" refuses "$root/install.sh" --dry-run --theme

check "guard blocks desktop writes" refuses gsettings set org.gnome.desktop.interface accent-color blue

check "dry run writes nothing" test ! -e "$tmp/state/desktop-kit/current"

echo
if (( fails > 0 )); then
  echo "$fails failed"
  exit 1
fi
echo "all passed"
