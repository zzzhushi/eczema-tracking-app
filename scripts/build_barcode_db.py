#!/usr/bin/env python3
"""Build the offline barcode database bundled with eXzema.

Food: pulls the most-scanned product codes from Open Food Facts' search
service (which supports popularity sort), then resolves names/ingredients in
batches via the v2 API. Beauty: pages through Open Beauty Facts directly.
Writes a compact JSON map of barcode -> {n: name, b: brand, i: ingredients}.

The app never talks to these APIs at runtime — this script runs on a dev
machine, and the result ships inside the app bundle so lookups stay fully
offline.

Usage: python3 scripts/build_barcode_db.py [output.json]
Re-run any time to refresh or enlarge the slice (bump the targets below).
"""
import json
import sys
import time
import urllib.request

USER_AGENT = "eXzema-build-script/0.1 (github.com/zzzhushi/eczema-tracking-app)"

FOOD_TARGET = 2000
BEAUTY_TARGET = 1000
SEARCH_DELAY_SECONDS = 6.5  # OFF search API rate limit is 10 req/min


def fetch(url, attempts=4):
    for attempt in range(attempts):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except Exception as error:
            if attempt == attempts - 1:
                raise
            wait = 15 * (attempt + 1)
            print(f"  retrying in {wait}s ({error})", file=sys.stderr)
            time.sleep(wait)


def keep(db, product):
    code = (product.get("code") or "").strip()
    name = product.get("product_name") or ""
    if isinstance(name, list):  # search-a-licious returns lists for some fields
        name = name[0] if name else ""
    name = name.strip()
    ingredients = (product.get("ingredients_text_en") or product.get("ingredients_text") or "").strip()
    if not code or not name or len(ingredients) < 10 or code in db:
        return False
    brands = product.get("brands") or ""
    if isinstance(brands, list):
        brands = brands[0] if brands else ""
    db[code] = {"n": name, "b": brands.split(",")[0].strip(), "i": ingredients}
    return True


def build_food(db):
    """Top codes by popularity from search-a-licious, resolved via the v2 API."""
    codes = []
    page = 1
    while len(codes) < FOOD_TARGET * 1.5 and page <= 40:
        url = (
            "https://search.openfoodfacts.org/search"
            f"?page={page}&page_size=100&sort_by=-unique_scans_n&fields=code"
        )
        hits = fetch(url).get("hits", [])
        if not hits:
            break
        codes += [h["code"] for h in hits if h.get("code")]
        print(f"[food] collected {len(codes)} popular codes")
        page += 1
        time.sleep(2)

    kept = 0
    for start in range(0, len(codes), 100):
        if kept >= FOOD_TARGET:
            break
        chunk = ",".join(codes[start:start + 100])
        url = (
            "https://world.openfoodfacts.org/api/v2/search"
            f"?code={chunk}&page_size=100"
            "&fields=code,product_name,brands,ingredients_text,ingredients_text_en"
        )
        for product in fetch(url).get("products", []):
            if keep(db, product):
                kept += 1
        print(f"[food] resolved {kept}/{FOOD_TARGET}")
        time.sleep(2)


def build_beauty(db):
    kept = 0
    page = 1
    while kept < BEAUTY_TARGET and page <= 30:
        url = (
            "https://world.openbeautyfacts.org/api/v2/search"
            f"?page={page}&page_size=100"
            "&fields=code,product_name,brands,ingredients_text,ingredients_text_en"
            "&states_tags=en:ingredients-completed"
        )
        products = fetch(url).get("products", [])
        if not products:
            break
        for product in products:
            if keep(db, product):
                kept += 1
                if kept >= BEAUTY_TARGET:
                    break
        print(f"[beauty] page {page}: kept {kept}/{BEAUTY_TARGET}")
        page += 1
        time.sleep(SEARCH_DELAY_SECONDS)


def main(out_path):
    db = {}
    build_food(db)
    build_beauty(db)
    with open(out_path, "w") as f:
        json.dump(db, f, ensure_ascii=False, separators=(",", ":"))
    print(f"Wrote {len(db)} products to {out_path}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "eXzema/Resources/BarcodeDB.json")
