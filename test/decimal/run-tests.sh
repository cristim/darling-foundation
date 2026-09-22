#!/bin/sh
# Build and run the decimal tests on the build host.
#
# This deliberately does not join the top-level CMake graph: that graph is a
# Darling cross-build with -nostdinc and a macOS deployment target, while
# src/NSDecimalCore.m contains no message sends.  It therefore compiles in
# Objective-C mode against a two-declaration shim and needs no Objective-C
# runtime, which makes it testable anywhere, including CI, with no container.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../.." && pwd)
out=${TMPDIR:-/tmp}/darling-foundation-decimal-tests
mkdir -p "$out"

${CC:-clang} -x objective-c -std=gnu11 -g -O1 -Wall -Wno-deprecated \
	-I "$here/hostshim" \
	-I "$root/include" \
	-I "$root/src" \
	-include "$here/hostshim/hostprefix.h" \
	-o "$out/test-decimal" \
	"$here/test-decimal.c" "$here/hostshim/hoststubs.m" "$root/src/NSDecimalCore.m"

exec "$out/test-decimal" "$here/decimal-fixture.txt" "$here/decimal-known-failures.txt"
