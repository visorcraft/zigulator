#!/usr/bin/env bash
# Generates tools/crt-nosframe/ (copies of the system glibc CRT objects with
# the .sframe section stripped) and tools/libc-nosframe.txt (a zig --libc
# manifest pointing at them). Needed on hosts whose binutils emits .sframe
# sections (e.g. GCC 16 / binutils 2.46 with --enable-default-sframe), which
# zig 0.16's linker cannot process (R_X86_64_PC64 in .rela.sframe).
# Safe to re-run; no-op output if the system CRTs have no .sframe sections.
set -euo pipefail

cd "$(dirname "$0")/.."
CRT_DIR=tools/crt-nosframe
mkdir -p "$CRT_DIR"

for f in crt1.o crti.o crtn.o Scrt1.o gcrt1.o; do
    if [ -f "/usr/lib/$f" ]; then
        objcopy --remove-section .sframe "/usr/lib/$f" "$CRT_DIR/$f"
    fi
done

# The libc manifest's crt_dir is also searched for the shared/static libs, so
# symlink the rest of glibc in alongside the stripped CRT objects.
for f in /usr/lib/libc.so* /usr/lib/libm.so* /usr/lib/libdl.so* \
         /usr/lib/librt.so* /usr/lib/libpthread.so* /usr/lib/libutil.so* \
         /usr/lib/libmvec.so* /usr/lib/libm-*.a \
         /usr/lib/libc_nonshared.a /usr/lib/libc.a /usr/lib/libm.a \
         /usr/lib/libdl.a /usr/lib/librt.a /usr/lib/libpthread.a \
         /usr/lib/libutil.a /usr/lib/ld-linux-x86-64.so.2; do
    [ -e "$f" ] && ln -sf "$f" "$CRT_DIR/"
done

cat > tools/libc-nosframe.txt <<EOF
include_dir=/usr/include
sys_include_dir=/usr/include
crt_dir=$(pwd)/$CRT_DIR
msvc_lib_dir=
kernel32_lib_dir=
gcc_dir=
EOF

echo "wrote tools/libc-nosframe.txt -> $CRT_DIR"
