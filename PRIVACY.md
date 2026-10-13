# Privacy

Machenike Control runs locally. It has no analytics, telemetry, account login, cloud synchronization or automatic app-usage history.

It stores user-selected application paths and URLs, profile names, key mappings, colors and restoration backups in `~/Library/Application Support/Machenike Control/`. These data stay on the Mac. Opening a web destination launches the configured URL in the user's default browser; the destination then receives the browser's normal request.

The app observes registered hotkeys rather than recording general typing. It reads this keyboard's configuration and macOS shortcut preferences to display their functions. Input Monitoring is used for access to the keyboard's HID interface. Diagnostic output is opt-in with `--diagnostics` and stays in the private app-state directory.

The repository uses a publication allowlist. Personal profiles, hardware captures, downloaded vendor packages, research HTML, diagnostic output, screenshots generated from local state and compiled binaries are excluded. Test fixtures are synthetic. No local account identifiers, home-directory paths, credentials or tokens are needed to build or test the project.
