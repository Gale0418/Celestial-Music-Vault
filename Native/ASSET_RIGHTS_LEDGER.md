# CMV 2.0｜素材權利台帳

更新：2026-10-23

所有商店截圖、預覽與 App 內建素材都必須有可追溯權利。未填妥的項目不可進入
App Store metadata 或 Review Kit。本檔只記錄非敏感 locator、摘要與現行檔案 SHA。

## 狀態定義

- **User-attested**：使用者於 2026-10-03 明確聲明目標素材都是本專案使用者與 Codex
  工具協作製作，並授權本任務公開／上架。這是使用者來源與授權聲明，不等於找回原始
  生成事件、prompt 或完整權利鏈。
- **Provenance recorded**：已有可重現的非敏感來源 locator、摘要與現行檔案 SHA；仍須
  由發布者檢查輸出適切性。`User-attested` 與 `Provenance recorded` 分開記錄。
- OpenAI [Terms of Use](https://openai.com/policies/terms-of-use/) 僅作官方條款摘要來源；
  條款的輸入權限、輸出內容與發布前檢查責任仍須依實際情況判斷，本檔不作法律意見。

## 2026-10-08 素材盤點（歷史快照）

下表保留 2026-10-08 的 canonical fixture 與截圖狀態；最新素材進度見下方
「2026-10-23 素材進度」，不可把本表的 `Blocked` 解讀成目前四張新實機圖的狀態。

| 素材 | Repo path／locator | 創作者／權利人 | 授權或產生方式 | 商業散布／修改 | 證據 locator | SHA-256 | 狀態 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| App icon 1024 | `Native/CMV/CMV/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | 本專案使用者／Codex 工具協作製作（user-attested 2026-10-03） | 個別原始生成紀錄未回收 | 使用者聲明允許本任務公開／上架；發布前檢查適切性 | `Native/ASSET_PROVENANCE.md#user-attestation-2026-10-03` | `6e22bba6268a24a33817a0d92d177372042758991b94c29806e14b41f1b348ca` | User-attested |
| App icon 512 | `Native/CMV/CMV/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png` | 本專案使用者／Codex 工具協作製作（user-attested 2026-10-03） | 個別原始生成紀錄未回收 | 使用者聲明允許本任務公開／上架；發布前檢查適切性 | `Native/ASSET_PROVENANCE.md#user-attestation-2026-10-03` | `33432152c84e5c2b93bdaba6478fab5370db7294aafcdbf802b6a362d55acc21` | User-attested |
| Crimson sky | `Native/CMV/CMV/Assets.xcassets/SkyCrimsonNebula.imageset/sky-crimson-nebula.heic` | 本專案使用者／Codex 工具協作製作（user-attested 2026-10-03） | 個別原始生成紀錄未回收 | 使用者聲明允許本任務公開／上架；發布前檢查適切性 | `Native/ASSET_PROVENANCE.md#user-attestation-2026-10-03` | `7ef3fdaba766629e9dc81afba3217013daa4b5b50d91bf317b23e5af6746ab95` | User-attested |
| Saturn orbit sky | `Native/CMV/CMV/Assets.xcassets/SkySaturnOrbit.imageset/sky-saturn-orbit.heic` | CMV 專案使用者（imagegen output） | OpenAI imagegen，2026-09-27；詳 `Native/SATURN_ASSET_PROVENANCE.md` | 依 OpenAI Terms of Use 內容權利條款；發布前仍須檢查適切性 | `Native/SATURN_ASSET_PROVENANCE.md` | `a32853ab3e45283ed48638a8132b271586de2625c73bf96268e890e57e5854c3` | Retired 2026-10-07；historical record，主 App 不再打包 |
| Saturn cloud map | `Native/CMV/CMV/Assets.xcassets/SaturnCloudMap.imageset/saturn-cloud-map.png` | CMV 專案原創程式生成 | `Native/tools/generate_saturn_clouds.swift`，2026-09-27 | 未引用第三方圖片；確定性週期雜訊繪製 | `Native/SATURN_ASSET_PROVENANCE.md` | `93294007673ffc0bcd28a2bf27f7a86709d4bd6913b58fd7ba65c4341eedfccd` | Provenance recorded |
| Milky Way depth sky | `Native/CMV/CMV/Assets.xcassets/SkyMilkyWayDepth.imageset/sky-milky-way-depth.heic` | CMV 專案使用者（imagegen output） | OpenAI imagegen，2026-09-27 | 依 OpenAI Terms of Use 內容權利條款；發布前仍須檢查適切性 | `Native/SATURN_ASSET_PROVENANCE.md` | `38b1c930b9e06186d49590c13a1e6a81c41627e00712f75ca4bfe4b3b00ef01f` | Provenance recorded |
| Emerald sky | `Native/CMV/CMV/Assets.xcassets/SkyEmeraldAurora.imageset/sky-emerald-aurora.heic` | 本專案使用者／Codex 工具協作製作（user-attested 2026-10-03） | 個別原始生成紀錄未回收 | 使用者聲明允許本任務公開／上架；發布前檢查適切性 | `Native/ASSET_PROVENANCE.md#user-attestation-2026-10-03` | `2f1cf9d7e62fbb73528c13b8a107f3ac56e91f414f7d94160910e553d5e38f2f` | Reused 2026-10-08；保留 Emerald 主題原外觀 |
| Amber sky | `Native/CMV/CMV/Assets.xcassets/SkyAmberDawn.imageset/sky-amber-dawn.heic` | 本專案使用者／Codex 工具協作製作（user-attested 2026-10-03） | 個別原始生成紀錄未回收 | 使用者聲明允許本任務公開／上架；發布前檢查適切性 | `Native/ASSET_PROVENANCE.md#user-attestation-2026-10-03` | `6e78834a768513a8563b39947275dec8dbd04a0a136a97b4b40198d386b970bc` | User-attested |
| Rainbow meadow background | `Native/CMV/CMV/Assets.xcassets/SheepRainbowMeadow.imageset/sheep-rainbow-meadow.png` | 本專案使用者／Codex 工具協作製作（user-attested 2026-10-03；provenance recorded） | 已記錄 imagegen event、最終 prompt 摘要與 shipping source；原始生成日期未回收 | 使用者聲明允許本任務公開／上架；發布前檢查適切性 | `Native/ASSET_PROVENANCE.md#rainbow-background` | `a20f10e904d53ce2e40f7bc213c2d57b20dcaff42eeca8f548f9e0a29c2e485b` | User-attested + Provenance recorded |
| Sheep rocket | `Native/CMV/CMV/Assets.xcassets/SheepRocket.imageset/sheep-rocket.png` | 本專案使用者／Codex 工具協作製作（user-attested 2026-10-03） | 個別原始生成紀錄未回收 | 使用者聲明允許本任務公開／上架；發布前檢查適切性 | `Native/ASSET_PROVENANCE.md#user-attestation-2026-10-03` | `d0837aac40308d70fb21171b839c26e4f46f345e605fd0e077b5b90b8f36ae6b` | User-attested |
| Sheep sleep | `Native/CMV/CMV/Assets.xcassets/SheepSleep.imageset/sheep-sleep.png` | 本專案使用者／Codex 工具協作製作（user-attested 2026-10-03） | 個別原始生成紀錄未回收 | 使用者聲明允許本任務公開／上架；發布前檢查適切性 | `Native/ASSET_PROVENANCE.md#user-attestation-2026-10-03` | `c00e176d9e1c95a4ea9cf90db6bb39e769136e03a99c6de507c534ac27c2836a` | User-attested |
| Sheep tumble | `Native/CMV/CMV/Assets.xcassets/SheepTumble.imageset/sheep-tumble.png` | 本專案使用者／Codex 工具協作製作（user-attested 2026-10-03；provenance recorded） | 已記錄 imageGeneration revisions、final output 與 shipping copy；現行 SHA 已核對 | 使用者聲明允許本任務公開／上架；發布前檢查適切性 | `Native/ASSET_PROVENANCE.md#sheep-tumble` | `d8a71b232a87952d47a70c17fcf68231bd04460cad1e1d5dc1d10f5c45af93fe` | User-attested + Provenance recorded |
| Sheep umbrella | `Native/CMV/CMV/Assets.xcassets/SheepUmbrella.imageset/sheep-umbrella.png` | 本專案使用者／Codex 工具協作製作（user-attested 2026-10-03） | 個別原始生成紀錄未回收 | 使用者聲明允許本任務公開／上架；發布前檢查適切性 | `Native/ASSET_PROVENANCE.md#user-attestation-2026-10-03` | `0334a7a762ae82fe16b770644ff55fb7b52d321c6b5af6b66c20945e426190bc` | User-attested |
| Review WAV 01 Cobalt Echoes | `/tmp/cmv-owned-review-media/01-cobalt-echoes.wav` | WindSheep project original generated fixture（使用者授權 Codex 創作） | `Native/ReviewMedia/generate-review-media.swift`；原創 deterministic PCM arpeggio | 可供受控發布與審核測試；StoreScreenshots 尚未 capture | `Native/ReviewMedia/generated-manifest.json#artifacts/01-cobalt-echoes.wav` | `96da3f07d7f89419a3b78c770863e25c4e262ac1e8bea030a755e353fd8ce0f0` | Provenance recorded；StoreScreenshots Blocked |
| Review WAV 02 Amber Circuit | `/tmp/cmv-owned-review-media/02-amber-circuit.wav` | WindSheep project original generated fixture（使用者授權 Codex 創作） | `Native/ReviewMedia/generate-review-media.swift`；原創 deterministic PCM arpeggio | 可供受控發布與審核測試；StoreScreenshots 尚未 capture | `Native/ReviewMedia/generated-manifest.json#artifacts/02-amber-circuit.wav` | `b43fa0ebbadae98d00dd2af5016ab390f976e75d3481328bebf634ae9a17b7c7` | Provenance recorded；StoreScreenshots Blocked |
| Review WAV 03 Violet Tide | `/tmp/cmv-owned-review-media/03-violet-tide.wav` | WindSheep project original generated fixture（使用者授權 Codex 創作） | `Native/ReviewMedia/generate-review-media.swift`；原創 deterministic PCM arpeggio | 可供受控發布與審核測試；StoreScreenshots 尚未 capture | `Native/ReviewMedia/generated-manifest.json#artifacts/03-violet-tide.wav` | `dc4b3b5d1cfa511bd6d30b765bfe341762bf2c4cc83158b7c95231dc0581f001` | Provenance recorded；StoreScreenshots Blocked |
| Review WAV 04 Silver Orbit | `/tmp/cmv-owned-review-media/04-silver-orbit.wav` | WindSheep project original generated fixture（使用者授權 Codex 創作） | `Native/ReviewMedia/generate-review-media.swift`；原創 deterministic PCM arpeggio | 可供受控發布與審核測試；StoreScreenshots 尚未 capture | `Native/ReviewMedia/generated-manifest.json#artifacts/04-silver-orbit.wav` | `825775d8a808510dd0e935d67c9afdd85e43c07cc208f592b858764ffabc9377` | Provenance recorded；StoreScreenshots Blocked |
| Review H.264/AAC MOV | `/tmp/cmv-owned-review-media/eof-pip-fixture.mov` | WindSheep project original generated fixture（使用者授權 Codex 創作） | `Native/ReviewMedia/generate-review-media.swift`；H.264 24fps/288 frames + AAC audio | 可供 EOF/PiP 受控發布與審核測試；StoreScreenshots 尚未 capture | `Native/ReviewMedia/generated-manifest.json#artifacts/eof-pip-fixture.mov` | `284956fd8bfe7e0d0bf2555cf7ff793ea6a42bd4c26db8c5ed394b99f44389fa` | Provenance recorded；StoreScreenshots Blocked |
| Review CoreGraphics cover | `/tmp/cmv-owned-review-media/review-cover.png` | WindSheep project original generated fixture（使用者授權 Codex 創作） | `Native/ReviewMedia/generate-review-media.swift`；原創 CoreGraphics 1024×1024 PNG | 可供受控發布與審核測試；StoreScreenshots 尚未 capture | `Native/ReviewMedia/generated-manifest.json#artifacts/review-cover.png` | `e253b655cf86b353718077e633d8c9feb660e57058b854feec3ef8bb27e212ae` | Provenance recorded；StoreScreenshots Blocked |
| Mac screenshots／preview | `[待建立]` | `[待填]` | CMV RC 實機擷取 | `[待確認畫面內媒體]` | `[待填]` | `[待產生]` | Blocked |
| iPad screenshots／preview | `[待建立]` | `[待填]` | CMV RC 實機擷取 | `[待確認畫面內媒體]` | `[待填]` | `[待產生]` | Blocked |

## 2026-10-23 素材進度（最新）

- 四張新實機截圖已完成：Mac 兩張 2880×1800、iPad 兩張 2360×1640，全部為橫向。
- 兩張 image_gen 裝置 mockup 已完成，並明確標示為 mockup，不冒稱實機擷取。
- 13 吋 Simulator 橫向圖仍在補拍；final archive／export／upload／遠端回讀與送審仍 pending。

## 2026-10-07 退休素材註記

- `SkySaturnOrbit.imageset` 於 2026-10-07 退休；`SkyEmeraldAurora.imageset` 曾同批退休，但 2026-10-08 已因可選 Emerald 主題復用精確備份，現行權利與 SHA 紀錄不變。
- 可恢復備份位於 repo 相對路徑 `.cmv-local-evidence/2026-10-04-remaining-validation/unused-background-cleanup-20261007/removed-assets/Native/CMV/CMV/Assets.xcassets/`；備份內 HEIC SHA 分別為 `2f1cf9d7e62fbb73528c13b8a107f3ac56e91f414f7d94160910e553d5e38f2f` 與 `a32853ab3e45283ed48638a8132b271586de2625c73bf96268e890e57e5854c3`。
- `SkyMilkyWayDepth` 未退休，仍依原紀錄保留。

## 規則

- 使用者自己的私人媒體不等於可公開用於 App Store 截圖；本次 user-attested 只涵蓋上述
  目標素材與本任務公開／上架授權。
- `User-attested` 不得寫成已找回的生成紀錄；沒有原始 prompt、event 或來源時，明確保留
  「個別原始生成紀錄未回收」。
- 產生式素材若有可靠紀錄，須記錄非敏感工具／event locator、prompt 摘要、來源參考、
  條款摘要與現行 SHA；不得從檔案存在推定權利，也不得把未知工具臆寫成特定工具。
- 商業歌曲、專輯封面、串流服務 UI、YouTube／VTuber 影片預設為不可用，除非有
  明確書面授權涵蓋商業宣傳與再散布。
- 每次替換檔案都要更新 SHA-256 與證據，不沿用舊結論；損壞或缺少證據不刪除主曲庫。

## 2026-10-08 原創審核素材現行 locator

六個 `/tmp/cmv-owned-review-media/` locator 為歷史生成位置；現行同 SHA 檔案與非敏感 locator 見
[既有檔案讀回](ReviewMedia/existing-fixture-readback-20261008.json)。本次六檔均實際讀回符合原 manifest，
沿用已記錄的原創 fixture 來源與授權，不新增媒體副本。收據的 generator SHA 是目前來源指紋，
不表示找回歷史生成版本。額外 Long 音訊不納入這六檔證據，商店截圖／影片仍須綁定實際畫面內素材。


## 2026-10-09 原創VTuber封面與八張英文裝置宣傳圖

使用者明確要求原創虛擬歌手、四套天空各一封面及Mac/iPad各四張宣傳圖。工具為內建`image_gen.imagegen`；本輪完整八張提示詞位於本機 ignored-only locator `Native/ReviewMedia/vtuber-covers/20261009/single-device-prompts.json`（未納入版本控制），cover manifest與single-device manifest的現行SHA也只由本機 ignored evidence 保存。封面提示摘要：成年虛構銀紫髮歌手、月牙髮飾、麥克風演唱，四套不同天空；沒有指定第三方角色、真人或YouTube品牌。宣傳圖参考本專案實際UI及已有背景素材；不是複製GAI app內容。歌曲/歌手/專輯文字是虛構示範。生成原圖和最終RGB尺寸版均保存，後者僅經使用者授權等比例縮放／最小留邊。這是本機可追溯生成來源紀錄，不是 repository-verifiable evidence、第三方法律授權證書或Apple審核結論；尚未公開上傳。裝置內生成UI仍待實際忠實度核對，不能作實機證據。


2026-10-09 Mac圖示修正：四張Mac宣傳圖由相同內建imagegen進行單一元素編修，將不存在於Mac介面的AirPlay類图示改成音效滑桿。完整edit target／prompt／tool來源見本機 ignored-only locator `Native/ReviewMedia/vtuber-covers/20261009/mac-icon-correction-inputs.json`（未納入版本控制）；現行八張SHA見本機 ignored manifest `Native/ReviewMedia/vtuber-covers/20261009/single-device-v2/manifest.json`。iPad四張原件未改。舊版與生成原圖保留。仍為宣傳示意，不宣稱native capture或Apple接受。
