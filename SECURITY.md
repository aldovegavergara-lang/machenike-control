# Security

This is an experimental local macOS keyboard utility, not an official Machenike application. Security checks do not establish that every keyboard revision is compatible.

## Scope and controls

- No network listener, remote-control endpoint, updater, shell command execution or keystroke recorder.
- Launch destinations are revalidated at configuration load, hotkey registration and launch. Only local `.app` bundles and HTTP/HTTPS URLs are accepted. Other file types, other URL schemes, URL credentials and control characters are rejected.
- The only child process in app code is `/usr/bin/hidutil`, invoked with a fixed executable and structured arguments. User text is never interpreted by a shell.
- Hotkeys and mappings have bounded counts, recognized key IDs, duplicate checks and modifier masks. Lighting values are range checked when profiles are decoded.
- App-owned state directories use mode 0700 and new state files use mode 0600. State reads are limited to 2 MiB and reject non-regular files, including symlinks. These controls do not protect against another process with the same user's privileges.
- USB writes are restricted to the studied configuration reports. Feature request/response transactions are serialized, and writes have backups and readback checks. Firmware and bootloader updates are excluded.

## Known limitations

The application is locally signed, not notarized. macOS Input Monitoring may need to be renewed after rebuilding. A saved Fn shortcut can still register its Carbon handler while USB readback is blocked; the UI keeps USB validation pending.

The reserved F13–F20 hotkeys are global. Another keyboard emitting the same key and modifiers can trigger the configured app or URL. Fn restoration on exit requires USB permission. A same-user process can modify app data, replace the binary or operate the keyboard directly; that is outside the local input-validation boundary.

Destination URLs and application paths remain in local profiles because they are necessary for the configured shortcuts. Choose trusted apps and destinations. No profile-import or remote-management API is exposed.

## Checks

Run `./scripts/test.sh` on macOS. It performs offline protocol and adversarial configuration tests with synthetic fixtures. It does not send USB writes or open external apps/sites. See [the review record](Docs/security-review.md) for tested cases and publication checks.

If you find a vulnerability, contact the repository owner privately through GitHub if possible. Do not include real credentials, personal profiles or raw keyboard captures in a public issue.
