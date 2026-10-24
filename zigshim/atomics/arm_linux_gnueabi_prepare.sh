#!/bin/sh
set -eu
dir="$(cd "$(dirname "$0")" && pwd)"
cd "$dir"

ar x "$(arm-linux-gnueabi-gcc -print-libgcc-file-name)" linux-atomic.o
arm-linux-gnueabi-gcc -O1 -fPIC -fno-builtin -march=armv5te -c arm_linux_gnueabi_sync_umin_umax.c -o arm_linux_gnueabi_sync_umin_umax.o

echo "${dir}/linux-atomic.o ${dir}/arm_linux_gnueabi_sync_umin_umax.o"