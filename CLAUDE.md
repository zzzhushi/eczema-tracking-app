## Agent skills

### Issue tracker

GitHub Issues on zzzhushi/eczema-tracking-app, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Short label names: triage, info, agent, human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Development approach

- Docs: `docs/spec.md` (product and lasting decisions), `docs/release-1.md` (active requirements and milestones), `docs/analysis.md` (the only place formulas and thresholds live), `docs/backlog.md` (later releases), `CONTEXT.md` (terms). Update the one doc that owns a rule; never restate it elsewhere.
- Build in vertical slices: each milestone is a thin, working path through every layer, usable on the phone.
- Every behavior change starts with a written acceptance check. Automate it at the highest stable seam (the analysis as a pure computation over day records) when possible; otherwise record a manual check on the iPhone. Prototypes are exempt.
- Test names state the behavior; each test lists the requirement IDs it verifies.
- Open questions live in the milestone's GitHub issue. When one is decided, update the owning doc and delete the question. Use an ADR only for a cross-cutting, hard-to-reverse decision.
- Health data is always marked private in logs.
