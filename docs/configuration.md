# Configuration

The plugin ID is `okuma.dev_dock4omarchy`. Put settings inside its existing `plugins`
entry in Omarchy's shell configuration. Back up the file before editing.

| Setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `menuWidth` | number | 150 | Menu width in logical pixels, minimum 120, capped to screen |
| `pinned` | array | discovered | Ordered application definitions; an empty array means no pins |
| `runningOrder` | string array | empty | Preferred order for unpinned running app keys |

## Pin fields

- `key`: unique stable string used for ordering and IPC.
- `name`: displayed label.
- `desktop`: desktop-entry ID without `.desktop`; used to launch through DesktopEntries.
- `icon`: icon name, absolute file path, or file URL.
- `classes`: lowercase Hyprland application classes, used to group windows.
- `command`: optional argv array; overrides desktop-entry execution. Do not use a shell string.
- `shellPlugin`: optional Omarchy plugin ID to toggle instead of executing a command.
- `payload`: optional JSON object for `shellPlugin`.

`command` and `shellPlugin` are trusted executable configuration. Never import
settings from a source you do not trust. Use absolute paths for custom files;
`~` and `$HOME` are not expanded inside argv arrays or icon paths.

The built-in Applications pin toggles `omarchy.menu` with
`{"initialMenu":"apps"}`. It requires that first-party menu to be enabled.
Disk Usage uses a distinct terminal app ID to avoid grouping with normal terminals.

Find window classes using `hyprctl -j clients`. Application and desktop IDs vary
by distribution and package. If a window appears twice, add its lowercase class
to the intended pin. Avoid assigning the same class to multiple pins.

The browser is discovered via `omarchy-cmd-default-browser`, with XDG fallbacks
that avoid mistaking Omarchy's browser forwarding entry for the real browser.
Files is discovered via `xdg-mime` with a small
installed-file-manager fallback. The editor is matched to Omarchy's saved editor
executable. Applications that cannot be identified are omitted rather than
hardcoding another user's software. The Applications menu is always available.

Drag updates persist via Omarchy's scoped plugin settings API. Running order is
stored independently from pins. New running apps appear after recognized saved
keys. Use `omarchy restart shell` after manually changing defaults or when a
keep-loaded plugin does not update immediately.
