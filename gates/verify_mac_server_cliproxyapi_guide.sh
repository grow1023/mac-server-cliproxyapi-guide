#!/usr/bin/env bash
# Master gate for this repository. Exit 0 only when tests/run.sh passes.
set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
bash "$ROOT/tests/run.sh"
