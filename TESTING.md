# Running & Testing eXzema

## Prerequisites

- Xcode 26 or newer (the app targets iOS 26).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) only if you add/remove files or edit `project.yml` (`brew install xcodegen`, then `xcodegen generate`). The generated `eXzema.xcodeproj` is committed, so for normal development you don't need it.

## Run on your Mac (simulator)

The easy way:

1. `open eXzema.xcodeproj`
2. Pick any iPhone simulator as the run destination (top toolbar, e.g. "iPhone 17 Pro").
3. Press **⌘R**.

Or entirely from the terminal:

```sh
xcodebuild build -project eXzema.xcodeproj -scheme eXzema \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; open -a Simulator
APP=$(find ~/Library/Developer/Xcode/DerivedData -path "*eXzema*Debug-iphonesimulator/eXzema.app" | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.zzzhushi.eXzema
```

**What doesn't work in the simulator:**

- The **label scanner** (Check tab and Add Product) — there's no camera. You'll see the built-in "Scanner unavailable" fallback; use paste/typing instead.
- The **on-device AI** usually falls back to rule-based assessments. (On an Apple-silicon Mac with Apple Intelligence enabled in macOS System Settings, the simulator may be able to use the model — the Insights tab's "On-device AI" section tells you which mode you're in.)

Everything else — logging, products, flares, photos (use the simulator's built-in photo library), insights, rule-based product checks — works fully in the simulator.

## Run on your iPhone

One-time setup:

1. **Add your Apple ID to Xcode** (if you haven't): Xcode → Settings → Accounts → "+". A free Apple ID is enough; you don't need the paid developer program to run on your own phone.
2. **Pick your team**: open the project, select the **eXzema** target → *Signing & Capabilities* → check *Automatically manage signing* → choose your Personal Team. If signing complains the bundle ID is taken, change it to something unique (e.g. `com.zzzhushi.eXzema2`).
3. **Enable Developer Mode on the phone**: Settings → Privacy & Security → Developer Mode → on, then restart the phone. (The toggle only appears after the phone has been connected to Xcode once.)
4. **Connect the iPhone via cable**, unlock it, and tap "Trust This Computer".

Then every time: select your iPhone as the run destination in Xcode and press **⌘R**. After the first install with a free account, approve the app on the phone under Settings → General → VPN & Device Management.

Notes:

- **Free-account apps expire after 7 days** — the app stays installed but stops launching; just run it from Xcode again to refresh. The paid program ($99/yr) removes this and would be needed for TestFlight/App Store anyway.
- **For the AI features** you need an Apple Intelligence–capable iPhone (15 Pro or newer) with Apple Intelligence enabled (Settings → Apple Intelligence & Siri). The Insights tab shows the exact status and what to do if the model isn't available. On any other phone, the app transparently uses rule-based assessments.
- If you regenerate the project with `xcodegen generate`, your team selection is wiped (it lives in the pbxproj). To make it stick, add your team ID under the eXzema target in `project.yml`:
  ```yaml
  settings:
    base:
      DEVELOPMENT_TEAM: YOURTEAMID
  ```
  (Find the ID in Xcode → Settings → Accounts → your team, or in the Signing pane after selecting it once.)

## Automated tests

Unit tests cover the correlation engine, the ingredient parser, and allergen matching:

```sh
xcodebuild test -project eXzema.xcodeproj -scheme eXzema \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Or **⌘U** in Xcode. They run in a few seconds; all should pass before any commit.

## Manual test scenarios

The automated tests cover the math; these cover the experience. The **10-minute happy path** first — it exercises every screen:

### Happy path (simulator or phone)

1. **Products tab** → add "MI Cream", category Skincare, ingredients: `Aqua, Methylisothiazolinone, Glycerin`. Expect: footer says "3 ingredients detected"; after saving, the detail view shows *methylisothiazolinone* with an orange **Known allergen** badge and a note.
2. Add a second product "Plain Balm" with `Petrolatum, Glycerin`.
3. **Today tab** → "Log products used" → select both → Add. Expect both listed under today.
4. Today tab → "Log today's weather" → fill in anything → Save. Expect it shown in the Environment section.
5. Today tab → "Log a flare-up" → severity 7, pick areas, add 1–2 photos, toggle POEM on and answer the 7 questions, save. Expect: POEM total updates as you answer.
6. **Flares tab** → open the flare. Expect: photos render, POEM and severity shown, and *methylisothiazolinone* appears under "Suspected triggers" with a red **Your trigger?** badge (same-day exposure counts — the window is flare day minus 3 days). Your weather entry appears under "Environment in that window".
7. **Insights tab** → expect *methylisothiazolinone* ranked as a likely trigger ("Preceded 1 of 1 flares"), and the "On-device AI" section showing your device's AI status.
8. **Check tab** → paste `Water, Oxybenzone, Fragrance, Shea Butter` → expect *benzophenone-3* (oxybenzone's INCI name) and *fragrance* flagged as known allergens. Tap "Check against my history" → expect a **Caution** (or higher) verdict with suggestions. Header says "(on-device AI)" on an Apple Intelligence phone, "(rule-based)" otherwise.

### Scenarios worth covering beyond the happy path

**Data & persistence**

- [ ] Force-quit the app and relaunch — everything you logged is still there.
- [ ] Delete a product that has logged usage — its exposures disappear from Today and Insights recalculates (the detail view warns about this).
- [ ] Swipe-to-delete an exposure on the Today tab.
- [ ] Log a flare and **Cancel** instead of saving — the photos you attached are cleaned up (no orphan files).

**Engine edge cases**

- [ ] A product with an empty ingredient list — detail view says "No ingredients recorded", nothing crashes.
- [ ] Messy ingredient input: `Ingredients: AQUA (WATER); parfum • glycerin, glycerin` — should parse to 3 deduplicated ingredients (water, fragrance, glycerin).
- [ ] A flare with **no** exposures in the prior 3 days — flare detail shows the "no exposures logged" message instead of suspects.
- [ ] Backdate a flare (date picker) to before your exposures — it should *not* count those exposures as suspects.
- [ ] Insights with several flares: an ingredient used daily (e.g. glycerin in both products) ranks **below** one used only right before flares.

**Privacy (the whole point — verify it)**

- [ ] Add flare photos, then check the Apple Photos app — they must NOT appear there.
- [ ] Turn on **Airplane Mode** and use every feature — nothing should break or behave differently. The app makes zero network calls.

**Phone-only**

- [ ] **Scanner**: Check tab → "Scan ingredient label" → point at any real product's INCI list → tap a few text lines → "Use" → they land in the text field and parse. Also try a barcode (it captures the number — offline lookup is a roadmap item).
- [ ] Camera permission: first scan asks for camera access; deny it once and confirm the app doesn't crash, then re-allow in Settings.
- [ ] **AI on**: with Apple Intelligence enabled, run a product check — verdict header should say "(on-device AI)" and the summary should reference only ingredients actually in your list/history (it's instructed not to invent facts — call out anything fabricated).
- [ ] **AI off**: toggle Apple Intelligence off in Settings → the same check should silently fall back to "(rule-based)" and Insights should explain why.

### Known limitations to keep in mind while testing

- Exposures can only be logged **for today** — you can't backfill "I used X last Tuesday" yet. (Flares *can* be backdated.)
- Weather is tracked but not yet part of the trigger scoring.
- Barcode scans capture the code but don't look up ingredients (offline Open Food Facts bundle is on the roadmap).
