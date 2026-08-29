# 星穹私藏音樂庫 Celestial Music Vault（CMV）2.0 Product Authority

## Product

- **Product:** 星穹私藏音樂庫 Celestial Music Vault（CMV）2.0
- **Promise:** A private, dependable native music library for people who keep a very large local or NAS collection and expect it to remain usable when the network is not.
- **Primary audience:** One owner of a carefully maintained personal collection, using a Mac or iPad at home, at a desk, or connected to a NAS on the local network.
- **Unique mechanism:** CMV turns a user-authorized folder into a durable offline-first library, then combines local acoustic analysis with transparent listening history to create explainable queues without uploading audio.
- **Cultural home:** Dream atlases, blue-hour skies, luminous clouds, constellations, auroras, and the childhood feeling of finding whole worlds inside music.

## Platforms and distribution

- One Swift 6 and SwiftUI codebase targeting macOS 15+ and iPadOS 18+.
- Mac and iPad are complete standalone players. There is no remote control, Handoff, account, library synchronization, or cross-device state.
- Public App Store distribution with Apple sandboxing and privacy declarations.
- iPhone, Windows, Linux, and Android are out of scope.

## Core jobs

1. Authorize a local or NAS-mounted folder through the system folder picker.
2. Index and search collections of up to 50,000 tracks without blocking browsing or playback.
3. Preserve library records when a NAS sleeps, Wi-Fi drops, a bookmark expires, or access is revoked.
4. Play albums gaplessly with ReplayGain/R128 normalization, limiter protection, EQ, system media controls, background audio, and AirPlay.
5. Inspect and edit useful library organization: albums, artists, playlists, favorites, ratings, metadata, artwork, and listening history.
6. Analyze BPM, key, loudness, and acoustic features entirely on device; create an explainable Smart DJ queue while offline.
7. Pin selected media for guaranteed offline use and maintain a separate budgeted smart cache.
8. Play video naturally on each platform: a draggable AVPlayerView utility window on Mac and full-screen AVPlayerViewController with PiP on iPad.

## Product truths and constraints

- The user connects a NAS in Finder or the Files app first. CMV never implements SMB login and never stores NAS credentials.
- Persist access with security-scoped bookmarks. A temporarily unavailable source is not deletion.
- Pinned media lives in Application Support and is never evicted by LRU. Smart cache lives in Caches, defaults to 10 GB, and may evict only unpinned content.
- The legacy Electron app and its data stay untouched until the native release passes acceptance. No legacy migration is provided.
- Apple first-party application frameworks remain the only UI, media, persistence,
  sandbox, and platform-integration dependencies. An in-repository Rust static
  library may implement deterministic, platform-neutral core logic behind a
  narrow versioned C ABI; it never owns SwiftUI, SwiftData, security-scoped URL,
  AVFoundation, AVKit, or MediaPlayer objects.
- No cloud AI, analytics tracker, account system, or audio upload. Diagnostics use OSLog and MetricKit.
- Import, analysis, cache maintenance, and reconnect work never block the main actor.

## Information architecture

- **Mac:** NavigationSplitView with listening, songs, albums, artists, playlists, favorites, and settings in the sidebar; content in the center; a collapsible queue/details inspector; compact bottom transport.
- **iPad landscape:** Adaptive two- or three-column library with keyboard, pointer, and Stage Manager support.
- **iPad portrait and narrow split:** Bottom tabs plus NavigationStack, with a mini-player pinned above the safe area and an expandable Now Playing surface.
- “加入音樂來源” is the canonical acquisition language. Mac may also accept a folder drop; iPad uses the system folder picker.
- Theme choice belongs in Settings and never changes control placement, navigation meaning, or data state.

## Visual commitments

- Four complete celestial-weather themes share one component and interaction contract:
  - **緋紅星雲:** coral and crimson nebulae, rose clouds, warm stardust.
  - **鈦銀月蝕:** midnight indigo, moon-silver clouds, cool cyan starlight.
  - **翠綠極光:** emerald auroras, deep teal sky, prismatic mist.
  - **琥珀晨曦:** golden cloud edges, peach sunrise, lavender distance.
- The default visual world is the **Celestial Cloud Atlas**: albums become luminous cloud-worlds, source and offline state become small functional constellations, and playback progression becomes a restrained ribbon of colored starlight.
- The celestial world must remain operational: atmospheric illustration stays behind semantic controls, large artwork never hides library status, and Reduce Motion has a deliberate static composition.
- Use native controls, system materials, SF Symbols, semantic color roles, and readable text at every Dynamic Type size.
- Every action has a 44 by 44 point target and works with VoiceOver, increased contrast, Reduce Motion, keyboard, and pointer where applicable.
- Motion explains queue, player, and navigation state; it never gates information.
- Vinyl, turntable, mastering-console, lacquer, and dark audiophile-hardware metaphors are explicitly not part of the product identity.

## Success and acceptance

- First verifiable milestone: Mac and iPad authorize the same kind of folder source, index a test library, preserve access after relaunch, and continue audio in lock/background states.
- A 50,000-track library completes initial and differential scans; visible search results update within 150 ms and scrolling remains responsive.
- NAS failures never clear the catalog or freeze the UI.
- Gapless fixtures lose or duplicate no detectable audio frames; ReplayGain, limiter, and EQ switching creates no pop.
- Smart DJ functions in airplane mode and displays why each track was selected.
- Complete device and simulator validation covers accessibility, memory pressure, PiP, Stage Manager, full screen, source reauthorization, privacy, and sandboxing.

## Deliberate exclusions

- No cross-device control or synchronization.
- No early public partial release; internal milestones remain independently buildable and testable.
- No copied desktop floating-window metaphor on iPad.
- No permanent theme controls in primary navigation.
- No 50,000-view eager rendering.
