#!/usr/bin/env python3
"""Print a readable markdown review table from a data file.

Usage: python3 scripts/review_table.py data/rubric/v1.json

The output is for pull request descriptions only and is never committed.
"""
import json
import sys


def rubric_table(rubric, sources):
    names = {s["id"]: s for s in sources}
    lines = [f"**Rubric version {rubric['version']}**, scale {rubric['scale']['min']}–{rubric['scale']['max']}", "",
             "| Sign | 0 | 1 | 2 | 3 |", "|---|---|---|---|---|"]
    for sign in rubric["signs"]:
        lv = sign["levels"]
        lines.append(f"| {sign['name']} | {lv['0']} | {lv['1']} | {lv['2']} | {lv['3']} |")
    lines += ["", rubric["unscored"], "", "Sources:"]
    for ref in rubric["sources"]:
        s = names[ref["sourceId"]]
        authors = s["authors"][0].split(",")[0] + (" et al." if len(s["authors"]) > 1 else "")
        lines.append(f"- {ref['relationship']}: {authors} ({s['year']}), {s['journal']}, [{s['doi']}]({s['url']})"
                     + (f" — {ref['note']}" if ref.get("note") else ""))
    return "\n".join(lines)


if __name__ == "__main__":
    path = sys.argv[1]
    data = json.load(open(path))
    sources = json.load(open("data/sources.json"))
    if "signs" in data:
        print(rubric_table(data, sources))
    else:
        sys.exit(f"No renderer for {path}")
