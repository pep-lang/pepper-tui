#!/usr/bin/env bash
# Runs the package's tests: the [Test] functions in tests/, with pepper test.
#
# Usage: tests/run.sh [path/to/pepper]   (default: pepper on PATH)
#
# Then it builds the examples and runs them on piped input, which goes
# through the real backend (TermBackend) without a terminal.
set -euxo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pepper="${1:-pepper}"
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

# The package is the module `tui`: a folder of that name on the import path.
mkdir "$build/packages"
ln -s "$root" "$build/packages/tui"
"$pepper" test -I "$build/packages" "$root/tests"

for program in minimal list_detail; do
    "$pepper" build -I "$build/packages" "$root/examples/$program/main.pep" -o "$build/$program"
done
"$pepper" build -I "$build/packages" "$root/tests/panic/main.pep" -o "$build/panic"

# Each example draws a frame per key and stops at q. Unchanged cells are
# not written, so the checks look for single words. The last thing written
# puts the screen back: the cursor shown, then the main screen.
printf 'q' | "$build/minimal" > "$build/minimal.out"
grep -q 'Hello,' "$build/minimal.out"
tail -c 14 "$build/minimal.out" | od -c | grep -q '\[   ?   1   0   4   9   l'
printf 'jjq' | "$build/list_detail" > "$build/list_detail.out"
grep -q 'Mars' "$build/list_detail.out"
grep -q 'Sun' "$build/list_detail.out"

# A panic puts the screen back too.
if "$build/panic" < /dev/null > "$build/panic.out" 2> "$build/panic.err"; then
    echo "error: the panic test did not panic" >&2
    exit 1
fi
grep -q 'on purpose' "$build/panic.err"
tail -c 14 "$build/panic.out" | od -c | grep -q '\[   ?   1   0   4   9   l'
