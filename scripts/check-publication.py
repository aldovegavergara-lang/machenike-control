#!/usr/bin/env python3
"""Inspect Git-tracked publication files without printing secret values."""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
files = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
allowed = {
    ".gitignore", "README.md", "SECURITY.md", "PRIVACY.md",
    "scripts/build.sh", "scripts/test.sh", "scripts/check-publication.py",
    *[f"Tests/{name}.swift" for name in (
        "ProtocolTests", "TargetTests", "ConfigurationTests", "OnboardKeysTests",
        "FnShortcutTests", "SecurityTests", "TestFixtures")],
}
patterns = [
    re.compile("/" + "Users" + r"/[^/\s]+/"),
    re.compile(r"(?i)auth_key=\d{6,}-"),
    re.compile(r"(?i)BEGIN [A-Z ]*PRIVATE KEY"),
    re.compile(r"\b(?:ghp_|gho_|github_pat_)[A-Za-z0-9_]{20,}"),
    re.compile(r"(?i)(?:api_key|access_token|password)\s*[:=]\s*[\"'][^\"']{8,}"),
]
failures = []
for name in filter(None, files):
    path = root / name
    if name not in allowed and not (name.startswith("Sources/") and name.endswith(".swift")) and not (name.startswith("Docs/") and name.endswith(".md")):
        failures.append((name, "not in publication allowlist"))
        continue
    if path.is_symlink():
        failures.append((name, "symlink"))
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeError, OSError):
        failures.append((name, "non-text or unreadable file"))
        continue
    for number, line in enumerate(text.splitlines(), 1):
        emails = re.findall(r"\b[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})\b", line)
        private_email = any(domain.lower() not in {"example.com", "example.org", "example.net"} for domain in emails)
        if private_email or any(pattern.search(line) for pattern in patterns):
            failures.append((f"{name}:{number}", "possible private data"))
for path, reason in failures:
    print(f"FAIL {path}: {reason}")
if failures:
    sys.exit(1)
print(f"PASS publication privacy: {len(list(filter(None, files)))} text files checked")
