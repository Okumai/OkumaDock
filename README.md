# OkumarchyDock

A compact, full-width application dock for Omarchy's Quickshell desktop.

Project: https://github.com/Okumai/Dock

Author: ŌKUMA | Plugin ID: `okuma.dev_dock4omarchy`

## Features

- Centered application icons on a bottom bar matching the active bar's height and font.
- Live Omarchy theme colors and synchronized top-bar visibility.
- Per-monitor visibility only on tiling (`dwindle`) and scrolling workspaces;
  floating workspaces keep Omarchy's built-in dock.
- Automatic discovery of the default browser, file manager, and configured editor.
- Applications automatically prefers an enabled OkumarchyLaunchpad plugin, with a built-in Omarchy menu fallback; no private script is required.
- Optional Disk Usage launcher when `dua` and `xdg-terminal-exec` are installed.
- Running application grouping across workspaces, activity indicators, and window selection.
- Left-drag sorting, persistent pins, right-click actions, and wheel overflow scrolling.
- A 150-logical-pixel context menu by default.
- Direct icon-file indexing to avoid Qt icon-theme lookup failures after login.
- Window focus without permanently changing compositor cursor settings.

## Compatibility

This is an **Omarchy plugin**, not a standalone Arch Linux dock. It requires:

- Omarchy's Quickshell-based shell with schema-version-1 plugins, keep-loaded panels,
  the shared `qs.Commons` theme, and `PluginShellApi.updateEntryInline`.
- Hyprland with the Lua API: `hyprctl eval`, `hl.get_config`, `hl.config`,
  `hl.dsp.focus`, and `hl.dsp.window.close`.
- Quickshell with QtQuick, Io, Hyprland, Wayland, and DesktopEntries support.
- Python 3 and `xdg-utils`.
- Omarchy's `omarchy-hyprland-workspace-layout-current` command for reliable
  tiling, scrolling, and floating mode detection.

The development system uses Quickshell `0.3.2.r7.g2b4501a`. Compatibility is
API-based: no minimum Omarchy release is claimed without a broader test matrix.
Older Waybar-based Omarchy desktops and legacy Hyprland dispatch-only releases
are not supported. Other compositors are not supported.

All project-authored code and documentation are English. Desktop-entry names
and window titles supplied by installed applications may use any language.

## Installation

After this repository is published:

```bash
omarchy plugin add https://github.com/Okumai/Dock.git --enable
```

Review the source before enabling: shell plugins run unsandboxed as your user.
Keep Omarchy's built-in dock enabled: it handles floating workspaces, while this
plugin handles tiling and scrolling. Disable other third-party bottom docks to
avoid duplicate panels and reservations.

For a local checkout, copy the repository to the standard plugin directory:

```bash
mkdir -p ~/.config/omarchy/plugins
cp -a /path/to/OkumarchyDock ~/.config/omarchy/plugins/okuma.dev_dock4omarchy
omarchy plugin validate ~/.config/omarchy/plugins/okuma.dev_dock4omarchy
omarchy-shell shell rescanPlugins
omarchy plugin enable okuma.dev_dock4omarchy
omarchy restart shell
```

Do not overwrite an existing installation with `cp`; use a clean target or the
normal plugin update command. No packaged Omarchy files need modification.

## Controls

| Gesture | Action |
| --- | --- |
| Left click | Focus one window, choose among multiple windows, or launch |
| Middle click / Shift + left click | Launch another instance |
| Right click | Window list, launch, pin/unpin, close a single window |
| Left drag horizontally | Reorder within the pinned or running section |
| Mouse wheel | Scroll overflowing icons |
| Toggle Top Bar | Hide/show both the bar and dock |

Dragging across the separator does not implicitly pin or unpin an application.
The insertion line shows the drop position. Only mapped graphical windows count
as running applications. Tray-only processes do not appear.

## Configuration

Settings live in your plugin entry in `~/.config/omarchy/shell.json` (or the
corresponding `XDG_CONFIG_HOME` directory). Preserve all other shell settings.
See [docs/configuration.md](docs/configuration.md) and
[examples/plugin-settings.json](examples/plugin-settings.json).

Defaults are discovered at shell startup. Once you reorder or pin/unpin an app,
the resulting `pinned` list becomes explicit and persists. Remove that setting
and restart the shell to rediscover defaults. Changing your default applications
does not silently replace explicitly saved pins.

## Launchpad integration across devices

Update this Dock and [OkumarchyLaunchpad](https://github.com/Okumai/Launchpad), then
run Launchpad's `install.sh` on every device to enable it and validate native gestures.
The Dock chooses the responding plugin at click time, so either installation order
works. When Launchpad is missing/disabled it opens the built-in Applications menu.
Saved default Applications pins and legacy `/home/user/.local/bin/launchpad toggle`
pins work without copying that user's script. Other custom commands are untouched.

A portable Applications pin uses `"launcher": true`. Set `launcherPlugin` to
`auto` (default), `okuma.dev_launchpad4omarchy` (require it), or `omarchy.menu`
(always use the built-in menu). See [configuration](docs/configuration.md).
Dock does not read raw touchpad input: pinch registration belongs to Hyprland and
the Launchpad installer. No additional input permissions or gesture daemon is needed.

## Management

```bash
omarchy plugin disable okuma.dev_dock4omarchy
omarchy plugin enable okuma.dev_dock4omarchy
omarchy plugin update okuma.dev_dock4omarchy
omarchy restart shell
omarchy-shell shell call okuma.dev_dock4omarchy status ''
```

Git-managed plugin updates require installation through `omarchy plugin add`.
See [docs/troubleshooting.md](docs/troubleshooting.md) for diagnostics.

## Uninstall

Back up any pins or settings you want to reuse, then run:

```bash
omarchy plugin disable okuma.dev_dock4omarchy
omarchy plugin remove okuma.dev_dock4omarchy
```

The removal command asks for confirmation and rescans plugins. It supports both
Git-managed installations and local copies in the standard plugin directory;
local copies are moved to a hidden backup by Omarchy. A checkout elsewhere is
not removed. Do not delete `shell.json`: it contains unrelated desktop settings.
Removal is not a secure erasure of saved settings or backups. Keep Omarchy's
built-in dock enabled; no packaged files or compositor configuration need restoring.

## Development

```bash
python3 -m unittest discover -s tests -v
omarchy plugin validate .
python3 discover-apps.py
python3 index-icons.py
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the manual desktop test checklist.
This repository has no GitHub Actions workflows; tests run locally on your own device.
See [source publication and local testing](docs/publication.md).

## Limitations

No magnification, thumbnails, automatic hiding, or cross-section drag pinning.
Each screen follows its own active workspace. The dock appears only in tiling
(`dwindle`) and scrolling modes, never in floating mode or while mode detection
is unavailable. Mode changes are checked every 750 ms and after config reloads;
there can be a brief handover delay. Hidden docks release bottom reservations,
close menus, and cancel drags. Named and special workspaces are not supported.
Fullscreen stacking is controlled by Hyprland. Application class matching is
heuristic and may require explicit `classes` overrides, especially for shared
terminal classes or apps with unusual desktop IDs. Theme-based icon recoloring
is not implemented; application artwork retains its own colors. The icon index
prefers user icons and standard hicolor application artwork, not every possible
icon-theme inheritance rule.

## License

MIT. See [LICENSE](LICENSE).
