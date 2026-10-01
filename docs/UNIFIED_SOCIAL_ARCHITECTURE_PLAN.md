# Unified Social Client Architecture Plan: Mustard + Winston (Reddit) + Bluesky (AT Protocol)

**Document Version:** 1.0.0  
**Target Environment:** iOS 18+, macOS 15+, visionOS 2+  
**Core Language & Runtime:** Swift 6 / Modern Swift Concurrency (`async`/`await`, Actors, `@Observable`)  
**Data Layer:** SwiftData + Keychain Services  

---

## 1. Executive Vision

The objective is to evolve **Mustard** from a single-network Mastodon client into a **unified, multi-network social hub** running 100% on-device. The unified client brings together:

1. **Mastodon / ActivityPub** (Federated, existing in Mustard)
2. **Reddit** (Aggregated, community discussions, ported/merged from **Winston**)
3. **Bluesky / AT Protocol** (Public conversation, decentralized custom feeds)
4. **On-Device Recommendation Engine** (Local, privacy-preserving ranking across networks using SwiftData interaction history)

---

## 2. Cross-Project Audit & Current State

### A. Mustard Status
* **Strengths:** 
  * Clean modern SwiftUI views (`PostView`, `TimelineContentView`, `ProfileView`, `SearchView`).
  * SwiftData schema configured for `Interaction`, `UserAffinity`, and `HashtagAffinity`.
  * Clean Swift 5.9/6 build with `@Observable` architecture started.
* **Debt to Cleanse ("Slop" Removal):**
  * Replace the fake `OnDeviceAIService.swift` (mocked `FoundationModel` heuristic) with genuine SwiftData interaction decay & ranking.
  * Consolidate duplicate timeline managers (`TimelineProvider` and `TimelineService`).
  * Remove dead CoreLocation notification handlers and unneeded permission requests.
  * Eliminate leftover `ObservableObject` / `@StateObject` in `MustardApp.swift`.

### B. Winston (Reddit Client) Status
* **Location:** `Developer/SwiftUI/winston` (Remote: `https://github.com/lo-cafe/winston`, active branches `main`, `alpha`).
* **Strengths:**
  * Rich suite of polished UI components in `winston/components/` (waterfall layouts, media carousels, expandable text, comments collapse/tree, swipe gesture responders, custom sheet presenters).
  * Robust Reddit API data parsing and rich Markdown rendering (`DownAttributedString`).
* **Considerations for Merging:**
  * Winston uses CoreData (`winston.xcdatamodeld`) and legacy `@ObservedObject` patterns in older views.
  * Licensing: Winston is licensed under **GPL-3.0**. Combining codebases requires adhering to GPL-3.0 compliance.
  * Component extraction: Winston's custom components (`Waterfall`, `ExpandableText`, `LiveTextInteraction`, `CommentsTree`) are modular and can be adapted into Mustard's modern design system.

---

## 3. Universal Multi-Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          SwiftUI Views                          │
│  TimelineScreen │ PostDetailView │ ProfileView │ UniversalSearch│
└────────────────────────────────┬────────────────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────┐
│           Unified Feed Engine & ViewModels (@Observable)        │
│  - UnifiedTimelineService: Aggregates Mastodon, Reddit, Bluesky │
│  - OnDeviceRanker: Scores posts across networks via SwiftData   │
└────────────────────────────────┬────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌────────▼────────┐    ┌─────────▼─────────┐    ┌────────▼────────┐
│ Mastodon Service│    │   Reddit Service  │    │  Bluesky Service│
│ (ActivityPub)   │    │  (Winston Engine) │    │  (AT Protocol)  │
└────────┬────────┘    └─────────┬─────────┘    └────────┬────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────┐
│                   Universal Domain Models                       │
│  - UniversalPost (id, network, author, content, media, stats)   │
│  - UniversalAccount (id, network, handle, avatar, bio)          │
│  - Interaction (SwiftData: action, network, author, tag, time)  │
└─────────────────────────────────────────────────────────────────┘
```

### Universal Post Abstraction
```swift
enum SocialNetwork: String, Codable, CaseIterable, Identifiable {
    case mastodon = "Mastodon"
    case reddit = "Reddit"
    case bluesky = "Bluesky"

