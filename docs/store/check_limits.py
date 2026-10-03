#!/usr/bin/env python3
"""Check store-listing character limits in docs/store/*.md.

Every limited field in the listing docs is written as:

    <!-- limit:30 id:play-name -->
    ```text
    Pebble Routines: Checklist
    ```

This script finds each marker, takes the fenced block that follows it, and
counts characters exactly as the stores do (Unicode characters, newlines in
multi-line fields count as one character each, no trailing newline).

Keyword fields can add `keywords exclude:<id>,<id>` to the marker. The script
then also checks the Apple keyword rules: comma separated, no spaces, no empty
entries, no duplicates, and no word that already appears in the excluded
fields (for example the app name and subtitle).

Run from the repo root:

    python3 docs/store/check_limits.py

Exit code is 1 if any field is over its limit or breaks a keyword rule.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent
MARKER = re.compile(
    r"<!--\s*limit:(?P<limit>\d+)\s+id:(?P<id>[\w-]+)(?P<rest>[^>]*)-->\s*\n"
    r"```[a-z]*\n(?P<body>.*?)\n```",
    re.S,
)


def words(text: str) -> set[str]:
    return {w for w in re.split(r"[^a-z0-9]+", text.lower()) if w}


def main() -> int:
    fields: dict[str, str] = {}
    entries = []
    for path in sorted(ROOT.glob("*.md")):
        text = path.read_text(encoding="utf-8")
        for match in MARKER.finditer(text):
            field_id = match.group("id")
            if field_id in fields:
                print(f"DUPLICATE ID {field_id} in {path.name}")
                return 1
            body = match.group("body")
            fields[field_id] = body
            entries.append((path.name, field_id, int(match.group("limit")), body, match.group("rest")))

    failed = False
    print(f"{'file':<26} {'field':<34} {'chars':>5} / {'max':<5} status")
    for file_name, field_id, limit, body, rest in entries:
        count = len(body)
        problems = []
        if count > limit:
            problems.append(f"over by {count - limit}")
        if "keywords" in rest:
            if " " in body or "\n" in body:
                problems.append("contains spaces or newlines")
            items = body.split(",")
            if any(not item for item in items):
                problems.append("empty keyword")
            if len(items) != len(set(items)):
                problems.append("duplicate keyword")
            exclude = re.search(r"exclude:([\w,-]+)", rest)
            if exclude:
                taken = set()
                for other in exclude.group(1).split(","):
                    taken |= words(fields.get(other, ""))
                repeats = sorted(set(items) & taken)
                if repeats:
                    problems.append("repeats name/subtitle words: " + ",".join(repeats))
        status = "OK" if not problems else "FAIL (" + "; ".join(problems) + ")"
        failed = failed or bool(problems)
        print(f"{file_name:<26} {field_id:<34} {count:>5} / {limit:<5} {status}")
    print(f"\n{len(entries)} fields checked.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
