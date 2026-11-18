# Rick and Morty iOS

An iOS technical assessment focused on maintainable architecture, concurrency
safety, testability, and accessibility.

**Current status:** Data implements paginated character list/search requests and
domain mapping. The SwiftUI screen remains static, with Light/Dark previews.
UI search, pagination interaction, caching, refresh, images and detail are deferred.

## Stack

- iOS 17+, Swift 6 with strict concurrency, SwiftUI, and Observation for future ViewModels.
- One local Swift package; no third-party application dependencies.
- Swift Testing, SwiftFormat 0.64.5, SwiftLint 0.63.2, and GitHub Actions.

## Architecture

| Target | Responsibility | Dependencies |
| --- | --- | --- |
| Domain | Entities, repository contracts, use cases, policies | Foundation |
| Data | Networking, DTOs, mapping, repository implementation | Domain |
| Presentation | SwiftUI views and presentation state | Domain |
| App | Entry point and dependency composition | Domain, Data, Presentation |

`Packages/RickAndMortyKit` uses module-first directories and colocated tests.
Domain and Data avoid UI-framework dependencies for future reuse; the package
currently targets iOS only.

## Getting started

Use Xcode 26.4 or compatible newer Xcode. Open
`RickAndMorty.xcodeproj`, select the `RickAndMorty` scheme, and run
on an iOS Simulator. Appearance follows the system automatically.

## Testing and CI

Select the `RickAndMorty` app scheme and press Cmd+U on an iOS Simulator to
execute all three package test targets. Domain tests cover use-case delegation,
fetch policies, results, errors, and cancellation. Data tests cover requests,
decoding, mapping, error handling and cancellation with controlled transports;
they make no HTTP calls or arbitrary sleeps. Presentation has no behavioral tests yet.

With the pinned development tools on PATH, run `bash Scripts/check-quality.sh`.
Local Xcode builds also run optional SwiftLint warnings; a missing tool does not block compilation.
The [CI workflow](.github/workflows/ci.yml) checks formatting, lint, the app build,
and package tests using Xcode 26.4.1. Hosted CI is deliberately skipped while account
spending restrictions apply; validation is local and no CI success is claimed.
Commands and engineering conventions are in [AGENTS.md](AGENTS.md).

## Key decisions

- Immutable, Sendable domain values and constructor injection keep contracts testable.
- App composition retains MainActor isolation and approachable concurrency;
  package modules use nonisolated defaults with explicit UI isolation.
- A minimal static view needs no ViewModel or fake repository.
- Full-screen `ViewState` stays separate from future refresh/pagination state.
  Typed presentation error mapping is deferred until concrete failures exist.
- An internal transport protocol makes the concrete generic HTTP client testable
  without global mocks or additional networking abstractions.
- The default URLSession disables HTTP caching; every request also bypasses local
  HTTP cache and sends `Cache-Control: no-cache`. Both fetch policies currently
  use networking. The actor-based TTL cache will be implemented separately.
- Domain repository errors hide HTTP/decoding details; cancellation remains
  `CancellationError`. Detail requests are deferred until there is a caller.
