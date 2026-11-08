#!/usr/bin/env python3
"""Reject tracked path collisions that break on case-insensitive filesystems."""
import subprocess
import sys
import unicodedata

raw = subprocess.check_output(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"])
paths = set(p.decode("utf-8") for p in raw.split(b"\0") if p)
seen = {}
errors = []
for path in sorted(paths):
    parts = path.split("/")
    for i in range(1, len(parts) + 1):
        name = "/".join(parts[:i])
        key = unicodedata.normalize("NFC", name).casefold()
        if key in seen and seen[key] != name:
            errors.append(f"Path collision: {seen[key]} / {name}")
        seen[key] = name
        component = parts[i - 1]
        stem = component.split(".")[0].upper()
        if (component.endswith((".", " ")) or any(c in component for c in '<>:"\\|?*')
                or stem in {"CON", "PRN", "AUX", "NUL", *(f"COM{n}" for n in range(1, 10)), *(f"LPT{n}" for n in range(1, 10))}):
            errors.append(f"Windows-incompatible path: {name}")
if errors:
    print("\n".join(sorted(set(errors))), file=sys.stderr)
    sys.exit(1)
print(f"Checked {len(paths)} files for case and Windows path compatibility.")
