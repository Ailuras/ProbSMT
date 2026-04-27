#!/usr/bin/env bash
set -euo pipefail

benchmark="${1:-GD_Triangle_0_1.smt2}"
runs="${2:-1000}"

test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
solver="$test_dir/../build/z3"
input="$test_dir/smt/$benchmark"
out_dir="$test_dir/res"
log="$out_dir/$benchmark.log"

if [[ ! -x "$solver" ]]; then
  echo "error: solver not found or not executable: $solver" >&2
  echo "hint: build first: cmake -S . -B build && cmake --build build -j" >&2
  exit 1
fi

if [[ ! -f "$input" ]]; then
  echo "error: benchmark not found: $input" >&2
  exit 1
fi

if ! [[ "$runs" =~ ^[0-9]+$ ]] || [[ "$runs" -le 0 ]]; then
  echo "error: runs must be a positive integer, got: $runs" >&2
  exit 1
fi

mkdir -p "$out_dir"
: > "$log"

for ((i = 1; i <= runs; i++)); do
  "$solver" "$input" >> "$log"
done

sat_count=$(grep -c '^sat$' "$log" || true)

echo "done"
echo "  benchmark: $benchmark"
echo "  runs:      $runs"
echo "  sat lines: $sat_count"
echo "  log:       $log"
