# Troubleshooting

## Dock is missing

```bash
omarchy plugin list --json
omarchy plugin validate ~/.config/omarchy/plugins/okuma.dev_dock4omarchy
omarchy-shell shell call okuma.dev_dock4omarchy status ''
quickshell log -p /usr/share/omarchy/shell -t 100
```

Check that the plugin is enabled and Toggle Top Bar is not hiding it. This dock
only appears on tiling (`dwindle`) and scrolling workspaces; floating mode uses
Omarchy's built-in dock. The `status` response includes each screen's workspace,
detected mode, and visibility. An empty mode means detection is pending or failed.
Check `omarchy-hyprland-workspace-layout-current <workspace-id>` if it stays empty.
Named and special workspaces are not supported. Wait a few
seconds after shell startup before querying IPC. Confirm this is the Quickshell
edition of Omarchy, not Waybar. Restart the shell if a keep-loaded instance is stale.

## Icons are missing

The Python helper scans XDG icon directories asynchronously at startup. A brief
fallback image while it runs is normal. Check helper output and Python availability:

```bash
python3 ~/.config/omarchy/plugins/okuma.dev_dock4omarchy/index-icons.py
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

Keep Omarchy's built-in dock enabled for floating mode. This plugin hides there
and releases its bottom reservation automatically (allow up to one polling cycle,
750 ms, for same-workspace mode changes). Disable other third-party bottom docks
if they duplicate the panel. This plugin does not modify system layout commands
or automatically disable another plugin. Use only reviewed application definitions;
private launcher commands and usernames are not portable.

## Reporting bugs

Report issues at https://github.com/Okumai/Dock/issues after publication.
Include Omarchy, Hyprland and Quickshell versions, monitor scale, reproduction
steps, and whether restarting the shell fixes the issue. Cold login and full
machine reboot are separate tests; do not report one as proof of the other.
