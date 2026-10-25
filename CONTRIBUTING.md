# Contributing

Plugin IDs follow `<plugin-name>.okuma.dev`, and manifest authors use `ŌKUMA`.
This project's plugin ID is `dock.okuma.dev`. Keep runtime IDs, examples, and
management commands synchronized with the manifest. The GitHub organization
and repository URL remain `OKUMARCHY/Dock`.

Keep source code, comments, documentation, issue templates, and test fixtures in
English. Do not commit personal settings, home-directory paths, or private window
titles. Use Python's standard library for helpers; avoid additional runtime dependencies.

Run the unit tests and `omarchy plugin validate .` before submitting changes.

## Manual desktop checklist

- Cold shell startup: icons appear after indexing; no persistent blanks.
- Full login/reboot: test separately from shell restart.
- Browser, Files, editor, Applications, and optional Disk Usage launch correctly.
- Existing windows focus across workspaces without moving the cursor.
- Multiple windows show a clickable selection menu; outside click dismisses it.
- Menu fits at 150 logical pixels; long titles are elided.
- Pin/unpin and left-drag sorting persist after shell restart.
- Dragging never triggers application launch; separator boundaries remain intact.
- Overflow wheel scrolling and edge dragging work.
- Theme changes update bar, popup and text colors live.
- Toggle Top Bar hides both bars and releases reservations.
- Multiple monitors and different scale factors preserve logical geometry.
- Missing optional applications do not break startup.

Document the exact tested Omarchy, Quickshell and Hyprland versions. Do not
claim compatibility with unsupported versions or compositors.
