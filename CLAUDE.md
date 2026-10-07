## Agent skills

### Issue tracker

GitHub Issues on zzzhushi/eczema-tracking-app, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Short label names: triage, info, agent, human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Development approach

- Docs: `docs/spec.md` (product and lasting decisions), `docs/release-1.md` (the active release), `docs/analysis.md` (formulas and thresholds), `docs/testing.md` (how the app is tested), `CONTEXT.md` (terms). GitHub issues are the source of truth for work: releases are GitHub milestones, and each release milestone (M0, M1, …), backlog outcome, and tabled item is an issue holding its paths, acceptance checks, and open questions. Docs hold what the system does and why.
- A completed release document is frozen; the next active release gets a new file.
- Define a rule once, in the doc that owns it; summaries elsewhere must defer to the owning doc.
- Docs are part of every task: update what a change touches and delete what it makes stale, favoring removal. Close or prune stale GitHub issues the same way.
- Build in vertical slices: each milestone is a thin, working path through every layer, usable on the phone.
- Testing follows `docs/testing.md`: every behavior change starts with a written acceptance check.
- Open questions live in the milestone's GitHub issue. When one is decided, update the owning doc and delete the question. Use an ADR only for a cross-cutting, hard-to-reverse decision.
