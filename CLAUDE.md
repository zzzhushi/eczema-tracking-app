## Agent skills

### Issue tracker

GitHub Issues on zzzhushi/eczema-tracking-app, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Short label names: triage, info, agent, human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Development approach

- **Ownership.** Behavior docs own merged behavior, issues own proposed changes, and the spec and analysis rules own durable principles and rules. Other artifacts may summarize or verify a rule but must defer to its canonical owner. A decision about unbuilt behavior stays in its issue until the implementation pull request updates the behavior doc.
  - `docs/spec.md`: durable product intent, principles, constraints, safety, privacy, non-functional requirements.
  - `docs/behavior/*.md`: current behavior by stable capability, one short file each, created in the pull request that first ships that capability. No IDs, no release labels.
  - `docs/analysis.md`: formulas, thresholds, and missing-data rules, including provisional ones for later releases.
  - `docs/testing.md`: how the app is tested, and the definition of done.
  - Tests and fixtures: executable examples and edge cases; tests are named by behavior.
  - Slice issues: the proposed change, open questions, and end-to-end acceptance.
  - `docs/adr/`: cross-cutting, hard-to-reverse decisions.
  - Reference data files: the actual food lists and levels.
  - `CONTEXT.md`: terms.
- Vocabulary: a **release** is a GitHub milestone; a **slice** is a thin end-to-end issue within a release (S0, S1, …); a **future outcome** is a brief issue for a later release that becomes slices when that release is planned. Tabled items are issues with the `tabled` label.
- Update the behavior docs in the same pull request as the code, and delete what the change makes stale. Close or prune stale issues the same way.
- Define a rule once, in the doc that owns it; summaries elsewhere defer to it.
- Build in vertical slices: each slice is a thin, working path through every layer, usable on the phone.
- Testing follows `docs/testing.md`: every behavior change starts with a written acceptance check.
- Open questions live in the slice's issue. When one is decided, update the owning doc and tick the question. Use an ADR only for a cross-cutting, hard-to-reverse decision.
