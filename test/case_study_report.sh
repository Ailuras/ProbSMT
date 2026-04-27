#!/usr/bin/env bash
set -euo pipefail

benchmark="${1:-GD_Triangle_0_1.smt2}"

test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log="$test_dir/res/$benchmark.log"

if [[ ! -f "$log" ]]; then
  echo "error: log not found: $log" >&2
  echo "hint: run ./case_study_run.sh $benchmark [runs] first" >&2
  exit 1
fi

sat_count=$(grep -c '^sat$' "$log" || true)
x_count=$(grep -c 'define-fun x' "$log" || true)
y_count=$(grep -c 'define-fun y' "$log" || true)

echo "report: $benchmark"
echo "  sat lines: $sat_count"
echo "  x models:  $x_count"
echo "  y models:  $y_count"
echo

echo "first 5 x assignments:"
awk '/define-fun x/{getline; print; c++; if (c == 5) exit}' "$log"

echo

echo "first 5 y assignments:"
awk '/define-fun y/{getline; print; c++; if (c == 5) exit}' "$log"
