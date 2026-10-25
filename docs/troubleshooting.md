# Troubleshooting

## Dock is missing

```bash
omarchy plugin list --json
omarchy plugin validate ~/.config/omarchy/plugins/dock.okuma.dev
omarchy-shell shell call dock.okuma.dev status ''
quickshell log -p /usr/share/omarchy/shell -t 100
```

Check that the plugin is enabled and Toggle Top Bar is not hiding it. Wait a few
seconds after shell startup before querying IPC. Confirm this is the Quickshell
edition of Omarchy, not Waybar. Restart the shell if a keep-loaded instance is stale.

## Icons are missing

The Python helper scans XDG icon directories asynchronously at startup. A brief
fallback image while it runs is normal. Check helper output and Python availability:

```bash
python3 ~/.config/omarchy/plugins/dock.okuma.dev/index-icons.py
```

Absolute custom icon files must exist. Installed application changes trigger a
rescan; manually replaced icon files may require a shell restart. A bundled SVG
is displayed if an image fails to load. Report persistent failures with the app's
desktop entry, icon name, shell logs, and relevant file paths.

## Focus or close does not work

Confirm the installed Hyprland exposes the required Lua dispatch APIs. This
version does not support legacy-only dispatchers. Include `hyprctl version` and
the shell logs in bug reports. Never paste private window titles without review.

## Two bottom bars

Disable the previous dock, then restart the shell. This plugin does not modify
or automatically disable another plugin. When migrating from a custom dock,
recreate pins or copy only reviewed application definitions; private launcher
commands and usernames are not portable.

## Reporting bugs

Report issues at https://github.com/OKUMARCHY/Dock/issues after publication.
Include Omarchy, Hyprland and Quickshell versions, monitor scale, reproduction
steps, and whether restarting the shell fixes the issue. Cold login and full
machine reboot are separate tests; do not report one as proof of the other.
