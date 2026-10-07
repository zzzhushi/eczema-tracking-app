# eXzema

A personal iPhone app for tracking eczema. It relates what the user eats, applies, and is exposed to against daily ratings and photos of their skin, and surfaces patterns in their own data so they can make better-informed decisions about likely triggers. Everything, including the AI, runs on the phone.

> **Not medical software.** This is a personal tracker. It finds patterns, never diagnoses, and is no substitute for a dermatologist, allergist, or dietitian.

## Status

Building Release 1 (food and skin). Current slice: S1, the foundation.

## Setup

```bash
git config core.hooksPath .githooks
cp Local.xcconfig.example Local.xcconfig   # then set your Apple team ID
xcodegen generate
swift test --package-path Packages/ExzemaCore
```

`Local.xcconfig` and the generated `eXzema.xcodeproj` are git-ignored.

## Constraints

- iPhone 15 Pro or newer on iOS 27, with Apple Intelligence enabled; built with Xcode 27.
- Personal use under a free Apple developer account, so the app is reinstalled from Xcode every 7 days.

## Docs

- [Spec](docs/spec.md): the product and its lasting decisions
- [Analysis rules](docs/analysis.md): formulas, thresholds, and missing-data rules
- [Testing](docs/testing.md): how the app is tested
- [Roadmap](https://github.com/zzzhushi/eczema-tracking-app/milestones): releases as GitHub milestones; slices and future outcomes as issues
- [Glossary](CONTEXT.md): project terms
