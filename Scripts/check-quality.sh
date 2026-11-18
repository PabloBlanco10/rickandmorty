#!/bin/bash
set -euo pipefail

SWIFTFORMAT_VERSION=0.64.5
SWIFTLINT_VERSION=0.63.2

cd "$(dirname "$0")/.."
test "$(swiftformat --version)" = "$SWIFTFORMAT_VERSION"
test "$(swiftlint version)" = "$SWIFTLINT_VERSION"
swiftformat --lint --cache ignore RickAndMorty/RickAndMorty Packages/RickAndMortyKit
swiftlint lint --strict --no-cache --config .swiftlint.yml
