# SquareRepo

A UIKit iOS app that fetches and displays a scrollable list of public GitHub repositories for the [Square](https://github.com/square) organisation.

---

## Project Structure

```
SquareRepo/
├── Common/
│   ├── Helper/
│   │   └── ImageCache.swift          — Actor-isolated, NSCache-backed async image                                     cache
│   └── UI/
│       ├── StateView.swift           — Reusable loading / error / empty state view
│       └── PillLabel.swift           — Rounded badge label (language, archived)
├── Models/
│   └── Repository.swift              — Codable domain model, flattens          owner.avatar_url
├── Networking/
│   ├── NetworkError.swift            — Typed error enum with LocalizedError
│   └── RepositoryService.swift       — Protocol + live URLSession implementation
├── ViewModels/
│   └── SqureRepoListViewModel.swift  — @MainActor state machine + pagination logic
├── Views/
│   ├── qureRepoListViewController.swift — UITableView + diffable data source
│   └── SqureRepoCell.swift           — Self-sizing cell with async avatar loading
├── AppDelegate.swift
├── SceneDelegate.swift               — Programmatic window / root VC setup
└── Tests/
    └── RepositoryListViewModelTests.swift — Unit tests (no network, no UIKit)
```

---

## Architecture

### Pattern: MVVM

```
┌─────────────────────────────────────────────────────────┐
│  Views                                                   │
│  SqureRepoListViewController                             │
│    └── observes onStateChange closure                    │
│    └── renders ViewState → UIKit                         │
└───────────────────────┬─────────────────────────────────┘
                        │ reads state / calls load*()
┌───────────────────────▼─────────────────────────────────┐
│  ViewModel                                               │
│  SqureRepoListViewModel (@MainActor)                     │
│    └── owns ViewState (idle/loading/loaded/failed)       │
│    └── handles pagination + refresh logic                │
└───────────────────────┬─────────────────────────────────┘
                        │ async throws → [Repository]
┌───────────────────────▼─────────────────────────────────┐
│  Networking                                              │
│  RepositoryServiceProtocol                               │
│    └── GitHubRepositoryService  (live URLSession)        │
│    └── MockRepositoryService    (injected in tests)      │
└─────────────────────────────────────────────────────────┘
```

**Why MVVM?**

- **Testability** — the ViewModel has zero UIKit imports and is fully unit-testable without a simulator or XCTestExpectation boilerplate.
- **Single responsibility** — the ViewController only drives UIKit; it never touches `URLSession` or decoding logic.
- **Explicit state** — all UI states are modelled as a single `ViewState` enum, making impossible combinations (e.g. `isLoading = true` alongside a populated list) structurally unrepresentable.

### Key design decisions

**Protocol-driven networking**
`RepositoryServiceProtocol` decouples the ViewModel from `URLSession`. Tests inject `MockRepositoryService` and return deterministic results, making every failure path testable without a network.

**`@MainActor` ViewModel**
All state mutations are guaranteed to run on the main thread. The ViewController subscribes via a `(ViewState) -> Void` closure and can update UIKit directly — no `DispatchQueue.main.async` boilerplate anywhere.

**`UITableViewDiffableDataSource`**
Replaces the classic `reloadData()` / `performBatchUpdates()` pair. Diffable eliminates the "invalid number of rows" crash that occurs when data arrives during an in-progress animation, and makes the data→UI mapping declarative.

**Actor-isolated image cache (`ImageCache`)**
- `NSCache` provides automatic memory-pressure eviction.
- Swift `actor` isolation makes all cache mutations data-race-free without manual locks.
- In-flight deduplication: if multiple cells request the same URL simultaneously, only one network request is made — subsequent callers await the existing `Task`. This matters here because every row shares the same Square org avatar.

**Programmatic layout — no Storyboards**
All views are created and constrained in code. Benefits: fully diffable in PRs, no XML noise, no storyboard merge conflicts, and dependencies are explicit and injectable at the root level in `SceneDelegate`.

---

## State Machine

The ViewModel drives a single `ViewState` enum. The ViewController renders each case and nothing else.

```
idle ──► loading ──► loaded([Repository])
                 ╰──► failed(NetworkError)

loaded ──► loadingMore([Repository]) ──► loaded (appended)
                                     ╰──► loaded (original, on failure)
```

| State          | UI                                                    |
|----------------|-------------------------------------------------------|
| `idle`         | Blank (before first load)                             |
| `loading`      | Full-screen activity indicator                        |
| `loaded`       | Populated table view                                  |
| `loaded([])`   | Empty-state illustration + copy                       |
| `loadingMore`  | Table stays visible; footer spinner appears           |
| `failed`       | Full-screen error view with message + "Try Again" CTA |

**Pull-to-refresh** resets pagination to page 1 and reloads.
**Pagination failure** preserves the existing list — users are never left with a blank screen.

---

## Testing

All tests live in `RepositoryListViewModelTests.swift` and run entirely in-process — no network, no simulator required.

`MockRepositoryService` conforms to `RepositoryServiceProtocol` and exposes a configurable `result: Result<[Repository], NetworkError>` property. Tests set this before calling into the ViewModel to simulate any scenario deterministically.

**Coverage:**

| Area | What's tested |
|------|--------------|
| Initial state | Starts as `.idle` |
| Successful load | Transitions to `.loaded([Repository])` |
| Empty response | Stays `.loaded([])` |
| Network errors | `.noConnection`, `.httpError(403)`, `.decodingFailed` all produce `.failed` |
| Refresh | Resets pagination to page 1, replaces list |
| Pagination | Appends page 2 to existing list |
| Pagination no-op | `loadMoreIfNeeded` ignores calls far from the bottom |
| Pagination failure | Reverts to the last good list, not an error screen |
| State callbacks | `onStateChange` fires on every transition |
| Error descriptions | `NetworkError.errorDescription` includes contextual detail |
| Number formatting | `Int.abbreviated` — 42, 5130 → "5.1k", 1.5M |

---

## Assumptions & Trade-offs

- **iOS 15+ minimum** — enables `async/await`, `UIButton.Configuration`, and the improved diffable data source API without polyfills.
- **No Combine / SwiftUI** — kept to UIKit as specified. Swapping the `onStateChange` closure for a Combine `@Published` property would be a small refactor.
- **Memory-only image cache** — no disk persistence. Images re-download on next launch. A production app would layer in disk caching (e.g. via Kingfisher or a custom `URLCache` policy).
- **Unauthenticated GitHub API** — capped at 60 requests/hour. Adding `Authorization: Bearer <token>` raises this to 5,000/hour.
- **Single organisation** — the endpoint is hardcoded to `square`. Promoting it to a parameter in `RepositoryServiceProtocol` would make the feature reusable for any org.

---

## Running the project

1. Clone and open `SquareRepo.xcodeproj` in Xcode 15+.
2. Select any iPhone simulator running iOS 15+.
3. Press `⌘R` to run, or `⌘U` to run the full unit test suite.

No third-party dependencies — SPM or CocoaPods not required.
