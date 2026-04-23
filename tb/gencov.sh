#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Usage:
#   ./generate_coverage_reports.sh [ucdb_file] [output_dir]
#   ./generate_coverage_reports.sh --reports-only [ucdb_file] [output_dir]
# Examples:
#   ./generate_coverage_reports.sh
#   ./generate_coverage_reports.sh coverage.ucdb coverage
#   ./generate_coverage_reports.sh --reports-only coverage.ucdb coverage

REPORTS_ONLY=0
if [[ "${1:-}" == "--reports-only" ]]; then
  REPORTS_ONLY=1
  shift
fi

UCDB_FILE="${1:-coverage.ucdb}"
OUT_DIR="${2:-coverage}"

if ! command -v vcover >/dev/null 2>&1; then
  echo "Error: vcover not found in PATH."
  exit 1
fi

if [[ "$REPORTS_ONLY" -eq 0 ]]; then
  for cmd in vlib vlog vsim; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Error: $cmd not found in PATH."
      exit 1
    fi
  done

  echo "Collecting coverage with toggle enabled (+cover=bcesft)..."
  rm -rf work transcript "$UCDB_FILE"
  vlib work
  vlog -sv +cover=bcesft ../rtl/*.sv
  vlog -sv +cover=bcesft +incdir+. \
    ./in_hdlc.sv \
    ./testPr_hdlc.sv \
    ./test_hdlc.sv \
    ./assertions_hdlc.sv \
    ./bind_hdlc.sv
  vsim -coverage -c -assertdebug -voptargs="+acc" test_hdlc bind_hdlc \
    -do "run -all; coverage save -onexit $UCDB_FILE; quit -f"
fi

if [[ ! -f "$UCDB_FILE" ]]; then
  echo "Error: UCDB file not found: $UCDB_FILE"
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "Generating coverage reports from: $UCDB_FILE"
echo "Output directory: $OUT_DIR"

# Assertion and directive coverage
vcover report -details -assert "$UCDB_FILE" > "$OUT_DIR/cov_assert.txt"
vcover report -details -directive "$UCDB_FILE" > "$OUT_DIR/cov_directive.txt"

# Code coverage per metric
vcover report -details -code s "$UCDB_FILE" > "$OUT_DIR/cov_statement.txt"
vcover report -details -code b "$UCDB_FILE" > "$OUT_DIR/cov_branch.txt"
vcover report -details -code c "$UCDB_FILE" > "$OUT_DIR/cov_condition.txt"
vcover report -details -code e "$UCDB_FILE" > "$OUT_DIR/cov_expression.txt"
vcover report -details -code t "$UCDB_FILE" > "$OUT_DIR/cov_toggle.txt"

# Combined code coverage report
vcover report -details -code bcesft "$UCDB_FILE" > "$OUT_DIR/cov_code_all.txt"

# Overall summary report
vcover report -details "$UCDB_FILE" > "$OUT_DIR/cov_summary.txt"
