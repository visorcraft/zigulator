<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Contributing to Zigulator

Thanks for helping improve Zigulator. This is a small Zig desktop
calculator with a GUI-independent core, so changes should stay focused,
tested, and easy to review.

If anything here is unclear or out of date, open an issue or a PR.

## Code of conduct

Be kind, be specific, assume good faith. Disagree about the technical
details, not the person. Public reviews stay focused on the diff.

## How to propose a change

Use the standard **fork → branch → pull request** workflow on GitHub.

1. Fork [`visorcraft/zigulator`](https://github.com/visorcraft/zigulator).
2. Clone your fork and add the upstream remote:

   ```sh
   git clone git@github.com:<you>/zigulator.git
   cd zigulator
   git remote add upstream https://github.com/visorcraft/zigulator.git
   ```

3. Branch from `master` with a descriptive name:

   ```sh
   git fetch upstream
   git switch -c fix-parser-edge-case upstream/master
   ```

4. Make focused commits. One logical change per commit.
5. Open a pull request against `master` and include:
   - what changed,
   - why it changed,
   - exact test commands run,
   - screenshots for visible UI changes,
   - any platform you could not test.

## Project layout

| Path | Role |
| ---- | ---- |
| `src/main.zig` | GLFW / OpenGL startup and render loop |
| `src/core/` | Parsing, formatting, calculator state, history, stats, i18n, prefs |
| `src/core.zig` | Test root that discovers core unit tests |
| `src/ui/` | ImGui shell, widgets, keyboard handling, theme |
| `docs/usage.md` | End-user workflows |
| `packaging/` | Desktop entry, icons, AUR package metadata |

Keep calculator logic in `src/core/` and independent of zgui so it stays
unit-testable. UI code should render and forward events, not reimplement
math or state machines.

## Local development

Zigulator targets **Zig 0.16.0**. A pinned binary may live at
`tools/zig-x86_64-linux-0.16.0/zig`; use that path when `zig` is not on
`PATH`.

```sh
zig version
zig fmt --check build.zig src
zig build test
zig build -Doptimize=ReleaseFast
./zig-out/bin/zigulator
```

Development run:

```sh
zig build run
```

The first build needs network access to fetch the pinned dependencies in
`build.zig.zon`. If a Linux link fails on `.sframe` relocations:

```sh
scripts/gen-crt-nosframe.sh
zig build
```

When changing AUR packaging, regenerate `.SRCINFO`:

```sh
(cd packaging/aur && makepkg --printsrcinfo > .SRCINFO)
```

## What we look for in a review

- The change does one thing and does it well.
- Core behavior changes include a small regression test beside the code.
- UI code stays thin; logic lives in `src/core/`.
- User-visible behavior is documented in `docs/usage.md` or `README.md`
  when it changes.
- No AI/tool attribution in commits, PRs, code, or docs.

## Coding standards

- Accept `zig fmt` output and use four-space indentation.
- Files and enum values: `snake_case`.
- Functions and variables: `camelCase`.
- Public types: `TitleCase`.
- Pass allocators explicitly; pair owned allocations with `deinit`.
- Avoid hidden global state.
- Prefer the standard library and already-pinned dependencies over new
  ones.

## Commit messages

Use clear Conventional Commit-style subjects matching the history:

```text
feat(core): accept hex paste with 0x prefix
fix(ui): restore simple mode from prefs
docs: add security policy
build: bump AUR package to 0.1.1
```

Keep the subject imperative, concise, and without a trailing period. Do
not add AI/tool attribution trailers.

## Security reports

Do not open a public issue for security problems. See
[SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the
same terms as the project: [GPL-3.0-only](LICENSE).
