<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Security Policy

Zigulator is a local-first desktop calculator. It does not run a network
service, open listening ports, or send telemetry. Security reports are
still welcome for crashes, memory issues, and anything that could affect
user trust or local data.

## Supported versions

Security fixes land on the latest release and `master`.

| Version | Supported |
| ------- | --------- |
| 0.1.x   | Yes       |
| < 0.1   | No        |

## Application scope

In scope:

- **Expression parser and calculator engine** (`src/core/`) - crashes,
  unbounded memory or CPU use, or incorrect results reachable from
  keypad input, keyboard input, or pasted expressions.
- **Clipboard paste** - malicious or oversized clipboard text that
  causes crashes or resource exhaustion.
- **Local preferences** (`~/.config/zigulator/prefs`) - path handling
  issues, unexpected writes outside the intended config directory, or
  privilege problems when creating config paths.
- **Desktop packaging** - icon, desktop-entry, or install layout issues
  that could mislead users or run unexpected content at launch.

Out of scope:

- Issues that require an attacker who already controls the local user
  account and can replace the application binary or config files.
- Third-party dependency advisories already tracked and fixed upstream,
  unless Zigulator exposes additional impact.
- Theoretical floating-point precision limits inherent to IEEE-754
  `f64` arithmetic used by the calculator.

## Data handled by the app

- Calculations run only in memory on the local machine.
- Preferences (mode, language, decimal separator) are stored under the
  XDG config home.
- History, memory, graph functions, and statistics are session-only.
- Dear ImGui may write `imgui.ini` in the working directory for window
  layout.

The app has no accounts, cloud sync, or runtime network client.

## Reporting a vulnerability

**Do not open a public GitHub issue, discussion, or pull request for
security problems.**

Report privately through GitHub:

1. Open the repository **Security** tab.
2. Choose **Report a vulnerability**.
3. Describe the issue using the checklist below.

If you cannot use GitHub Security Advisories, contact the maintainers via
[visorcraft.com](https://www.visorcraft.com).

Please include:

- The affected version or commit.
- OS, desktop environment, and how you built or installed Zigulator.
- A clear description of the issue and its impact.
- Steps to reproduce, with a minimal expression, clipboard sample, or
  config file when possible.
- A suggested fix or mitigation, if you have one.

## What to expect

- Acknowledgement within a few days.
- An initial assessment and remediation plan if confirmed.
- Progress updates through the private advisory thread until resolved.
- Credit in the advisory or release notes unless you prefer to remain
  anonymous.

Please give maintainers a reasonable opportunity to ship a fix before
public disclosure.

## Dependency security

Runtime and build dependencies are pinned in `build.zig.zon`
(currently zgui, zglfw, and zopengl from zig-gamedev). Prefer updating
pinned revisions over adding new dependencies. Report supply-chain or
build-system issues through the same private channel above.
