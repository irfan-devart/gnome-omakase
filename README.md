# gnome-omakase

My take on Omarchy, for people who'd rather keep Ubuntu.

I like what [Omarchy](https://omarchy.org) gets right: keyboard first, one theme across everything, no fiddling. I didn't like it enough to leave Ubuntu and GNOME behind. So this is my cut: the feel, on the desktop I already run, with every change reversible.

Tested on Ubuntu 26.04, GNOME 50.

## Keys

| Keys | Does |
|---|---|
| `Super+Space` | Launch apps |
| `Shift+Ctrl+Super+Space` | Switch theme |
| `Super+Return` / `Shift+Super+B` / `Shift+Super+F` | Terminal / browser / files |
| `Super+W` | Close window |
| `Super+T`, then two tiles | Tile the window |
| `Ctrl+Super+Arrow` | Focus the window on that side |
| `Super+Alt+1-4` | Go to workspace (add `Shift` to take the window) |

One theme switch covers GNOME, the terminal (Ptyxis), Herdr, Claude Code, the launcher, the tiling grid and the wallpaper. Themes: Tokyo Night, Gruvbox, Gruvbox Light.

## Install

```bash
git clone https://github.com/irfan-devart/gnome-omakase.git && cd gnome-omakase
sudo apt install rofi jq
./install.sh --dry-run        # see every change first
./install.sh --extensions     # then do it
```

`--extensions` asks GNOME to install [Tactile](https://extensions.gnome.org/extension/4548/tactile/) and [Focus changer](https://extensions.gnome.org/extension/4627/focus-changer/). GNOME confirms each one with you.

## Undo

```bash
./uninstall.sh
```

Every setting goes back to what it was before install. Your own shortcuts are left alone.

## Safe by design

- No sudo, no `curl | bash`, no third-party repos. Nothing leaves your home folder.
- Original values are recorded before the first change; config edits are atomic and never leave a file half-written.
- Theme files are validated, so a theme can't run commands. `--dry-run` everywhere.

## Make it yours

Add a theme in `~/.config/gnome-omakase/themes/<id>/theme.toml` (copy one from `themes/`). Drop a wallpaper in `~/.config/gnome-omakase/backgrounds/<id>/`.

## Limits

GNOME doesn't auto-tile like Hyprland: Tactile places windows, Focus changer moves between them. The launcher runs through XWayland, so press its key again to close it.

## Credits

[Omarchy](https://omarchy.org) for the idea, [Omabuntu](https://github.com/omakasui/omabuntu) for the Ubuntu groundwork. Palettes: [Gruvbox](https://github.com/morhetz/gruvbox) and [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme), both MIT. MIT licence.
