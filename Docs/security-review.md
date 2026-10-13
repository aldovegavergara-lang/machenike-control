# Local security review — 2026-10-13

Scope: Swift source, launch destinations, persisted configuration, hotkey routing, HID message boundaries, private-file handling and the exact Git publication tree. This is a local adversarial code review with executable tests, not an independent external penetration-test certification.

## Findings corrected

1. Persisted launch targets could bypass picker validation and reach `NSWorkspace.open` with an unsafe scheme or a non-app file. Validation now runs on decode, registration and immediately before launch.
2. Persisted lighting values and mapping data lacked complete validation. Oversized or invalid values could crash UI arithmetic or request unsupported mappings. They are now bounded and checked before use.
3. App-owned files used default filesystem permissions, and normal state reads were unbounded. Direct state files now reject symlinks, enforce owner-only storage and have a 2 MiB read limit.
4. USB message sending assumed trusted nonempty input. Outbound messages now enforce exact sizes and an allowlist of studied commands. Transactions are serialized to prevent request/response interleaving within the app.
5. A diagnostic app-launch history was written automatically. That logging was removed. Diagnostic snapshots remain opt-in and local.
6. The working directory mixed code with local research and captures. Publication now uses an explicit file allowlist, synthetic test fixtures and a privacy scan of Git-tracked files.

## Executed validation

The security suite covers 547 checks, including rejected target schemes, embedded URL credentials, control characters, hostile profile integers, duplicate/unknown HID mappings, invalid hotkeys, malformed matrix/report sizes, all 253 unexpected six-byte request opcodes, 256 Fn-selector values, filesystem permissions, symlink rejection and oversized state files.

The five other offline suites check RGB byte preservation, destination persistence, current/pending configuration labels, Fn matrix edits and hotkey registration. Tests do not write the keyboard or launch external destinations. The app is built separately with Swift.

Before upload, the allowlisted Git tree is exported and scanned with Gitleaks and the publication privacy checker. Findings must be resolved before pushing. Scanner reports and local research are not committed.

## Residual risks

Compatibility has been studied for one revision. Local signing and macOS Input Monitoring remain deployment limitations. Hotkeys are global, and another keyboard can emit their reserved signals. Same-user malware and malicious keyboard firmware are outside this review. No external service or firmware flashing was tested.

## Result

All six local suites passed, including 547 adversarial security checks. The Swift app build and staged whitespace checks passed. Gitleaks 8.30.1 found no secrets in the exported publication tree, and the publication privacy checker accepted 29 text files. Raw captures, user profiles and downloaded packages are not part of that tree. These results apply to the checked source and the stated local threat model; they are not a guarantee of absence of vulnerabilities.
