#!/usr/bin/env python3
"""Check that Hush's translations are complete.

- Every key in the app's String Catalogs (Localizable.xcstrings and
  InfoPlist.xcstrings) has a translated, non-empty value for every supported
  language, and any value whose English text names "Hush" keeps that name.
- Every App Store listing locale under docs/app-store/metadata/ has all the
  listing fields, within App Store Connect's length limits.

Run from anywhere: python3 scripts/check_localizations.py
Exits non-zero and lists every problem if anything is missing.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGS = [
    ROOT / "Hush/Hush/Localizable.xcstrings",
    ROOT / "Hush/Hush/InfoPlist.xcstrings",
]
LANGUAGES = ["de", "es", "fr", "it", "ja", "ko", "pt-BR", "zh-Hans"]

METADATA = ROOT / "docs/app-store/metadata"
STORE_LOCALES = ["en-US", "de-DE", "es-ES", "fr-FR", "it", "ja", "ko", "pt-BR", "zh-Hans"]
# Field file name -> App Store Connect character limit.
STORE_FIELDS = {
    "name": 30,
    "subtitle": 30,
    "promotional_text": 170,
    "description": 4000,
    "keywords": 100,
    "release_notes": 4000,
}


def check_catalog(path):
    problems = []
    strings = json.loads(path.read_text(encoding="utf-8"))["strings"]
    if not strings:
        problems.append(f"{path.name}: catalog has no keys")
    for key, entry in strings.items():
        if entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})
        for lang in LANGUAGES:
            unit = localizations.get(lang, {}).get("stringUnit")
            if unit is None:
                problems.append(f"{path.name}: {key!r} has no {lang} translation")
                continue
            value = unit.get("value", "")
            if unit.get("state") != "translated" or not value.strip():
                problems.append(f"{path.name}: {key!r} {lang} is not translated")
            elif "Hush" in key and "Hush" not in value:
                problems.append(f"{path.name}: {key!r} {lang} drops the name Hush")
    return problems


def check_metadata():
    problems = []
    for locale in STORE_LOCALES:
        for field, limit in STORE_FIELDS.items():
            path = METADATA / locale / f"{field}.txt"
            if not path.is_file():
                problems.append(f"metadata: {locale}/{field}.txt is missing")
                continue
            text = path.read_text(encoding="utf-8").strip()
            if not text:
                problems.append(f"metadata: {locale}/{field}.txt is empty")
            elif len(text) > limit:
                problems.append(f"metadata: {locale}/{field}.txt is {len(text)} characters (limit {limit})")
    return problems


def main():
    problems = []
    for catalog in CATALOGS:
        problems += check_catalog(catalog)
    problems += check_metadata()
    for problem in problems:
        print(problem)
    if problems:
        sys.exit(1)
    print(f"OK: {len(CATALOGS)} catalogs x {len(LANGUAGES)} languages, {len(STORE_LOCALES)} App Store locales")


if __name__ == "__main__":
    main()
