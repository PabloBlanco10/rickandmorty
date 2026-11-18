# AGENTS.md — Rick and Morty iOS

## Project Context

This repository contains a Senior iOS technical assessment.

The objective is to demonstrate high-quality iOS engineering through a small, maintainable application consuming the public Rick and Morty API.

Prioritize correctness, simplicity, testability, accessibility and clear architectural decisions over feature count.

## Architecture

Follow Clean Architecture with three Swift Package Manager modules:

- **Domain:** entities, repository contracts, use cases and domain policies.
- **Data:** networking, DTOs, mapping, repositories and caching.
- **Presentation:** SwiftUI views, ViewModels, UI state and reusable components.

Dependencies:

- Domain must not depend on Data or Presentation.
- Data depends on Domain.
- Presentation depends on Domain.
- The App target acts as the composition root.

Follow SOLID principles and dependency inversion without introducing unnecessary abstractions.

Use constructor-based dependency injection. Avoid service locators and global singletons.

## Swift and Concurrency

- Use Swift 6 with strict concurrency checking.
- Prefer async/await and structured concurrency.
- Use actors for shared mutable state where appropriate.
- Respect Sendable requirements and actor isolation.
- Use explicit @MainActor isolation for UI-facing ViewModels.
- Do not introduce Task.detached or @concurrent without a justified need.
- Avoid @unchecked Sendable and concurrency-suppression workarounds.
- Handle cancellation cooperatively.
- Prevent stale asynchronous results from modifying current state.
- Do not block the main actor with expensive synchronous operations.

## SwiftUI and Presentation

- Use SwiftUI for every screen.
- Use the Observation framework with @Observable ViewModels.
- Follow MVVM with clear state ownership.
- Use ViewState for initial loading, success, empty and failure behavior as appropriate.
- Keep refresh and pagination state separate from loaded content.
- Use native NavigationStack for navigation.
- Use native SwiftUI components when possible.
- Do not place networking or business logic inside Views.

Every meaningful screen and reusable visual component should include useful #Preview configurations.

Previews must use fixtures or mock dependencies, never real network requests.

Include relevant previews for loading, loaded, empty and error states when applicable.

## Appearance and Accessibility

- Support automatic Light and Dark Mode based on system appearance.
- Use semantic SwiftUI colors and adaptive Asset Catalog colors.
- Do not force a global color scheme.
- Support Dynamic Type and VoiceOver.
- Provide meaningful accessibility labels where necessary.
- Avoid using color alone to communicate information.
- Prefer accessible native controls over custom replacements.

## Networking and Data

- Use native URLSession.
- Use generic Decodable-based response handling where appropriate.
- Use URLComponents to construct URLs safely.
- Validate HTTP responses and map errors explicitly.
- Keep DTOs exclusively in Data.
- All DTO type names must end with DTO.
- Map DTOs into domain entities before returning repository results.
- Do not add third-party networking libraries.

## Search, Pagination and Cache

- Support remote character search with debounce and cancellation.
- Support pagination using API metadata.
- Prevent duplicate page requests and stale results.
- Support pull to refresh that bypasses valid cached data.
- Cache paginated domain responses by normalized query and page.
- Use an in-memory actor-based cache with configurable TTL.
- Ensure explicit refresh cannot be undone by obsolete in-flight operations.
- Preserve previously loaded content after refresh or pagination failures.

Do not introduce persistent storage unless explicitly approved.

## Error Handling

- Handle network, HTTP, decoding and application errors deliberately.
- Do not silently swallow failures.
- Treat expected task cancellation separately from user-facing errors.
- Distinguish empty search results from unexpected failures.
- Preserve existing content when pagination or refresh fails.
- Provide understandable retry behavior.

## Testing

Use Swift Testing with separate targets:

- DomainTests
- DataTests
- PresentationTests

Tests must validate observable behavior.

- Use mocks, spies and fixtures.
- Do not make real HTTP requests in unit tests.
- Do not use arbitrary Task.sleep delays in tests.
- Use injectable time sources for TTL and debounce testing.
- Use explicit synchronization for asynchronous race-condition tests.
- Verify success, failure, cancellation and relevant edge cases.

## Code Quality

- Follow the existing SwiftLint and SwiftFormat configurations.
- Prefer descriptive names and focused types.
- Avoid force unwraps.
- Avoid unused abstractions and premature generalization.
- Keep functions and types reasonably small.
- Keep comments focused on reasoning, invariants and non-obvious behavior.
- Do not add new dependencies without approval.
- Do not introduce features outside the assessment scope.

