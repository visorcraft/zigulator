# Credits and Acknowledgements

Zigulator stands on open-source work from the Zig and zig-gamedev ecosystems.
This file lists the principal third-party projects used at build time and at
runtime. Full license texts for redistributed components are in
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

## Copyright

Zigulator is © VisorCraft LLC and contributors, distributed under
[GPL-3.0-only](LICENSE).

Repository: <https://github.com/visorcraft/zigulator>

## Direct Zig dependencies

Pinned in [`build.zig.zon`](build.zig.zon) (versions are the package
identifiers reported by Zig; URLs pin exact git revisions).

| Package | Version | License | Project |
| ------- | ------- | ------- | ------- |
| zgui | 0.6.0-dev (`88f186a`) | MIT | https://github.com/zig-gamedev/zgui |
| zglfw | 0.10.0-dev (`51003c1`) | MIT | https://github.com/zig-gamedev/zglfw |
| zopengl | 0.6.0-dev (`eda8724`) | MIT | https://github.com/zig-gamedev/zopengl |

## Embedded C/C++ libraries (via zgui / zglfw)

These are compiled into the Zigulator binary through the Zig bindings above.

| Library | Version | License | Project |
| ------- | ------- | ------- | ------- |
| Dear ImGui (docking) | 1.92.1 | MIT | https://github.com/ocornut/imgui |
| ImPlot | 0.17 | MIT | https://github.com/epezent/implot |
| GLFW | 3.4.0 | Zlib | https://github.com/glfw/glfw |

Dear ImGui also embeds the following header libraries (used for font packing
and text editing inside ImGui):

| Library | License | Author |
| ------- | ------- | ------ |
| stb_truetype | Public domain / MIT | Sean Barrett |
| stb_rect_pack | Public domain / MIT | Sean Barrett |
| stb_textedit | Public domain / MIT | Sean Barrett |

## Transitive build dependency

| Package | License | Project | Role |
| ------- | ------- | ------- | ---- |
| system_sdk | MIT | https://github.com/zig-gamedev/system_sdk | Platform headers/libs for zglfw/zgui cross builds |

## Toolchain

| Component | Version | License | Project |
| --------- | ------- | ------- | ------- |
| Zig | 0.16.0 (required) | MIT | https://github.com/ziglang/zig |

## Optional system fonts (not redistributed)

At runtime Zigulator may load fonts already installed on the host. None are
bundled in this repository.

| Font family | Typical packages | License (typical) |
| ----------- | ---------------- | ----------------- |
| Inter | distribution packages or local install | OFL-1.1 |
| Noto Sans / Noto Sans Mono | `noto-fonts` | OFL-1.1 |
| DejaVu Sans / DejaVu Sans Mono | `ttf-dejavu` | Bitstream Vera / DejaVu |
| Liberation Sans / Liberation Mono | `ttf-liberation` | OFL-1.1 |

## Reporting attribution gaps

If something in this repository is missing or miscredited, open an issue at
<https://github.com/visorcraft/zigulator/issues> and we will correct the record.
