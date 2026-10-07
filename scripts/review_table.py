#!/usr/bin/env python3
"""Print a readable markdown review table from a data file.

Usage: python3 scripts/review_table.py data/rubric/v1.json
       python3 scripts/review_table.py data/catalog

The output is for pull request descriptions only and is never committed.
"""
import glob
import json
import os
import sys


def rubric_table(rubric, sources):
    names = {s["id"]: s for s in sources}
    lines = [f"**Rubric version {rubric['version']}**, scale {rubric['scale']['min']}–{rubric['scale']['max']}", "",
             "| Sign | 0 | 1 | 2 | 3 |", "|---|---|---|---|---|"]
    for sign in rubric["signs"]:
        lv = sign["levels"]
        lines.append(f"| {sign['name']} | {lv['0']} | {lv['1']} | {lv['2']} | {lv['3']} |")
    lines += ["", rubric["scoring"], "", rubric["unscored"]]
    for sign in rubric["signs"]:
        if sign.get("lookFor"):
            lines += ["", f"{sign['name']}, look for: {sign['lookFor']}"]
    lines += ["", "Sources:"]
    refs = [(None, ref) for ref in rubric["sources"]]
    refs += [(sign["name"], ref) for sign in rubric["signs"] for ref in sign.get("sources", [])]
    for sign_name, ref in refs:
        s = names[ref["sourceId"]]
        authors = s["authors"][0].split(",")[0] + (" et al." if len(s["authors"]) > 1 else "")
        scope = f" ({sign_name})" if sign_name else ""
        lines.append(f"- {ref['relationship']}{scope}: {authors} ({s['year']}), {s['journal']}, [{s['doi']}]({s['url']})"
                     + (f" — {ref['note']}" if ref.get("note") else ""))
    return "\n".join(lines)


KIND_ORDER = ["measurement", "review", "guidance", "list"]
KIND_CODE = {"measurement": "M", "review": "R", "guidance": "G", "list": "L"}
LEVEL_SHORT = {"negligible": "negl", "low": "low", "moderate": "mod", "high": "high", "very high": "v.high"}
CHEMICALS = ["salicylates", "oxalates", "amines", "histamine", "glutamates", "nickel"]
STATUS_SHORT = {"sources-conflict": "conflict", "researched-no-data": "no data", "not-yet-researched": "not yet"}


def match_tier(evidence):
    """0 for the exact food in the exact form, 1 for a converted form, 2 for a related food."""
    if evidence.get("foodMatch") == "related":
        return 2
    return 1 if evidence.get("formMatch") == "converted" else 0


def catalog_cell(assessment):
    result = assessment["result"]
    if result["kind"] == "unknown":
        return STATUS_SHORT[result["reason"]]
    evidence = assessment["evidence"]
    closest = min(match_tier(e) for e in evidence)
    deciding = [e for e in evidence if match_tier(e) == closest]
    strongest = min(KIND_ORDER.index(e["kind"]) for e in deciding)
    stand_in = "*" if closest else ""
    return f"{LEVEL_SHORT[result['level']]} {KIND_CODE[KIND_ORDER[strongest]]}{stand_in}"


def catalog_table(directory):
    foods = [json.load(open(path)) for path in sorted(glob.glob(os.path.join(directory, "foods", "*.json")))]
    lines = ["| Food | Serving | " + " | ".join(c.capitalize() for c in CHEMICALS) + " |", "|---|---|" + "---|" * len(CHEMICALS)]
    for food in foods:
        serving = food["serving"]["description"] if food.get("serving") else "none"
        cells = " | ".join(catalog_cell(food["chemicals"][c]) for c in CHEMICALS)
        lines.append(f"| {food['name']} | {serving} | {cells} |")
    lines += ["", "The letter after each level is the strongest evidence behind it: M measurement, R review, G guidance, L list.",
              "An asterisk means the deciding evidence is a converted form or a related food."]
    return "\n".join(lines)


if __name__ == "__main__":
    path = sys.argv[1]
    sources = json.load(open("data/sources.json"))
    if os.path.isdir(path):
        print(catalog_table(path))
        sys.exit(0)
    data = json.load(open(path))
    if "signs" in data:
        print(rubric_table(data, sources))
    else:
        sys.exit(f"No renderer for {path}")
