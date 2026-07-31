# Repository Guidelines

## Project Structure & Module Organization

`src/main.zig` owns the GLFW/OpenGL startup and render loop. Keep calculator logic in `src/core/`; this layer must remain independent of zgui so it stays unit-testable. `src/ui/` contains the ImGui application shell, widgets, keyboard handling, and theme. `src/core.zig` imports every core module as the test root. `docs/usage.md` documents user workflows. `imgui.ini` is generated local UI state and must stay untracked. `scripts/gen-crt-nosframe.sh` creates the ignored Linux CRT workaround under `tools/`.

## Build, Test, and Development Commands

Use the repository-pinned Zig 0.16.0 binary:

- `tools/zig-x86_64-linux-0.16.0/zig build`: compile and install `zig-out/bin/zigulator`.
- `tools/zig-x86_64-linux-0.16.0/zig build run`: build and launch the desktop application.
- `tools/zig-x86_64-linux-0.16.0/zig build test`: run all GUI-independent core tests.
- `tools/zig-x86_64-linux-0.16.0/zig fmt --check build.zig src`: check formatting. Remove `--check` to apply formatting.

Dependencies are pinned in `build.zig.zon` and fetched during the first build. Run `scripts/gen-crt-nosframe.sh` only if linking fails on Linux with `.sframe` relocation errors.

## Coding Style & Naming Conventions

Accept `zig fmt` output and use four-space indentation. Name files and enum values with `snake_case`, functions and variables with `camelCase`, and public types with `TitleCase`. Keep UI code focused on rendering and event forwarding; place parsing, formatting, state transitions, and calculations in `src/core/`. Pass allocators explicitly, pair owned allocations with `deinit`, and avoid hidden global state.

## Testing Guidelines

Use Zig's built-in `std.testing`. Place focused `test "behavior description"` blocks beside the code they cover; `src/core.zig` discovers them. Add regression tests for parser edge cases, calculator state changes, numeric precision, localization, and error handling. There is no numeric coverage gate. For UI changes, also run the launch command above and manually check the affected window, keyboard path, and layout.

## Commit & Pull Request Guidelines

Follow the history's concise prefixes, such as `feat(core):`, `feat(ui):`, `fix(ui):`, `docs:`, and `build:`. Keep each commit focused and use a specific lowercase summary. Pull requests should explain behavior changes, identify affected modules, link the relevant issue or design note, and list test commands run. Include before/after screenshots for visible UI changes. Do not commit `zig-out/`, `.zig-cache/`, or generated `tools/` contents.
