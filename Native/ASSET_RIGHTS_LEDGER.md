# CMV 2.0｜素材權利台帳

更新：2026-09-27

所有商店截圖、預覽與 App 內建素材都必須有可追溯權利。未填妥的項目不可進入
App Store metadata 或 Review Kit。證明文件可保存於受控發布檔案庫；本檔只記錄
非敏感 locator 與摘要。

| 素材 | Repo path／locator | 創作者／權利人 | 授權或產生方式 | 商業散布／修改 | 證據 locator | SHA-256 | 狀態 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| App icon 1024 | `Native/CMV/CMV/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | `[待填]` | `[待填]` | `[待確認]` | `[待填]` | `6e22bba6268a24a33817a0d92d177372042758991b94c29806e14b41f1b348ca` | Blocked |
| App icon 512 | `Native/CMV/CMV/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png` | `[待填]` | `[待填]` | `[待確認]` | `[待填]` | `33432152c84e5c2b93bdaba6478fab5370db7294aafcdbf802b6a362d55acc21` | Blocked |
| Crimson sky | `Native/CMV/CMV/Assets.xcassets/SkyCrimsonNebula.imageset/sky-crimson-nebula.heic` | `[待填]` | `[待填]` | `[待確認]` | `[待填]` | `0289338209162006e105fc09378df285a1295498653387afd6938f2702cc5b96` | Blocked |
| Saturn orbit sky | `Native/CMV/CMV/Assets.xcassets/SkySaturnOrbit.imageset/sky-saturn-orbit.heic` | CMV 專案使用者（imagegen output） | OpenAI imagegen，2026-09-27；詳 `Native/SATURN_ASSET_PROVENANCE.md` | 依 OpenAI Terms of Use 內容權利條款；發布前仍須檢查適切性 | `Native/SATURN_ASSET_PROVENANCE.md` | `a32853ab3e45283ed48638a8132b271586de2625c73bf96268e890e57e5854c3` | Provenance recorded |
| Saturn cloud map | `Native/CMV/CMV/Assets.xcassets/SaturnCloudMap.imageset/saturn-cloud-map.png` | CMV 專案原創程式生成 | `Native/tools/generate_saturn_clouds.swift`，2026-09-27 | 未引用第三方圖片；確定性週期雜訊繪製 | `Native/SATURN_ASSET_PROVENANCE.md` | `93294007673ffc0bcd28a2bf27f7a86709d4bd6913b58fd7ba65c4341eedfccd` | Provenance recorded |
| Milky Way depth sky | `Native/CMV/CMV/Assets.xcassets/SkyMilkyWayDepth.imageset/sky-milky-way-depth.heic` | CMV 專案使用者（imagegen output） | OpenAI imagegen，2026-09-27 | 依 OpenAI Terms of Use 內容權利條款；發布前仍須檢查適切性 | `Native/SATURN_ASSET_PROVENANCE.md` | `38b1c930b9e06186d49590c13a1e6a81c41627e00712f75ca4bfe4b3b00ef01f` | Provenance recorded |
| Emerald sky | `Native/CMV/CMV/Assets.xcassets/SkyEmeraldAurora.imageset/sky-emerald-aurora.heic` | `[待填]` | `[待填]` | `[待確認]` | `[待填]` | `785ac7a2fe98eceab698194c2fd51b4ed75a419f58b8d5292c71b3b4de502c0d` | Blocked |
| Amber sky | `Native/CMV/CMV/Assets.xcassets/SkyAmberDawn.imageset/sky-amber-dawn.heic` | `[待填]` | `[待填]` | `[待確認]` | `[待填]` | `14ff17fb77d9df3d85d7f36463ec80f46410f0beb73b17ef0822121b929a1722` | Blocked |
| Sheep rocket | `Native/CMV/CMV/Assets.xcassets/SheepRocket.imageset/sheep-rocket.png` | `[待填]` | `[待填]` | `[待確認]` | `[待填]` | `d0837aac40308d70fb21171b839c26e4f46f345e605fd0e077b5b90b8f36ae6b` | Blocked |
| Sheep sleep | `Native/CMV/CMV/Assets.xcassets/SheepSleep.imageset/sheep-sleep.png` | `[待填]` | `[待填]` | `[待確認]` | `[待填]` | `c00e176d9e1c95a4ea9cf90db6bb39e769136e03a99c6de507c534ac27c2836a` | Blocked |
| Sheep tumble | `Native/CMV/CMV/Assets.xcassets/SheepTumble.imageset/sheep-tumble.png` | `[待填]` | `[待填]` | `[待確認]` | `[待填]` | `d8a71b232a87952d47a70c17fcf68231bd04460cad1e1d5dc1d10f5c45af93fe` | Blocked |
| Sheep umbrella | `Native/CMV/CMV/Assets.xcassets/SheepUmbrella.imageset/sheep-umbrella.png` | `[待填]` | `[待填]` | `[待確認]` | `[待填]` | `0334a7a762ae82fe16b770644ff55fb7b52d321c6b5af6b66c20945e426190bc` | Blocked |
| Review audio／video／cover | `[受控發布檔案庫 locator]` | `[待填]` | `[待填]` | `[待確認]` | `[待填]` | `[待產生]` | Blocked |
| Mac screenshots／preview | `[待建立]` | `[待填]` | CMV RC 實機擷取 | `[待確認畫面內媒體]` | `[待填]` | `[待產生]` | Blocked |
| iPad screenshots／preview | `[待建立]` | `[待填]` | CMV RC 實機擷取 | `[待確認畫面內媒體]` | `[待填]` | `[待產生]` | Blocked |

## 規則

- 使用者自己的私人媒體不等於可公開用於 App Store 截圖。
- 產生式素材須記錄工具、日期、prompt／來源參考、服務條款或授權摘要。
- 商業歌曲、專輯封面、串流服務 UI、YouTube／VTuber 影片預設為不可用，除非有
  明確書面授權涵蓋商業宣傳與再散布。
- 每次替換檔案都要更新 SHA-256 與證據，不沿用舊結論。