    var id: String { rawValue }
}

struct UniversalPost: Identifiable, Hashable {
    let id: String
    let network: SocialNetwork
    let author: UniversalAccount
    let title: String?              // Relevant for Reddit
    let content: String             // HTML for Mastodon, Markdown for Reddit/Bluesky
    let createdAt: Date
    let media: [UniversalMediaAttachment]
    var engagement: UniversalEngagement
    let rawReferenceID: String      // Native network identifier
}
```

---

## 4. Phase-by-Phase Execution Plan

### Phase 1: Clean House in Mustard (Eliminate Legacy Slop)
1. **Unify State Observation:**
   - Migrate `MustardApp.swift` from `@StateObject` / `@EnvironmentObject` to pure `@Observable` and `.environment()`.
   - Convert `TrendingService`, `CacheService`, and `LocationManager` to `@Observable`.
2. **Consolidate Timeline Feeds:**
   - Merge `TimelineProvider` logic directly into `TimelineService`.
   - Remove redundant feed duplication between `TimelineScreen` and `TimelineContentView`.
3. **Refactor Recommendation Engine:**
   - Replace fake `OnDeviceAIService` with a robust, pure-Swift mathematical decay scoring algorithm directly backed by SwiftData's `Interaction` table.
4. **Remove Dead Hooks:**
   - Remove commented GIS/weather code in `LocationService`. Stop automatic location permission prompt unless user enables a nearby trending feature.

---

### Phase 2: Winston (Reddit) Integration
1. **Repository Synchronization:**
   - Fetch and pull latest upstream `alpha` / `main` in `Developer/SwiftUI/winston`.
2. **Extract Reusable Components:**
   - Migrate top-tier Winston components to Mustard's design system:
     - Media player & looper (`EnhancedVideoPlayer`, `AVLooperPlayer`)
     - Expandable markdown renderer (`ExpandableText`, `DownAttributedString`)
     - Nested hierarchical comment tree component
3. **Reddit Service Integration:**
   - Port Winston's Reddit API client and OAuth credential store into Mustard's `Services/Backend/Reddit/` module.
   - Map Reddit submissions into `UniversalPost` and subreddits into feeds.

---

### Phase 3: Bluesky (AT Protocol) Integration
1. **AT Protocol Client:**
   - Implement `ATProtoService` conforming to AT Protocol XRPC standards:
     - `com.atproto.server.createSession` (Authentication)
     - `app.bsky.feed.getTimeline` (Reverse chronological home feed)
     - `app.bsky.feed.getCustomFeed` (Custom algorithmic feeds)
     - `app.bsky.feed.searchPosts` / `app.bsky.actor.searchActors`
2. **Data Mapping:**
   - Map AT Protocol `PostView` records into `UniversalPost` and `ProfileViewBasic` into `UniversalAccount`.

---

### Phase 4: Unified Multi-Network Experience & On-Device Curation
1. **Unified Timeline UI:**
   - Allow users to view a **"Unified Feed"** mixing Mastodon, Bluesky, and Reddit, with clear network badges.
   - Provide network toggle filters (e.g. `[All] [Mastodon] [Bluesky] [Reddit]`).
2. **Cross-Network Recommendation Engine:**
   - As users interact (favorite a Mastodon post, upvote a Reddit discussion, like a Bluesky skeet), the SwiftData engine updates cross-network interest affinities.
   - The unified "For You" timeline scores and interleaves content from all connected accounts.
3. **Multi-Account Login Center:**
   - Settings tab updated with an **"Accounts & Networks"** management screen to link or unlink Mastodon instances, Reddit accounts, and Bluesky handles.
