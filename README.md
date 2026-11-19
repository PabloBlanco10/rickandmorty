# Rick and Morty iOS

An iOS technical assessment focused on maintainable architecture, concurrency
safety, testability, and accessibility.

**Current status:** Data implements paginated character list/search requests,
domain mapping and a generic actor cache with configurable TTL (default 180 seconds).
The SwiftUI screen remains static. UI search, pagination interaction, pull-to-refresh,
images and detail requests are deferred.

## Stack

- iOS 17+, Swift 6 with strict concurrency, SwiftUI, and Observation for future ViewModels.
- One local Swift package; no third-party application dependencies.
- Swift Testing, SwiftFormat 0.64.5, SwiftLint 0.63.2, and GitHub Actions.

## Architecture

| Target | Responsibility | Dependencies |
| --- | --- | --- |
| Domain | Entities, repository contracts, use cases, policies | Foundation |
| Data | Networking, DTOs, mapping, repositories, in-memory cache | Domain |
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
decoding, mapping, independent page expiration, and out-of-order/cancelled responses
with manual time and controlled transports. They make no HTTP calls or arbitrary
sleeps. Presentation has no behavioral tests yet.

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
- cacheFirst reuses valid cached domain pages; reloadIgnoringCache always requests
  a replacement. Each query/page has an independent TTL; refreshing page 1 leaves
  later pages cached. Failed/cancelled refreshes preserve data and original expiry.
  HTTP-cache bypass is unchanged.
- Per-key generation tokens prevent old responses from overwriting newer cached
  results. Token validation and insertion commit atomically after checking cancellation.
  There is no request deduplication; future ViewModels will reset visible pagination
  on new searches/refreshes and protect against stale UI results. Independently cached
  pages may represent different server snapshots; cross-page consistency is not guaranteed.
- The same model-independent cache can hold characters keyed by ID later. Detail
  requests and search/detail cache coordination remain deferred.
- Domain repository errors hide HTTP/decoding details; cancellation remains
  `CancellationError`. Detail requests are deferred until there is a caller.
