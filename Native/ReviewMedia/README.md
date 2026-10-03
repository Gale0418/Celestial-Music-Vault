# ReviewMedia fixture generator

## 繁中說明

這個工具會在 macOS 本機產生可重現的審核測試素材，預設輸出到
`/tmp/cmv-owned-review-media`，不會把音訊、影片或封面直接加入 repo。當輸出要交給
受控發布檔案庫時，先保留同一目錄的 `manifest.json`；本 repo 的
`generated-manifest.json` 是本輪已驗證輸出的非敏感快照。

實際執行命令：

```sh
swiftc -module-cache-path /tmp/cmv-review-media-module-cache Native/ReviewMedia/generate-review-media.swift -o /tmp/cmv-generate-review-media
/tmp/cmv-generate-review-media --output /tmp/cmv-owned-review-media
cp /tmp/cmv-owned-review-media/manifest.json Native/ReviewMedia/generated-manifest.json
```

產生器會在寫出 manifest 前讀回並驗證 WAV 的 linear PCM／stereo／44.1 kHz、MOV 的
H.264 `avc1`／AAC `aac `／24 fps／288 frames，以及 PNG 的 1024×1024 尺寸。這些是
格式與檔案完整性證據，不代表人工聽感、實機播放、EOF/PiP 感知驗收或 Apple 審核已通過；
StoreScreenshots 仍維持 Blocked。輸出目錄可在交付後刪除，重新生成會更新素材 SHA，需同步
更新 ledger 與 manifest 快照。

`generate-review-media.swift` creates deterministic, original review fixtures in `/tmp/cmv-owned-review-media` by default:

- four 18–21 second stereo WAV arpeggios with distinct titles, tempi, and keys;
- one 12 second, 24 fps / 288-frame H.264/AAC MOV for EOF and PiP checks;
- one 1024×1024 CoreGraphics PNG cover;
- `manifest.json` with SHA-256 digests, read-back durations, codec names, stereo/44.1 kHz audio fields, and dimensions.

The source synthesizes every sample and pixel. It does not read external music, text, or images. WAV read-back verifies linear PCM, stereo, and 44.1 kHz; the MOV is exported with AAC audio and read-back requires `aac ` plus H.264 `avc1`. The rights statement is `WindSheep project original generated fixture`; the user authorized Codex to create these fixtures for the project. Human listening and App Store review approval remain separate checks.

Run on macOS without Xcode project build steps:

```sh
swiftc -module-cache-path /tmp/cmv-review-media-module-cache Native/ReviewMedia/generate-review-media.swift -o /tmp/cmv-generate-review-media
/tmp/cmv-generate-review-media --output /tmp/cmv-owned-review-media
```

The output directory is disposable and intentionally outside the repository. The manifest is generated only after AVAsset duration/track read-back and PNG dimension validation succeed.

## 本輪公開下載

原倉庫的 [原創審核測試附件](https://github.com/Gale0418/Celestial-Music-Vault/releases/tag/cmv-review-fixtures-20261003) 提供同一批 6 份媒體與 manifest。ZIP SHA-256：`e3b766ec3a828fc8d11e8ac90b1468a5cea5e8f8ba600a79184aa39e68bf72d6`。
