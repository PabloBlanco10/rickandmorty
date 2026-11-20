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
- Keep pagination progress and errors separate from loaded content.
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
- Use cacheFirst in Presentation; retain reloadIgnoringCache in Domain/Data for explicit network replacements.
- Cache paginated domain responses by normalized query and page.
- Use an in-memory actor-based cache with configurable TTL.
- Prevent obsolete in-flight operations from overwriting newer cached results.
- Preserve previously loaded content after pagination failures.

Do not introduce persistent storage unless explicitly approved.

## Error Handling

- Handle network, HTTP, decoding and application errors deliberately.
- Do not silently swallow failures.
- Treat expected task cancellation separately from user-facing errors.
- Distinguish empty search results from unexpected failures.
- Preserve existing content when pagination fails.
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
- Keep every spy, mock and fixture inside its owning test target. Each test must
  create its own dependencies; do not share mutable globals or depend on order.
- Preserve Swift Testing's default in-process parallel execution and randomized
  ordering. Do not use `.serialized` without a documented requirement, disable
  parallel testing globally, or add a test plan just to restate framework defaults.
- Xcode selects test targets and configures runner processes; this is distinct
  from Swift Testing's task-group concurrency within each process. Verify both
  actual execution and generated test configuration before claiming validation.
- Keep use-case tests under Tests/UseCases, reusable actor spies under Tests/Mocks
  with nested request records, and nontrivial fixtures under Tests/Fixtures.

## Code Quality

- Follow the existing SwiftLint and SwiftFormat configurations.
- Prefer readable multiline formatting: separate conditions in complex guards, keep else clearly separated, and place SwiftUI modifiers on individual lines. Do not compress statements merely to reduce line count.
- Prefer descriptive names and focused types.
- Avoid force unwraps.
- Avoid unused abstractions and premature generalization.
- Keep functions and types reasonably small.
- Keep comments focused on reasoning, invariants and non-obvious behavior.
- Do not add new dependencies without approval.
- Do not introduce features outside the assessment scope.

## Access control

- Prefer the most restrictive access compatible with module boundaries.
- Use `private` for implementation details when possible; use `fileprivate` only
  when access across declarations in the same file requires it.
- Use the default `internal` visibility for declarations used only in a module.
- Use `public` only for contracts needed by other modules, including initializers
  and protocol requirements. Do not expose implementation details unnecessarily.
- Avoid `open` unless external subclassing is explicitly required.
- Mark classes `final` unless a concrete inheritance requirement is documented.
- SwiftUI View already guarantees MainActor isolation. Avoid redundant view-level
  annotations; retain explicit `@MainActor` on observable ViewModels.

## Workflow

- Work only in the existing primary repository checkout. Never create or use Git
  worktrees, temporary worktrees, or separate checkouts for implementation.
- Before each PR, inspect Git status and the active branch. Preserve all user
  changes; never discard, overwrite, or stash them without explicit approval.
- Switch to local main, fetch origin, pull origin/main with `--ff-only`, then
  create a new feature branch from updated main. Stop if switching is blocked;
  do not work around it with another checkout or by changing the user's files.
- Do not implement on main or reuse an earlier PR branch. Do not force-push or
  delete user branches without approval. Commit and push the feature branch,
  open a PR targeting main, and leave the primary checkout on that feature branch.
- Explain significant architectural changes and obtain approval before implementing them.
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
- Target iOS 17+ and do not add macOS support without
  approval. Keep Domain and Data free of UIKit, AppKit, and SwiftUI imports so
  their responsibilities remain suitable for future platform reuse.
- Create directories when they contain needed implementation. Do not add
  meaningless tests or artificial production APIs to fill a directory.
- Compose concrete dependencies in the App target and inject them through
  constructors. Do not create fake production repositories to disguise unfinished
  functionality.
- Keep Character and CharacterPage immutable and Sendable. Origin and location
  are display names; nextPage is a one-based page number or nil. Keep repository
  fetch policy explicit; both search and detail use cases default to cacheFirst.
- ViewState belongs to Presentation. Use typed presentation errors when concrete
  mappings justify them. Do not compare localized error text in tests.
- Treat only the character-search endpoint's verified no-match HTTP 404 as empty
  results. Do not convert arbitrary 404 responses into success.
- Cache TTL defaults to three minutes and must be configurable. Keep query/page
  entries independent; replacing one page must not invalidate other pages or
  their pending writes. Discuss request deduplication before implementing it.
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
app settings do not configure package compilation. Cache state uses its own actor
rather than MainActor isolation.

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

The app has exactly one optional SwiftLint Run Script phase invoking
`Scripts/lint-xcode.sh`. It resolves the repository from the script's location,
uses the existing config, discovers SwiftLint on PATH or at either Homebrew prefix,
and uses `--lenient` to report violations as Xcode warnings. A missing or failing
tool emits a warning without preventing compilation. The script never formats or
modifies source files. `SWIFTLINT_EXECUTABLE` can explicitly select an executable;
set it to a nonexistent path to verify the missing-tool behavior.

The phase runs once per app build, including incremental builds; it does not call
xcodebuild. It skips when CI=true because CI runs the pinned strict quality script
separately. Keep SwiftFormat outside build phases. Keep formatting and lint
responsibilities complementary and avoid unrelated reformatting.

App-only ENABLE_USER_SCRIPT_SANDBOXING is NO in Debug/Release so the optional
external tool can read repository-wide package sources and its Homebrew
installation. Project-level sandboxing stays enabled; Swift/package concurrency
settings remain unchanged. Do not broaden this exception to other targets.

