# Contributing

This project's plugin ID is `okuma.dev_dock4omarchy`, and the manifest author is `ŌKUMA`.
Keep runtime IDs, examples, and management commands synchronized with the manifest.
The canonical repository is `https://github.com/Okumai/Dock`.

Read [docs/publication.md](docs/publication.md) before uploading code or submitting
to a marketplace. Run all checks locally; this repository has no hosted workflows.

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
- Cycle tiling -> scrolling -> floating -> tiling on the same workspace: this
  dock only shows in the first two; the built-in dock remains enabled for floating.
- Floating mode closes open menus, releases focus grabs, cancels drags, and
  releases this dock's bottom reservation within one polling cycle (750 ms).
- Mixed modes on multiple monitors are handled independently; fast workspace
  switches and config reloads never apply stale mode-query results.
- Failed or missing mode queries leave the dock hidden rather than conflicting.
- Missing optional applications do not break startup.

Document the exact tested Omarchy, Quickshell and Hyprland versions. Do not
claim compatibility with unsupported versions or compositors.
