# CMV 2.0｜App Review Kit

更新：2026-09-01

這是 App Review Notes、實機示範與審核回覆的 canonical 草稿。方括號欄位必須由
發布者填寫；不得將 Apple ID、API key、憑證、NAS 密碼或私人媒體放進版本控制。

## Release identity

- App：星穹私藏音樂庫 Celestial Music Vault
- Bundle ID：`com.windsheep.cmv`
- Version／build：`2.0`／`1`（上傳前以遠端安全 build number 為準）
- Platforms：macOS 15+、iPadOS 18+
- Primary language：Traditional Chinese (`zh-Hant`)
- Review contact：`[法律姓名]`／`[可收信 email]`／`[含國碼電話]`

## App Review Notes 草稿

Celestial Music Vault is a local media-library player. Basic playback, search, playlists,
favorites, ratings, and everyday queue controls are free. CMV Pro is an optional one-time
in-app purchase with no subscription. It unlocks offline pinning and smart prefetch,
the gated Titanium Eclipse (Saturn Ring Station) and Emerald Aurora (Sheep
Dreamland) themes, on-device acoustic analysis, and Smart DJ recommendations. The app
does not implement SMB login, local-network discovery, cloud sync, advertising,
tracking, or cloud AI.

To test:

1. Open Settings and choose Add Music Source.
2. On macOS, choose a local folder with the system folder picker. On iPad, choose a folder
   through Files. For a NAS folder, connect it in Finder or Files before opening CMV; CMV
   never asks for or stores NAS credentials.
3. Indexing runs in the background and reports progress without blocking playback or UI.
4. Open Songs and select a rights-cleared audio track. Test queue, shuffle, repeat,
   favorites, five-star ratings, playlists, and sleep timer.
5. Select a rights-cleared MP4, MOV, or M4V file to test mixed audio/video playback. iPad
   uses the native player and Picture in Picture.
6. Force-quit and reopen the app to verify that the selected source remains authorized.

After purchasing Pro with an App Review Sandbox account:

1. In Settings, open CMV Pro, purchase the one-time product, and use Restore Purchases
   to verify the entitlement can be restored.
2. Pin a rights-cleared track for offline playback and verify smart prefetch on the
   next tracks. Disconnect the source only after the pinned file is ready.
3. Open Smart DJ from Playlists or Settings, generate a queue, inspect its reasons,
   and play it. Run on-device analysis from Now Playing for an audio track.
4. Choose Saturn Ring Station or Sheep Dreamland in theme settings; these are
   the Titanium Eclipse and Emerald Aurora Pro themes, respectively.

The app processes media, artwork, metadata, acoustic analysis, and listening history only
on the device. It does not upload audio, PCM, video, artwork, metadata, analysis results,
or listening history. Removing an item from CMV does not delete the original file.

No credentials are required for free features; App Review can use a Sandbox account
for CMV Pro. Review media: `[rights-cleared download URL or attachment reference]`.
Tested on `[device]`, `[OS version]`, on `[date]`.

## 無剪輯實機影片 shot list

每個平台各錄一段連續影片，不剪接、不遮住系統提示：

1. 顯示 App 版本與平台。
2. 以系統 picker 加入 rights-cleared 本機資料夾。
3. 顯示背景索引進度、歌曲列表與立即播放。
4. 展示 queue、評分、最愛、歌單、shuffle／repeat、背景／鎖屏控制。
5. 斷開來源後顯示曲庫仍保留、離線釘選仍可播放，再重新授權。
6. iPad 額外展示 Files provider、Split View、背景播放與 PiP；Mac 額外展示影片
   utility window 與回到月環。

## MediBuddy 2.1 經驗的處理規則

- 若 Apple 要的是操作方法、測試環境或影片，先補完整 Review Notes／影片並在
  Resolution Center 回覆；沒有程式缺陷證據時不要盲目重建 build。
- `Waiting for Review`／`In Review` 只代表等待或審核中，不等於完成。
- 若 Apple 指出實際 crash、缺功能或 metadata 與 binary 不一致，才建立修復任務、
  重跑相同 gate 並決定是否上傳新 build。

## 送審前人工核准

- `[ ]` Privacy Policy URL 公開可讀
- `[ ]` Support URL 與聯絡方式公開可讀
- `[ ]` Review contact 是可驗證法律人／團隊
- `[ ]` Mac／iPad Review media 權利證據已登錄
- `[ ]` App Store Connect privacy answers 與 manifest／政策一致
- `[ ]` Review Notes 已貼入正確 IOS 與 MAC_OS platform version
- `[ ]` 無任何 Apple ID、API key、憑證或 NAS 帳密落盤
