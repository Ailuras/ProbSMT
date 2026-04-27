#!/usr/bin/env bash
set -euo pipefail

runs="${1:-1000}"

test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! [[ "$runs" =~ ^[0-9]+$ ]] || [[ "$runs" -le 0 ]]; then
  echo "error: runs must be a positive integer, got: $runs" >&2
  exit 1
fi

for input in "$test_dir"/smt/GD_Triangle_*.smt2; do
  name="$(basename "$input")"
  "$test_dir/case_study_run.sh" "$name" "$runs"
done
