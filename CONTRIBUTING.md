# Contributing to nocterm_file_color

Thank you for your interest in contributing! This document explains how to
set up the project, run the checks, and submit changes.

## Code of Conduct

By participating in this project you agree to uphold a respectful,
collaborative environment. Be kind, be constructive, and assume good faith.

## Reporting bugs

Before filing a new issue, please search existing issues to avoid
duplicates. A good bug report includes:

- A short summary and the affected version (`pubspec.yaml` `version:`)
- Steps to reproduce (minimal snippet preferred)
- Expected vs. actual behavior
- Terminal/OS and Nocterm version (`nocterm` in `pubspec.yaml`)

## Suggesting features

Open an issue describing the use case and the proposed API. For anything
touching the public API or architecture, please discuss first — this package
follows the rules in [`AGENTS.md`](AGENTS.md), including the hard rule that
it depends **only on Nocterm's stable public APIs** (no `package:nocterm/src/*`
imports).

## Development setup

```bash
git clone https://github.com/AmidVoshakul/nocterm_file_color.git
cd nocterm_file_color
dart pub get
```

Requirements: Dart SDK `^3.13.4` (see `pubspec.yaml` `environment`).

## Running checks

```bash
dart format .            # format
dart analyze             # static analysis
dart test               # all tests
```

For coverage:

```bash
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info \
  --packages=.dart_tool/package_config.json --report-on=lib
```

The core + layout line coverage must stay **≥ 80%** (see `AGENTS.md`).

## Pull requests

1. Fork the repo and create a branch from `main`.
2. Keep changes focused — one concern per PR.
3. Add or update tests for new behavior; do not weaken existing tests.
4. If you changed the public API, update `README.md` and `CHANGELOG.md`
   (under `## Unreleased`).
5. Ensure `dart format .`, `dart analyze`, and `dart test` all pass.
6. Write a clear commit message (conventional style preferred:
   `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`).
7. Open the PR against `main` and fill in the template.

## Style guidelines

- Follow the existing code style; run `dart format .` before committing.
- Prefer early returns and small functions; avoid comments that restate code.
- No emojis in code or commits unless explicitly requested.
- Only public Nocterm APIs (`TextField`, `TextStyle`, `Color`, `RichText`,
  `TextSpan`, `InlineSpan`, `SingleChildScrollView`, `ScrollController`, …).

## Testing

- Unit tests live in `test/` (e.g. `test/prompt_history_test.dart`).
- Widget tests use `testNocterm` from `package:nocterm`.
- Coverage-driven: regressions found via coverage gaps are real bugs —
  test the edge case, don't just chase the percentage.

## Release process (maintainers)

1. Update `pubspec.yaml` `version:` and add a `## X.Y.Z` section to `CHANGELOG.md`.
2. Commit, then `git tag -a vX.Y.Z -m 'Release X.Y.Z' && git push origin vX.Y.Z`.
3. The `release.yml` workflow publishes the GitHub release from the changelog
   section; `pub.dev` publish is manual (`dart pub publish`).

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).