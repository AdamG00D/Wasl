**English** | [العربية](CONTRIBUTING.ar.md)

# Contributing to Wasl

Thanks for your interest! The project is small and written so anyone can read and change it. This guide helps your
change get in smoothly.

## Before you start

- Small change (a fix, a UI tweak)? Open a pull request directly.
- New feature or a protocol change? Open an issue first and describe the idea, so you don't spend time on something
  that won't be merged.
- Security issue? **Not here** — see [SECURITY.md](SECURITY.md).

## Setup

```bash
flutter pub get
flutter analyze   # must report: No issues found!
flutter test      # everything must pass
```

You don't need the signing key: the project builds with the debug key without it.

## Rules

**Code**

- UI text lives in `lib/l10n/app_ar.arb` (Egyptian Arabic, the template) and `lib/l10n/app_en.arb` — add every new
  string to both and use it as `context.l10n.key` in widgets or `tr.key` elsewhere; `flutter gen-l10n` regenerates the
  Dart code. Code comments are in Egyptian Arabic, short and friendly. If you can't write Arabic, write the English
  text and say so in the PR — a maintainer will translate. Issues and PRs in English or Arabic are both fine.
- The layout flips between RTL (Arabic) and LTR (English): use `EdgeInsetsDirectional` / `AlignmentDirectional` /
  `PositionedDirectional`, never fixed left / right.
- Colours only through `context.palette`. User messages via `showToast` (not `SnackBar`). Close the keyboard with
  `hideKeyboard()`.
- Line width 120. Don't reformat files your change doesn't touch.
- Avoid new dependencies unless necessary — if you add one, explain why in the PR and give its license (it must be
  compatible with GPL-3.0).

**Privacy (non-negotiable)**

- No internet access at all: no analytics, no crash reporting, nothing sent anywhere.
- Message contents and keys are never logged.
- A conversation is written to disk only if the user enabled saving.

**Protocol**

- The rules live in [docs/PROTOCOL.md](docs/PROTOCOL.md) and are covered by tests. If you change them, update that
  file and add or adjust a test.
- Changing the shape of private-channel packets requires bumping `protocolVersion`, which breaks compatibility with
  older versions — so it needs a strong reason.
- Additive changes that older versions ignore (a new packet kind, a new field) are the preferred way.
- Treat everything from the network as hostile: bound lengths, check types, and never trust a claimed identity
  without proof.

**Tests**

- Mesh, crypto and group logic are tested in `test/` on an in-memory network (`test/support.dart`) — no phones needed.
- For any bug fix: write a test that fails before the fix and passes after it.

## Pull requests

- Branch from `main`, one clear change per PR. Pull requests are squash-merged.
- Commit message: a short sentence saying what changed, and why below it if it isn't obvious.
- In the PR: what changed, how you tested it (tests / real phones and which transport), and a screenshot for UI changes.
- By contributing you agree that your code is released under the project's license (GPL-3.0-or-later).

## Not sure where to start?

- Try the app on different phones and report anything that doesn't work (phone model and Android version matter).
- Translation: the UI is in Arabic and English. Another language means a new `lib/l10n/app_<code>.arb`, adding it to
  `L10n.supported` and `L10n.resolve`, plus `android/app/src/main/res/values-<code>/strings.xml` for notifications.
- The limitations listed in [SECURITY.md](SECURITY.md) — each one is a nice project if you enjoy cryptography.
