# Rick and Morty iOS

An iOS 17+ SwiftUI application built incrementally for an engineering assessment.
PR #1 establishes the project foundation. The current screen is static; character
browsing and API integration are intentionally deferred.

## Requirements

- Xcode 26.4 or compatible newer Xcode, Swift 6 language mode.
- CI selects Xcode 26.4.1 explicitly on the standard `macos-26` runner.
- SwiftFormat 0.64.5 and SwiftLint 0.63.2 for development checks only.

Open `RickAndMorty/RickAndMorty.xcodeproj` and run the `RickAndMorty` scheme.
There are no third-party application dependencies or lint build phases.

## Architecture

One local package, `Packages/RickAndMortyKit`, uses explicit module-first paths:

```text
RickAndMortyApp -> Domain + Data + Presentation
Data           -> Domain
Presentation   -> Domain
Domain         -> Foundation only

Packages/RickAndMortyKit/
  Package.swift
  Domain/
    Sources/{Entities,Repositories,UseCases}/
    Tests/
  Data/
    Sources/
    Tests/
  Presentation/
    Sources/Features/Characters/
    Sources/Components/
    Tests/
```

Domain owns immutable, Sendable characters, paginated results, fetch policies,
the repository contract, and a concrete constructor-injected search use case.
Origin and location are display names. `CharacterPage.nextPage` is a one-based
page number or nil; API response types and links never cross into Domain.
The repository requires an explicit fetch policy; the use case defaults to
`cacheFirst` and forwards parameters, results, errors, and cancellation unchanged.

The app directly composes `CharactersView`. There is no fake repository,
dependency container, navigation wrapper, or ViewModel for static content.
Data's documentation-only source and the import-only Data/Presentation test
sources are necessary for SwiftPM to recognize those targets. They expose no
artificial functionality and contain no placeholder tests. Directories for
networking, DTOs, mappers, caching, and detail screens will be created when used.
Future API response types must have a `DTO` suffix and stay exclusively in Data.

## Concurrency decisions

Settings were inspected before modification. At implementation start, the working
tree already selected Swift 6 in both project and app Debug/Release configurations;
this user change is retained.

| Setting | Existing app | PR #1 app | Package targets |
| --- | --- | --- | --- |
| Swift language mode | 6.0 | 6.0, retained | `.v6`, tools 6.0 |
| Default actor isolation | MainActor | MainActor, retained | Nonisolated default |
| Approachable concurrency | YES | YES, retained | Not opted in |
| Strict concurrency setting | Not explicit | complete | Complete through Swift 6 mode |
| Member import visibility | YES | YES, retained | Compiler baseline |
| Minimum iOS | 26.4 | 17.0 | 17.0 |

App composition is UI work, so its MainActor default and approachable concurrency
remain appropriate. Package compilation settings are independent of app settings.
Domain and Data have no default MainActor isolation. Presentation's view is
explicitly MainActor-isolated; future UI-facing ViewModels will use
`@MainActor @Observable`. A future cache will have its own actor isolation.
No detached tasks, unsafe Sendable conformances, or concurrency escape hatches
are needed in this foundation.

## Presentation and future error behavior

Presentation's internal `ViewState<Value: Sendable>` models idle, loading, loaded,
and failed full-screen states. It retains `any Error` initially: Swift 6 errors are
Sendable, and choosing error categories before implementing their mapping would
be premature. A typed, Equatable presentation error can be added when concrete
user-facing failure cases exist; no error equality or localized-string matching
is assumed today.

Future refresh and pagination will keep loaded content and use separate progress
and error properties. Cancellation will not become a user-facing failure. Network
connectivity, invalid responses, HTTP statuses, decoding, and image failures will
have explicit mappings. Only the character-search endpoint's documented no-match
404 behavior will map to empty results; other 404 responses remain failures.
Refresh/pagination failures will preserve content.

## Validation

Run formatting and lint checks with the pinned executables on PATH:

```bash
bash Scripts/check-quality.sh
```

Download the release executables from
[SwiftFormat](https://github.com/nicklockwood/SwiftFormat/releases/tag/0.64.5) and
[SwiftLint](https://github.com/realm/SwiftLint/releases/tag/0.63.2).
The quality script checks versions and disables tool caches. To format intentional
changes, run `swiftformat --cache ignore RickAndMorty/RickAndMorty Packages/RickAndMortyKit`.

Build from the repository root:

```bash
xcodebuild -project RickAndMorty/RickAndMorty.xcodeproj \
  -scheme RickAndMorty -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Run all three test targets using Xcode's generated package scheme from
`Packages/RickAndMortyKit` (choose an installed simulator if different):

```bash
xcodebuild -scheme RickAndMortyKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO test
```

Domain tests exercise delegation, both policies, the default policy, empty queries,
complete results, error propagation, and cancellation propagation with an actor spy.
DataTests and PresentationTests build and run with zero behavioral tests until
their implementations arrive. Tests use no network, sleeps, or arbitrary delays.
Future TTL/debounce tests will inject time; asynchronous race tests will use
controlled completion and explicit synchronization.

The single CI workflow checks formatting, lint, app compilation, and all package
test targets. UI tests, deployment, signing, and coverage services are outside its
scope. A workflow configuration is not evidence of a successful GitHub run; inspect
the PR checks for its actual result.
