#!/usr/bin/env python3
"""Check CMV's three-language string catalog before shipping."""

import json
import pathlib
import re
import sys
from collections import Counter


APP = pathlib.Path(__file__).resolve().parents[1] / "CMV" / "CMV"
LANGUAGES = ("en", "ja", "zh-Hant")
FORMAT = re.compile(r"%(?:([1-9]\d*)\$)?(@|lld|ld|d|\.\d+f|f)")
HELPER = re.compile(
    r'(?:AppLanguage\.localized|cmvLocalized|localizedFormat)\(\s*"((?:\\.|[^"\\])*)"',
    re.S,
)


def read_catalog(name: str) -> dict:
    with (APP / name).open(encoding="utf-8") as handle:
        return json.load(handle)["strings"]


def placeholder_signature(value: str):
    matches = list(FORMAT.finditer(value))
    uses_positions = [match.group(1) is not None for match in matches]
    if any(uses_positions) and not all(uses_positions):
        return None
    return Counter(
        (int(match.group(1)) if match.group(1) else index, match.group(2))
        for index, match in enumerate(matches, start=1)
    )


def main() -> int:
    strings = read_catalog("Localizable.xcstrings")
    problems = []
    for key, entry in strings.items():
        for language in LANGUAGES:
            unit = entry.get("localizations", {}).get(language, {}).get("stringUnit", {})
            value = unit.get("value")
            if not value or unit.get("state") != "translated":
                problems.append(f"{key}: missing {language}")
            elif placeholder_signature(value) != placeholder_signature(key):
                problems.append(f"{key}: {language} placeholders changed")

    for path in APP.glob("*.swift"):
        source = path.read_text(encoding="utf-8")
        for match in HELPER.finditer(source):
            key = match.group(1).replace('\\"', '"')
            if key not in strings:
                line = source.count("\n", 0, match.start()) + 1
                problems.append(f"{path.name}:{line}: missing key {key}")

    display_name = read_catalog("InfoPlist.xcstrings").get("CFBundleDisplayName", {})
    for language in LANGUAGES:
        if not display_name.get("localizations", {}).get(language, {}).get("stringUnit", {}).get("value"):
            problems.append(f"CFBundleDisplayName: missing {language}")

    for problem in problems:
        print(problem, file=sys.stderr)
    print(f"Checked {len(strings)} UI strings and app display name; {len(problems)} problem(s).")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
