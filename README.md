# gnome-omakase

My take on Omarchy, for people who'd rather keep Ubuntu.

I like what [Omarchy](https://omarchy.org) gets right: keyboard first, one theme across everything, no fiddling. I didn't like it enough to leave Ubuntu and GNOME behind. So this is my cut: the feel, on the desktop I already run, with every change reversible.

Tested on Ubuntu 26.04, GNOME 50.

## Keys

| Keys | Does |
|---|---|
| `Super+Space` | Launch apps |
| `Shift+Ctrl+Super+Space` | Switch theme |
| `Super+Return` / `Shift+Super+B` / `Shift+Super+F` | Terminal (borderless Ghostty if installed) / browser / files |
| `Super+W` | Close window |
| `Super+T`, then two tiles | Tile the window: 2x2 grid on a laptop, 4x2 on an external screen |
| `Ctrl+Super+Arrow` | Focus the window on that side |
| `Super+Alt+1-4` | Go to workspace (add `Shift` to take the window); the panel shows which one you're on |
| `Shift+Super+Space` | Switch keyboard layout (moved from `Super+Space`) |

For the workspace keys, set a fixed number of workspaces in GNOME Settings > Multitasking.

The browser shortcut opens your default browser. Change it, and other default apps, in GNOME Settings > Apps > Default Apps.

One theme switch covers GNOME, the terminal (Ghostty and Ptyxis), Herdr, Claude Code, the launcher, the tiling grid and the wallpaper. Twelve themes: Paper (e-ink calm), Catppuccin Mocha and Latte, Tokyo Night, Kanagawa, Nord, Everforest, Rose Pine Dawn, Gruvbox and Gruvbox Light, Matte Black, White.

## Install

```bash
git clone https://github.com/irfan-devart/gnome-omakase.git && cd gnome-omakase
sudo apt install rofi jq gnome-shell-extensions ghostty   # then log out and in once
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

Add a theme in `~/.config/gnome-omakase/themes/<id>/theme.toml` (copy one from `themes/`); put a `background.svg`, `.jpg` or `.png` next to it to give it its own wallpaper. To use your own wallpaper with any theme, drop it in `~/.config/gnome-omakase/backgrounds/<id>/`.

## Limits

GNOME doesn't auto-tile like Hyprland: Tactile places windows, Focus changer moves between them. The launcher runs through XWayland, so press its key again to close it. A running Claude Code session shows a new theme after a restart.

## Credits

[Omarchy](https://omarchy.org) for the idea, [Omabuntu](https://github.com/omakasui/omabuntu) for the Ubuntu groundwork and the theme palettes (Catppuccin, Tokyo Night, Kanagawa, Nord, Everforest, Rosé Pine, Gruvbox and others, each MIT by their authors). MIT licence.
