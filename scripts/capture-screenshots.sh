#!/usr/bin/env bash
# Capture README gallery screenshots (requires a working OpenGL display).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
out=docs/screenshots
mkdir -p "$out"
bin=./zig-out/bin/zigulator
if [[ ! -x $bin ]]; then
  zig build -Doptimize=ReleaseFast
fi

capture() {
  local name=$1; shift
  local ppm
  ppm="$(mktemp --suffix=.ppm)"
  env "$@" ZIGULATOR_SHOT="$ppm" "$bin"
  magick "$ppm" -strip "$out/$name.png"
  rm -f "$ppm"
  echo "wrote $out/$name.png"
}

capture simple \
  ZIGULATOR_MODE=simple \
  ZIGULATOR_SEED='(2+3)*4'

capture standard \
  ZIGULATOR_MODE=standard \
  ZIGULATOR_SEED='1234.5*2'

capture scientific \
  ZIGULATOR_MODE=scientific \
  ZIGULATOR_SEED='sin(pi/2)+log(100)'

capture graph \
  ZIGULATOR_MODE=standard \
  ZIGULATOR_SHOW_GRAPH=1 \
  ZIGULATOR_SEED='42'
