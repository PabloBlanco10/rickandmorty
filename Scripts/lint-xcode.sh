#!/bin/bash
set -euo pipefail

# CI runs the pinned, strict lint check separately.
if [[ "${CI:-}" == "true" ]]; then
    exit 0
fi

REPOSITORY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINT_EXECUTABLE="${SWIFTLINT_EXECUTABLE:-}"
if [[ -z "$LINT_EXECUTABLE" ]]; then
    LINT_EXECUTABLE="$(command -v swiftlint || true)"
    for candidate in /opt/homebrew/bin/swiftlint /usr/local/bin/swiftlint; do
        if [[ -z "$LINT_EXECUTABLE" && -x "$candidate" ]]; then
            LINT_EXECUTABLE="$candidate"
        fi
    done
fi

if [[ ! -x "$LINT_EXECUTABLE" ]]; then
    echo "warning: SwiftLint is unavailable. Install SwiftLint to enable local lint warnings."
    exit 0
fi

cd "$REPOSITORY_ROOT"
if ! "$LINT_EXECUTABLE" lint --quiet --lenient --no-cache --config "$REPOSITORY_ROOT/.swiftlint.yml"; then
    echo "warning: SwiftLint could not complete. Run Scripts/check-quality.sh for strict validation."
fi