The Xcode project bundle lives at the repository root, beside Packages and Scripts.
Application sources remain in RickAndMorty/RickAndMorty; do not duplicate or move
them merely to change navigator labels.

Build from the repository root:

```bash
xcodebuild -project RickAndMorty.xcodeproj \
  -scheme RickAndMorty -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Run all three package test targets through the main app scheme from the repository root:

```bash
xcodebuild -project RickAndMorty.xcodeproj \
  -scheme RickAndMorty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' \
  CODE_SIGNING_ALLOWED=NO test
```

Choose an installed simulator when necessary and report its OS version. The
package is iOS-only; use xcodebuild with an iOS Simulator rather than host swift
test for the whole package. Keep UI tests outside the main CI workflow.
CI selects Xcode 26.4.1 on macos-26. Disclose local/CI toolchain differences and
inspect the workflow for the PR's current commit before reporting CI success.
Honor instructions restricting hosted CI. When hosted execution is prohibited,
use `[skip ci]` on commits to suppress push/pull_request workflows; do not change
repository visibility or trigger workflows to bypass the restriction. Report local
validation separately: deliberately skipped CI is not passing CI.

## Networking implementation decisions

- Keep HTTPTransport and its URLSession adapter internal to Data. HTTPClient is
  concrete with a generic Decodable & Sendable result; do not add a second client
  protocol, endpoint framework, or type erasure without a concrete requirement.
- Construct a decoder for each response. Keep requests and mapping nonisolated;
  do not introduce actors or detached tasks for immutable networking state.
- The JSON API default URLSession is ephemeral, has no URLCache, and ignores local cached
  data. Every request independently sets reloadIgnoringLocalCacheData and the
  Cache-Control: no-cache header, including when a session is injected.
- cacheFirst returns an unexpired domain result before networking; reloadIgnoringCache
  bypasses it. Network requests retain the same HTTP-cache bypass under either
  policy. Failed replacements preserve existing values and their original TTL.
- Check cancellation before requests, after transport completion, and before
  returning mapped results. Normalize URLSession's cancelled URLError and preserve
  CancellationError. Test late successful completion using controlled continuations.
- Translate infrastructure failures to CharacterRepositoryError: invalidRequest
  for invalid page/character ID/base URL; networkUnavailable for connection loss, unavailable
  connections and timeouts; serviceFailure for HTTP rejection or other URLSession
  failures such as TLS rejection; invalidData for non-HTTP, decode or mapping
  failures; unexpected only for unrecognized non-URLSession transport errors.
- Only a nonempty filtered search on page 1 whose 404 JSON body identifies
  "There is nothing here" maps to an empty page. Other endpoints, pages, statuses
  and unrecognized/malformed error bodies remain service failures.
- Trim surrounding search whitespace, preserve the remaining query text, and use
  URLComponents/URLQueryItem for encoding. Map pagination metadata into nextPage;
  never issue requests directly to an API-provided next URL.
- Inject API roots, transports and time sources through constructors. Keep test
  seams internal unless another application module needs them. Static views must
  not initiate requests or construct unused dependencies.

Swift Testing defaults are described in Apple's
[parallelization documentation](https://developer.apple.com/documentation/testing/parallelization)
and [WWDC explanation of randomized ordering](https://developer.apple.com/videos/play/wwdc2024/10195/).
The shared RickAndMorty app scheme selects all three package test targets without
serialization overrides; no custom test plan is necessary. Keep the existing package
folder registered as a named project file reference under the Packages navigator
group so Xcode exposes its test targets. Use a SOURCE_ROOT-relative path and the
explicit display name RickAndMortyKit; the package dependency registration alone
does not expose test targets. Keep one folder reference to the existing package,
not a second package or duplicate files.
Scheme test references use the package-relative container and target names as
blueprint identifiers and buildable names. Test-only Build action entries ensure
the package tests build without adding them to Run or Archive actions. Inspect generated
xctestrun settings and result logs when validating this configuration. A changed
start order exercises order independence, not exhaustive race coverage or a
guarantee that every run produces a different order.


## Cache concurrency

- Keep MemoryCache generic and independent of HTTP, DTOs and domain models. Store
  domain values and keep search and detail caches independent unless a concrete
  consistency requirement justifies coordination.
- Use monotonic time with Duration-based TTL and an injected time source. Entries
  expire exactly at their deadline. Use manual time in tests, never sleeps.
- Normalize search keys consistently: trim surrounding whitespace/newlines,
  preserve case and internal characters, and include the one-based page.
- Repository code owns fetching. Use per-key generation
  tokens to conditionally commit responses; do not introduce shared in-flight
  network tasks or deduplication without an explicit requirement.
- After every suspension, revalidate cancellation and token ownership before
  committing a network result. Token validation and insertion must form one
  actor-isolated segment with no intervening await.
- Failed/cancelled replacements preserve existing entries and their original TTL.
  Independent page lifetimes do not guarantee a consistent server snapshot across
  pages. Presentation owners reset visible pagination on new searches;
  cache storage does not coordinate page generations.
- Complete or release write tokens on all paths. Cleanup may revoke only its own
  generation, so an older failure or cancellation cannot revoke a newer write.
- A discarded cache write does not transfer ownership of a caller's task.
  UI owners must cancel obsolete searches and gate stale UI updates themselves.
- Test reverse completion order, independent page lifetimes, cancellation and
  clock-induced actor reentrancy with controlled continuations. Keep race tests
  focused on distinct responsibilities rather than duplicating them across layers.
