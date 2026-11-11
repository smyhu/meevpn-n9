#!/bin/sh
# Builds meevpn-root: static ARM binary without libc (gcc-arm-linux-gnueabihf).
set -e
D=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$D/meevpn-root}
arm-linux-gnueabihf-gcc -marm -march=armv7-a -mfpu=vfpv3-d16 -Os -nostdlib -static -ffreestanding \
  -fno-builtin -fno-stack-protector -std=gnu99 -Wall -o "$OUT" "$D/meevpn-root.c" -lgcc
arm-linux-gnueabihf-strip "$OUT"
file "$OUT"
