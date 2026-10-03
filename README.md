# desktop-kit

Omarchy's keyboard-first feel on stock Ubuntu GNOME, without replacing GNOME.

One key opens apps, one key switches the theme across the whole desktop, and windows tile from the keyboard. Every change is recorded and `./uninstall.sh` puts your desktop back the way it was.

Built and tested on Ubuntu 26.04 with GNOME 50.

## What you get

| Keys | Does |
|---|---|
| `Super+Space` | App launcher (rofi). Press again to close |
| `Shift+Ctrl+Super+Space` | Theme menu |
| `Super+Return` | Terminal |
| `Shift+Super+B` | Browser |
| `Shift+Super+F` | Files |
| `Super+W` | Close window (`Alt+F4` still works) |
| `Super+T`, then two tiles | Place the window on a grid (Tactile) |
| `Ctrl+Super+Arrow` | Move focus to the window on that side (Focus changer) |

Keyboard layout switching moves from `Super+Space` to `Shift+Super+Space`.

A theme switch changes, in one step: GNOME light or dark and accent colour, the Ptyxis terminal palette, the Herdr theme, the Claude Code theme, the launcher, the wallpaper and the tiling grid colours. Apps you don't have are skipped.

Themes: Tokyo Night, Gruvbox, Gruvbox Light.

## Install

```bash
git clone https://github.com/irfan-devart/desktop-kit.git
cd desktop-kit
./install.sh --dry-run      # see every change first
./install.sh --extensions   # install, and ask GNOME for the two extensions
```

Recommended packages: `sudo apt install rofi jq`. Without them the launcher and the Claude Code theme are skipped.

`--extensions` asks GNOME Shell to install [Tactile](https://extensions.gnome.org/extension/4548/tactile/) and [Focus changer](https://extensions.gnome.org/extension/4627/focus-changer/) from extensions.gnome.org. GNOME shows its own confirmation for each one. You can also install them yourself from Extension Manager; the kit only ships their settings.

## Uninstall

```bash
./uninstall.sh --dry-run
./uninstall.sh
```

Your shortcuts, commands, palettes and every setting the kit changed go back to their earlier values. Your own shortcuts are left alone. Extensions stay installed.

Two things to know:
- A setting goes back to its value from before install, even if you changed it yourself since (say, the accent colour or wallpaper).
- Run uninstall from the same folder you installed from. If you move the repo first, its commands in `~/.local/bin` are left behind as broken links.

## Safety

- No sudo, no `curl | bash`, no third-party apt repositories. Everything stays in your home folder.
- Config edits are atomic and never write an empty file: if `jq` or `awk` fails, the file is left as it was. Symlinked dotfiles are written through, not replaced, and file modes are kept.
- Settings that don't exist on your GNOME version are skipped, not half-applied.
- Every setting's original value is recorded before the first change (`~/.local/state/desktop-kit/prior.tsv`), and a full `dconf dump` is taken at install.
- Theme files are validated before anything is applied: colours must be `#rrggbb`, names and ids follow strict patterns, so a theme can't inject commands.
- `--dry-run` on install, uninstall and `theme-set` prints every change without making it.

## Your own themes and wallpapers

- **Theme:** copy a folder from `themes/` to `~/.config/desktop-kit/themes/<id>/` and edit `theme.toml`.
- **Wallpaper:** put an image in `~/.config/desktop-kit/backgrounds/<theme-id>/`. Without one, a wallpaper is generated from the theme's palette.

## Known limits

- rofi runs through XWayland, because GNOME doesn't support the layer-shell protocol rofi's Wayland mode needs. It opens as a normal window so GNOME gives it keyboard focus, so it doesn't close itself when you click away; press the shortcut again.
- GNOME has no automatic tiling like Hyprland. Tactile places windows; Focus changer moves between them.

## Tests

```bash
test/run.sh
```

## Credits

Inspired by [Omarchy](https://omarchy.org) and [Omabuntu](https://github.com/omakasui/omabuntu). The Gruvbox and Tokyo Night palettes are taken from Omabuntu's theme files (MIT per its README); the original colour schemes are [Gruvbox](https://github.com/morhetz/gruvbox) by Pavel Pertsev and [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) by enkia, both MIT. Licence: MIT.
