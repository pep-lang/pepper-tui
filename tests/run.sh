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

for program in minimal list_detail text_input; do
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
# A click (an xterm SGR report) on Saturn, the sixth row of the list,
# shows its moons, and the wheel then moves to Uranus ("ice" giant: only
# the cells that changed are written).
printf '\033[<0;3;7M\033[<0;3;7mq' | "$build/list_detail" > "$build/mouse.out"
grep -q '146' "$build/mouse.out"
if grep -q ice "$build/mouse.out"; then
    echo "error: a click selected past Saturn" >&2
    exit 1
fi
printf '\033[<0;3;7M\033[<65;3;7Mq' | "$build/list_detail" > "$build/wheel.out"
grep -q ice "$build/wheel.out"

# A bracketed paste (ESC [ 200 ~ ... ESC [ 201 ~) goes into the field
# whole: its line end becomes a space in the one-row field, so "two"
# starts at column 8 (the blank before it is unchanged, so not written);
# typed, the line end would be Enter, which the field ignores. A control
# character in a paste shows as U+FFFD rather than reaching the terminal.
printf 'ab\033[200~one\ntwo\033[201~\033[200~x\033[31my\033[201~' | "$build/text_input" > "$build/paste.out"
grep -q '\[2;4Hone' "$build/paste.out"
grep -q '\[2;8Htwo' "$build/paste.out"
grep -q "x$(printf '\357\277\275')\[31my" "$build/paste.out"
tail -c 14 "$build/paste.out" | od -c | grep -q '\[   ?   1   0   4   9   l'

# A panic puts the screen back too.
if "$build/panic" < /dev/null > "$build/panic.out" 2> "$build/panic.err"; then
    echo "error: the panic test did not panic" >&2
    exit 1
fi
grep -q 'on purpose' "$build/panic.err"
tail -c 14 "$build/panic.out" | od -c | grep -q '\[   ?   1   0   4   9   l'
