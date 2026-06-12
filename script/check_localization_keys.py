#!/usr/bin/env python3
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCE_ROOT = ROOT / "NotchMove" / "NotchMove" / "Resources"
LANGUAGES = ["en", "zh-Hans", "zh-Hant", "ja"]
PLACEHOLDER_RE = re.compile(
    r"%(?!%)(?:\d+\$)?[-+#0 ]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|h|ll|l|L|z|j|t)?[@diuoxXfFeEgGcCsSp]"
)


def fail(message: str) -> None:
    print(f"localization check failed: {message}", file=sys.stderr)
    sys.exit(1)


def load_strings(language: str) -> dict[str, str]:
    path = RESOURCE_ROOT / f"{language}.lproj" / "Localizable.strings"
    if not path.exists():
        fail(f"missing localization file: {path.relative_to(ROOT)}")

    result = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(path)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        fail(f"unable to parse {path.relative_to(ROOT)}: {result.stderr.strip()}")

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        fail(f"invalid JSON from plutil for {path.relative_to(ROOT)}: {error}")

    if not isinstance(data, dict):
        fail(f"expected dictionary in {path.relative_to(ROOT)}")

    return {str(key): str(value) for key, value in data.items()}


def placeholders(value: str) -> list[str]:
    return PLACEHOLDER_RE.findall(value)


def main() -> None:
    localizations = {language: load_strings(language) for language in LANGUAGES}
    reference_language = LANGUAGES[0]
    reference_keys = set(localizations[reference_language])

    for language, strings in localizations.items():
        keys = set(strings)
        missing = sorted(reference_keys - keys)
        extra = sorted(keys - reference_keys)
        if missing:
            fail(f"{language} is missing keys: {', '.join(missing[:10])}")
        if extra:
            fail(f"{language} has extra keys: {', '.join(extra[:10])}")

    for key in sorted(reference_keys):
        expected = placeholders(localizations[reference_language][key])
        for language in LANGUAGES[1:]:
            actual = placeholders(localizations[language][key])
            if actual != expected:
                fail(
                    f"placeholder mismatch for key '{key}' in {language}: "
                    f"expected {expected}, found {actual}"
                )

    print(
        "localization check passed: "
        f"{len(reference_keys)} keys across {', '.join(LANGUAGES)}"
    )


if __name__ == "__main__":
    main()
