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

These jobs describe the intended complete product. Completion evidence and open
release gates remain in `MissionCenter/tasks.md`.

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

## 免費與 Pro（2026-09-08 核准方向）

CMV 採免費下載＋一次性 Pro 解鎖。免費版提供可日常使用的本機影音、基本 NAS
來源播放、搜尋、基本歌單、收藏評分、日常佇列操作、背景播放、預設主題與月環。
穩定性、資料保護及無障礙由兩個版本共同提供。

Pro 的價值在於智慧離線快取與批次釘選、進階曲庫整理與批次工具、更多主題與
視覺自訂，以及本機 Smart DJ／聲學探索。裝置上原本就有的可存取檔案仍可免費
播放；NAS 基本播放與維持正常播放所需的暫存，不改成 Pro 才能使用。

一次性購買不自動續訂。價格、Mac／iPad 購買權益是否共用、家庭共享、未來大版本更新範圍尚未定案，不承諾所有未來功能終身免費。CMV 不建立
自己的帳號系統；購買與恢復購買仍須另行完成平台驗證。

商業方案與上市文案見 [免費＋一次性 Pro 草案](Native/MONETIZATION_DRAFT.md)。
使用者指定文案以任務中心既定功能全部完成為上市情境；該假設不能作為功能、
付費解鎖或上架驗收已通過的證據。2026-09-08 施工切片以緋紅星雲為免費主題，其他三款的新選用由 Pro 解鎖；
保留使用者目前已選的主題及既有離線內容。StoreKit 商品尚未設定時不開放付款。

## Information architecture

- **Mac:** NavigationSplitView with listening, songs, albums, artists, playlists, favorites, and settings in the sidebar; content in the center; a collapsible queue/details inspector; compact bottom transport.
- **iPad landscape:** Adaptive two- or three-column library with keyboard, pointer, and Stage Manager support.
- **iPad portrait and narrow split:** Bottom tabs plus NavigationStack, with a mini-player pinned above the safe area and an expandable Now Playing surface.
- “加入音樂來源” is the canonical acquisition language. Mac may also accept a folder drop; iPad uses the system folder picker.
- Theme choice belongs in Settings and never changes control placement, navigation meaning, or data state.

## Visual commitments

- Four complete celestial-weather themes share one component and interaction contract:
  - **銀河月夜:** deep blue night sky and cool starlight.
  - **土星環軌站:** an immense fixed Saturn on the right, subtly moving cloud bands and softly lit rings.
  - **綿羊幻想鄉:** emerald and rose atmosphere with animated sheep.
  - **星海晨光:** golden cloud edges, peach sunrise, lavender distance.
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
