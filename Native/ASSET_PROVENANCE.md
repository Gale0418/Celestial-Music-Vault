# CMV 素材 provenance record

更新：2026-10-03

本檔是非敏感的來源摘要，與 `Native/ASSET_RIGHTS_LEDGER.md` 的權利狀態分開維護。
`User-attested` 是使用者本次聲明；`Provenance recorded` 是已找得到來源 locator、
摘要與現行 SHA。兩者不互相取代，也不把檔案存在推定成權利證明。

## User attestation 2026-10-03

使用者明確聲明本次目標素材「都是你做的=w=」，確認由本專案使用者與 Codex 工具協作
製作，並授權本任務公開／上架。這是 2026-10-03 的來源與散布授權聲明，不是原始生成
日期、原始 prompt、特定工具呼叫或法律名稱的補寫；個別素材的原始生成紀錄未回收時，
仍標示為 `User-attested`。

## Rights reference（法律摘要與觀測事實分開）

官方來源：[OpenAI Terms of Use](https://openai.com/policies/terms-of-use/)。本次查閱頁面
的官方摘要指出：在使用者與 OpenAI 之間，使用者依適用法律擁有 Output，且 OpenAI 將其
對 Output 的權利、所有權與利益轉讓給使用者（以法律允許範圍為限）；使用者負責 Input
所需的權利、授權與許可，並須在分享前自行評估輸出的正確性與適切性。這只是條款摘要，
不是法律意見，也不涵蓋其他使用者輸出或第三方素材相似性。

## Target manifest

| 素材 | Repo path | 現行 SHA-256 | 狀態 | 來源紀錄 |
| --- | --- | --- | --- | --- |
| App icon 1024 | `Native/CMV/CMV/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | `6e22bba6268a24a33817a0d92d177372042758991b94c29806e14b41f1b348ca` | User-attested | 個別原始生成紀錄未回收 |
| App icon 512 | `Native/CMV/CMV/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png` | `33432152c84e5c2b93bdaba6478fab5370db7294aafcdbf802b6a362d55acc21` | User-attested | 個別原始生成紀錄未回收 |
| Crimson sky | `Native/CMV/CMV/Assets.xcassets/SkyCrimsonNebula.imageset/sky-crimson-nebula.heic` | `7ef3fdaba766629e9dc81afba3217013daa4b5b50d91bf317b23e5af6746ab95` | User-attested | 個別原始生成紀錄未回收 |
| Emerald sky | `Native/CMV/CMV/Assets.xcassets/SkyEmeraldAurora.imageset/sky-emerald-aurora.heic` | `2f1cf9d7e62fbb73528c13b8a107f3ac56e91f414f7d94160910e553d5e38f2f` | User-attested | 個別原始生成紀錄未回收 |
| Amber sky | `Native/CMV/CMV/Assets.xcassets/SkyAmberDawn.imageset/sky-amber-dawn.heic` | `6e78834a768513a8563b39947275dec8dbd04a0a136a97b4b40198d386b970bc` | User-attested | 個別原始生成紀錄未回收 |
| Sheep rocket | `Native/CMV/CMV/Assets.xcassets/SheepRocket.imageset/sheep-rocket.png` | `d0837aac40308d70fb21171b839c26e4f46f345e605fd0e077b5b90b8f36ae6b` | User-attested | 個別原始生成紀錄未回收 |
| Sheep sleep | `Native/CMV/CMV/Assets.xcassets/SheepSleep.imageset/sheep-sleep.png` | `c00e176d9e1c95a4ea9cf90db6bb39e769136e03a99c6de507c534ac27c2836a` | User-attested | 個別原始生成紀錄未回收 |
| Sheep tumble | `Native/CMV/CMV/Assets.xcassets/SheepTumble.imageset/sheep-tumble.png` | `d8a71b232a87952d47a70c17fcf68231bd04460cad1e1d5dc1d10f5c45af93fe` | User-attested + Provenance recorded | 見下節 |
| Sheep umbrella | `Native/CMV/CMV/Assets.xcassets/SheepUmbrella.imageset/sheep-umbrella.png` | `0334a7a762ae82fe16b770644ff55fb7b52d321c6b5af6b66c20945e426190bc` | User-attested | 個別原始生成紀錄未回收 |
| Rainbow meadow background | `Native/CMV/CMV/Assets.xcassets/SheepRainbowMeadow.imageset/sheep-rainbow-meadow.png` | `a20f10e904d53ce2e40f7bc213c2d57b20dcaff42eeca8f548f9e0a29c2e485b` | User-attested + Provenance recorded | 見下節 |

## Sheep tumble

這列的來源已由已授權 CMV 體驗 thread `01a059e7-fce6-7f21-9499-1235f5400a4e` 的舊 turn
`01a0d42e-ba93-7853-af9d-4abe67cce4c6` 核對。該 turn 觀測到四個 SheepTumble
imageGeneration event：`exec-c897c16b-2570-4b39-abe9-f428163bd7c4` 是最後採用的透明
仰躺小羊輸出，前置修正版為 `exec-d110bce6-ee4c-4f86-be69-8ecf1b926223`、
`exec-af78c064-7e90-4b3b-944c-e2e46e8a1def`、`exec-39e71028-ea65-41fe-bf7f-4aad0c8b1420`。
這些 event 的 prompt 摘要都只描述同一隻透明背景、薄荷蝴蝶結、四肢自然連接的小羊，
並修正頭部與身體一致的翻滾方向。

之後的 `sips` copy command（`exec-8de29e25-3cda-4706-960a-fd74d9d64c60` 與
`exec-ca2f8a0c-6d94-4f3a-b2f9-eb9debd5e2cb`）明確以最後輸出 event `exec-c897c16b-2570-4b39-abe9-f428163bd7c4.png`
作為來源，寫入 `Native/CMV/CMV/Assets.xcassets/SheepTumble.imageset/sheep-tumble.png`。
2026-10-03 以 `shasum -a 256` 核對 shipping file，現行 SHA 為
`d8a71b232a87952d47a70c17fcf68231bd04460cad1e1d5dc1d10f5c45af93fe`。因此本列具備
event → copy target → current hash 的 provenance chain；原始生成日期仍未宣稱。

## Rainbow background

已觀測到最終 shipping asset 位於 `Native/CMV/CMV/Assets.xcassets/SheepRainbowMeadow.imageset/`
並在公開 rewrite 後的 git commit `a44c62b5b5df197e14bdba58fcaf46f965102a0e`
（`feat: add anime rainbow sky and storybook sheep theme UI`）納入；不引用 privacy rewrite
前的私人歷史 locator。
非敏感來源 locator 如下：

- `docs/design/sheep-storybook-ui.md` 記有最終 asset 路徑、prompt 摘要與 imagegen event
  locator `exec-09e84234-e175-4427-a2e3-b0ea88346ae0.png`。
- `MissionCenter/notes.md` 記有相同的非敏感 prompt／event 摘要；已授權的 CMV 體驗
  thread 也觀測到該 imagegen 輸出被複製到 shipping path 的事件。
- 最終 prompt 摘要：保留大型粉彩彩虹拱門；移除地面、丘陵、湖泊、樹木、植物、花朵、
  柵欄、建築與羊；保留通透青綠天空、奶油色雲朵、藍灰輪廓、寬闊乾淨中央；3:2
  橫向、無文字／浮水印。這是摘要，不是逐字重建原始 prompt。

原始生成日期未回收；git commit／檔案時間只代表 shipping record，不宣稱原始生成日期。
此列同時保留使用者 2026-10-03 的 user-attested 公開／上架授權。

## Missing evidence retained explicitly

App icon 1024／512、Crimson／Emerald／Amber 三張 sky，以及 SheepRocket／Sleep／
Umbrella 三張 sheep，目前已逐一核對現行 SHA，但只找到本次 user attestation，未找回各自
的原始 prompt、生成事件或來源檔；因此不標示為 `Provenance recorded`。Review audio／
video／cover、Mac screenshots、iPad screenshots 仍待建立與審查，維持 `Blocked`。

SHA-256 是以 2026-10-03 工作樹現行檔案執行 `shasum -a 256` 的觀測結果；替換素材時須
重新計算並同步更新台帳。
