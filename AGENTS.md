# Repository Guidelines

## Project Structure & Module Organization

| Path | Role |
| ---- | ---- |
| `src/main.zig` | GLFW/OpenGL startup and render loop |
| `src/core/` | Parsing, formatting, engine state, history, stats, i18n, prefs (no zgui) |
| `src/core.zig` | Test root that imports every core module |
| `src/ui/` | ImGui shell, widgets, keyboard, theme, window icon |
| `docs/usage.md` | End-user workflows |
| `CREDITS.md` / `THIRD_PARTY_LICENSES.md` | Dependency acknowledgements and license texts |
| `packaging/` | Desktop entry, icons, AUR `PKGBUILD` |
| `scripts/` | Screenshot capture; Linux CRT `.sframe` workaround generator |

Keep calculator logic in `src/core/` so it stays unit-testable without the GUI.
UI code should render and forward events only. `imgui.ini` is generated local
UI state and must stay untracked. `scripts/gen-crt-nosframe.sh` writes ignored
files under `tools/` when a Linux link fails on `.sframe` relocations.

## Build, Test, and Development Commands

Use Zig **0.16.0**. A pinned binary may exist at
`tools/zig-x86_64-linux-0.16.0/zig`.

- `zig build` — compile and install `zig-out/bin/zigulator`
- `zig build run` — build and launch
- `zig build test` — run GUI-independent core tests
- `zig build -Doptimize=ReleaseFast` — optimized release binary
- `zig fmt --check build.zig src` — formatting check (drop `--check` to apply)

Dependencies are pinned in `build.zig.zon` (zgui, zglfw, zopengl) and fetched on
first build. If linking fails on Linux with `.sframe` relocation errors:

```bash
scripts/gen-crt-nosframe.sh
zig build
```

When changing AUR packaging, regenerate `.SRCINFO`:

```bash
(cd packaging/aur && makepkg --printsrcinfo > .SRCINFO)
```

## Coding Style & Naming Conventions

Accept `zig fmt` output; four-space indentation. Files and enum values:
`snake_case`. Functions and variables: `camelCase`. Public types: `TitleCase`.
Pass allocators explicitly, pair owned allocations with `deinit`, and avoid
hidden global state. Prefer the standard library and already-pinned
dependencies over new ones.

## Testing Guidelines

Use `std.testing`. Place focused `test "behavior description"` blocks beside
the code they cover; `src/core.zig` discovers them. Add regression tests for
parser edge cases, engine state, formatting, localization, and errors. No
numeric coverage gate. For UI changes, run the app and manually check the
affected window, keyboard path, and layout.

## Dependencies & Attribution

Direct Zig packages: **zgui** (Dear ImGui + ImPlot), **zglfw** (GLFW),
**zopengl**. After changing pins in `build.zig.zon`, update `CREDITS.md` and
`THIRD_PARTY_LICENSES.md` (versions, revisions, license texts). There are no
npm packages or Cargo crates in this repository.

## Commit & Pull Request Guidelines

Use concise Conventional Commit-style prefixes from history, e.g.
`feat(core):`, `feat(ui):`, `fix(ui):`, `docs:`, `build:`. One logical change
per commit; imperative lowercase subject, no trailing period. Pull requests
should explain behavior changes, list affected modules, note test commands
run, and include before/after screenshots for visible UI. Do not commit
`zig-out/`, `.zig-cache/`, `zig-pkg/`, or generated `tools/` contents. No
AI/tool attribution in commits, PRs, code, or docs.
