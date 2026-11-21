#!/bin/bash
set -euo pipefail

SWIFTFORMAT_VERSION=0.64.5
SWIFTLINT_VERSION=0.65.1

cd "$(dirname "$0")/.."
check_tool() {
  local tool="$1" expected="$2" flag="$3" actual
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool $expected is required but was not found on PATH. Install the pinned upstream release; see AGENTS.md." >&2
    exit 1
  fi
  if ! actual=$("$tool" "$flag"); then
    echo "error: Could not read the $tool version. Check the executable on PATH." >&2
    exit 1
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "error: $tool version mismatch: expected $expected, found $actual. Select the pinned executable on PATH; see AGENTS.md." >&2
    exit 1
  fi
}

check_tool swiftformat "$SWIFTFORMAT_VERSION" --version
check_tool swiftlint "$SWIFTLINT_VERSION" version
swiftformat --lint --cache ignore RickAndMorty/RickAndMorty Packages/RickAndMortyKit
swiftlint lint --strict --no-cache --config .swiftlint.yml