## Workflow

- Inspect existing code before making changes.
- Preserve unrelated user changes.
- Explain significant architectural trade-offs.
- Implement only the approved scope.
- Keep pull requests focused and reviewable.
- Run relevant tests, build, lint and format checks.
- Report actual validation results and known limitations.
- Never claim tests or CI passed without verifying them.
- Do not merge pull requests unless explicitly requested.
- Update documentation when architectural decisions change.

AI-generated code is subject to the same quality, testing and review standards as human-written code.

Prefer a simpler, defensible solution when two implementations satisfy the same requirements.

## Repository-specific boundaries

- Keep one local package at `Packages/RickAndMortyKit`, with explicit module-first
  target paths and colocated tests. Do not create separate feature packages.
- The package currently supports iOS 17+ only. Do not add macOS support without
  approval. Keep Domain and Data free of UIKit, AppKit, and SwiftUI imports so
  their responsibilities remain suitable for future platform reuse.
- PR #1 contains only foundation work. Networking, DTOs, mapping, caching,
  search, pagination, refresh, image loading, and detail screens require later
  approved work. Future-feature rules above do not authorize implementation.
- Create directories when they contain needed implementation. SwiftPM's current
  Data source and Data/Presentation test source files exist only to keep their
  otherwise empty targets discoverable; do not add meaningless tests or APIs.
- `RickAndMortyApp` directly composes `CharactersView`. Add concrete dependencies
  through constructors when real implementations exist; do not create fake
  production repositories to disguise unfinished functionality.
- Keep Character and CharacterPage immutable and Sendable. Origin and location
  are display names; nextPage is a one-based page number or nil. Keep repository
  fetch policy explicit; the search use case alone defaults to cacheFirst.
- ViewState belongs to Presentation. It currently retains a Sendable Error under
  Swift 6; introduce a typed presentation error when concrete mappings justify
  it. Do not compare localized error text in tests.
- Treat only the character-search endpoint's verified no-match HTTP 404 as empty
  results. Do not convert arbitrary 404 responses into success.
- Future cache TTL defaults to three minutes and must be configurable. Invalidate
  every page of the refreshed query and prevent obsolete requests from restoring
  invalidated entries. Discuss request deduplication before implementing it.
- Include Light and Dark previews for meaningful views/components, plus relevant
  state and Dynamic Type previews. Static views need no mock dependency. When
  data is required, inject fixtures/mocks; never use live services in previews.
- Runtime appearance follows the system. Explicit color schemes are permitted
  only in previews/tests. Do not add an appearance selector. Use semantic colors;
  if custom Asset Catalog colors are needed, supply adaptive appearance variants.

## Build settings and validation commands

Inspect current settings before changing them and document meaningful changes in
PR descriptions. App Debug/Release use Swift 6, complete strict concurrency,
MainActor default isolation, approachable concurrency enabled, and member import
visibility enabled. Retain these settings unless a concrete need justifies a
change. SwiftPM uses tools 6.0 and language mode v6 with nonisolated defaults;
app settings do not configure package compilation. Future cache state uses its
own actor rather than MainActor isolation.

Pinned development tools are SwiftFormat 0.64.5 and SwiftLint 0.63.2. Obtain their
release executables from the upstream repositories and place them on PATH. Run
from the repository root:

```bash
bash Scripts/check-quality.sh
```

To format intentional Swift changes:

```bash
swiftformat --cache ignore RickAndMorty/RickAndMorty Packages/RickAndMortyKit
```

Do not attach either tool to ordinary local Xcode build phases. Keep formatting
and lint responsibilities complementary and avoid unrelated reformatting.

Build from the repository root:

```bash
xcodebuild -project RickAndMorty/RickAndMorty.xcodeproj \
  -scheme RickAndMorty -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Run all three test targets from `Packages/RickAndMortyKit`:

```bash
xcodebuild -scheme RickAndMortyKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO test
```

Choose an installed simulator when necessary and report its OS version. The
package is iOS-only; use xcodebuild with an iOS Simulator rather than host swift
test for the whole package. Keep UI tests outside the main CI workflow.
CI selects Xcode 26.4.1 on macos-26. Disclose local/CI toolchain differences and
inspect the workflow for the PR's current commit before reporting CI success.
