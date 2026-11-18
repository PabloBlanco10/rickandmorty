# Rick and Morty iOS

An iOS technical assessment focused on maintainable architecture, concurrency
safety, testability, and accessibility.

**Current status:** project foundation with a static character screen and Light/Dark
previews. API integration, search, pagination, caching, refresh, and detail screens
are planned for later PRs.

## Stack

- iOS 17+, Swift 6 with strict concurrency, SwiftUI, and Observation for future ViewModels.
- One local Swift package; no third-party application dependencies.
- Swift Testing, SwiftFormat 0.64.5, SwiftLint 0.63.2, and GitHub Actions.

## Architecture

| Target | Responsibility | Dependencies |
| --- | --- | --- |
| Domain | Entities, repository contracts, use cases, policies | Foundation |
| Data | Future networking, mapping, repositories, caching | Domain |
| Presentation | SwiftUI views and presentation state | Domain |
| App | Entry point and dependency composition | Domain, Data, Presentation |

`Packages/RickAndMortyKit` uses module-first directories and colocated tests.
Domain and Data avoid UI-framework dependencies for future reuse; the package
currently targets iOS only.

## Getting started

Use Xcode 26.4 or compatible newer Xcode. Open
`RickAndMorty/RickAndMorty.xcodeproj`, select the `RickAndMorty` scheme, and run
on an iOS Simulator. Appearance follows the system automatically.

## Testing and CI

Run the `RickAndMortyKit-Package` scheme on an iOS Simulator to execute all three
test targets. Domain tests cover use-case delegation, fetch policies, results,
errors, and cancellation. Data and Presentation targets contain no behavioral
tests yet.

With the pinned development tools on PATH, run `bash Scripts/check-quality.sh`.
Local Xcode builds also run optional SwiftLint warnings; a missing tool does not block compilation.
The [CI workflow](.github/workflows/ci.yml) checks formatting, lint, the app build,
and package tests using Xcode 26.4.1. See the PR checks for actual workflow results.
Commands and engineering conventions are in [AGENTS.md](AGENTS.md).

## Key decisions

- Immutable, Sendable domain values and constructor injection keep contracts testable.
- App composition retains MainActor isolation and approachable concurrency;
  package modules use nonisolated defaults with explicit UI isolation.
- A minimal static view needs no ViewModel or fake repository.
- Full-screen `ViewState` stays separate from future refresh/pagination state.
  Typed presentation error mapping is deferred until concrete failures exist.
- Minimal source files keep future Data/test targets discoverable by SwiftPM
  without adding artificial APIs or placeholder tests.
