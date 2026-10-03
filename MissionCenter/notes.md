# 筆記

## 研究紀錄

| 搜尋前構想 | 參考來源 | 採納內容 | 授權狀態 |
| --- | --- | --- | --- |
| 沿用既有 NAS 打包 SOP | `docs/PACKAGING_AND_OPTIMIZATION.md` 與 Git 歷史 | 保留本機暫存與 electron-builder cache 策略，修正過期資訊 | 專案自有內容 |
| 關閉 `webSecurity` 並改用自訂協定 | Electron Security / Protocol 官方文件 | 採 `protocol.handle`、secure/standard/stream scheme 與核准根目錄檢查 | 官方文件，可引用概念 |
| 整理 App 圖示 | electron-builder Icons 官方文件 | 使用預設 `build/icon.png`、`build/icon.icns` 結構 | 官方文件，可引用概念 |
| 避免破壞 NAS 依賴 | 本機 Vite 錯誤與既有 SOP | 在 `/tmp` 以 `npm ci` 乾淨重建 | 專案自有決策 |
| Electron 主進程安全強化 | [Electron Security](https://www.electronjs.org/docs/latest/tutorial/security) | 限制導覽、新視窗、驗證 IPC sender、更新支援版本 | 官方文件，可引用概念 |
| 防止多實例競爭 | [Electron app API](https://www.electronjs.org/docs/latest/api/app) | 使用 `app.requestSingleInstanceLock()` 並聚焦主要視窗 | 官方文件，可引用概念 |
| 大型清單轉換快取 | [React useMemo](https://react.dev/reference/react/useMemo) | 快取大型陣列轉換並避免新陣列造成 Effect 過度觸發 | 官方文件，可引用概念 |
| 獨立架構與風險審查 | Antigravity cascade `272654c8-130a-4a3f-acd5-0def63d2d1dd` | 直接覆寫 JSON、NAS 離線存在性過濾與全量列表重算列為主要風險 | 本機授權協作；含 1 次 SEARCH_WEB 軌跡 |
| 確認 Mission Center 使用版本 | 已安裝 `.codex-plugin/plugin.json`、插件快取路徑與 SKILL.md SHA-256 | 基礎版為 0.3.1；執行中腳本來自 `0.3.1+codex.9ed1bfeca60445639f45a35d424aa16e` | 本機已安裝插件；只讀核對 |
| 將 CMV 上架流程改為可重跑任務鏈 | [rorkai/app-store-connect-cli-skills](https://github.com/rorkai/app-store-connect-cli-skills) 與本機 `asc-*` skills | 採簽章、Xcode build、TestFlight、release flow、submission health 分離；所有提交先 dry-run，`--confirm` 另需核准 | MIT；GitHub 外掛唯讀核對 |
| 預防 Guideline 2.1 資訊不足退件 | MediBuddy 任務 `01a04b26-127b-7772-a00f-3a2733ac5f2f` 的 Build 10 補件紀錄 | CMV 新增 Review Kit：完整 Notes、無剪輯實機影片、裝置／OS／核心流程、無帳號／無付費／NAS 授權方式與素材權利；資訊問題不先重建 Build | 同機專案自有紀錄；只採流程經驗，不複製敏感值 |
| 反方檢查 App Store 漏項 | Antigravity cascade `65eb3c8b-224f-4dcd-a3f3-12f2c0d66619` | 採 Privacy Manifest、FFI panic boundary、dSYM、展示素材版權與狀態語意；拒絕其「內建 NAS 掃描／保存帳密」假設 | 本機授權協作；外部磁碟未掛載時基於既有摘要，具明確未知 |
| 右欄播放佇列卡頓來源 | Apple `Understanding and improving SwiftUI performance`、Observation 官方文件 | 高頻播放秒數不再直接驅動整個 queue panel；以 Observation 快照隔離高頻粗 revision，只有 queue 順序／可見 metadata／目前曲目真正改變才發布 UI 狀態 | Apple 官方文件；採概念與 API |
| 月環即時波形既成實作 | [GRimAce11/WaveformKit](https://github.com/GRimAce11/WaveformKit)、[dmrschmidt/DSWaveformImage](https://github.com/dmrschmidt/DSWaveformImage) | 採 bounded bar count、固定 cadence、Canvas／即時 samples 與分析／呈現分工概念；CMV 保留自有 AVAudioEngine meter，不新增第三方依賴或複製程式碼 | 公開 GitHub 專案；僅參考架構概念 |
| UI 動效與效能收斂 | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) 的 audit／animate／optimize 規則 | 月環降回 80 段、移除逐段旋轉向量運算、修正 circular-buffer 時序並降低 queue backdrop blur；保留主視覺、刪掉無效 GPU 工作 | MIT；僅採規則與設計原則 |
| CMV Pro 買斷定價與跨平台權益 | [Doppler 台灣 App Store](https://apps.apple.com/tw/app/doppler-mp3-flac-player/id1468459747)、[Evermusic Pro 台灣 App Store](https://apps.apple.com/tw/app/evermusic-pro-%E9%9B%A2%E7%B7%9A%E9%9F%B3%E6%A8%82%E6%92%AD%E6%94%BE%E5%99%A8%E5%92%8C%E5%9D%87%E8%A1%A1%E5%99%A8%E9%9B%B2%E6%B5%81%E5%AA%92%E9%AB%94/id905746421)、[foobar2000 台灣 App Store](https://apps.apple.com/tw/app/foobar2000/id1072807669)、[Apple 跨平台購買](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms) | 2026-09-24 Apple API 已回讀：CMV 免費 App 台灣 TWD 0；同一 iPad／Mac 紀錄的 Pro non-consumable 商品台灣 TWD 290。商品尚 MISSING_METADATA，不代表 Sandbox 購買可用 | 競品價格為 2026-09-24 觀察，可能變動；僅學習定位，未複製內容或新增依賴 |
| CMV Pro Sandbox／審核邊界 | [Apple IAP 配置概述](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases)、[Apple IAP 審核資訊](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)、[Apple Sandbox 故障排查](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox) | 同一 App 紀錄可共用單一 IAP；付費協議須有效，商店 metadata 在 Sandbox 可能延遲至 1 小時。審核截圖應清楚顯示 App 內實際提供的項目，不以空曲庫主畫面冒充。Sandbox 不等於已送審或上架 | 官方文件，僅引用規則；測試結果依本機與 Apple API 回讀另記 |

## 2026-09-27 土星 UI 排版回復

- 使用者指出月環／播放區是在土星背景改版後變動。Git 定位：`5fdbf0e` 為改版前基準；`74df366` 首次加入播放區 24 pt layout padding 與 cover parallax。
- 恢復前版量測、移除月環 cover parallax；依最新要求保留寬版右面板下移 24 pt、淡半透明歌曲／播放與詳情卡。流光限於指定 UI 背景，月環無流光。
- 原生 macOS 簽署必須使用 `Native/CMV/CMV/CMV.entitlements`。本次交付曾誤用 `build/entitlements.mac.plist`（Electron）而讀到非 sandbox 資料位置，已重新簽署並於原生畫面確認既有 1,964 首曲目。未遷移或刪除曲庫。
- 本輪局部 UI 完成不代表整個 Pro／StoreKit 發布任務完成。

## 2026-10-02 羊羊彩虹繪本主題

- 背景與整體 UI 改為明亮童話卡通：原創彩虹天空、粗描邊奶油雲朵、奶油紙卡、可可文字與圓體。依最新使用者回饋移除所有地面與固定羊，沿用既有羊流星。
- 僅 emeraldAurora 套用；保留月環與播放區既有位置。背景圖片獨立於動畫 clock，羊流星遵循 Reduce Motion／scenePhase，最高 20 fps。
- Mac arm64 Release 最終建置成功；原生 entitlements ad-hoc 簽章與 strict verify 通過。桌面 CMV.app 已更新，舊版備份於 <USER_HOME>/.Trash/CMV-before-sheep-storybook-20261002-195121.app。
- CodeRabbit 共 2 次（各不超過 9 個小型 Swift 檔，排除大圖）；首次已確認佇列遮擋問題並修正，末次 9 檔 0 findings。獨立 Luna source／資產審查沒有確定 P0–P2。
- 原生 UI 工具啟動失敗：failed to start Node runtime: No such file or directory。只確認圖片素材與原始碼，未宣稱整頁實機視覺驗收。
- 初版 iPad Simulator Debug 曾建置、安裝與啟動；最終小修未重跑 iOS。使用者最新指定先完成 Mac，iPad 交付延後。此次自建測試 simulator 已關閉刪除。
- 本輪主題修改不代表整個 Pro／StoreKit 發布任務完成。

## 最新美術修正：日式動畫

使用者於 2026-10-02 指定改為日式動畫風格。背景已重繪為清透藍天、暖白積雲、藍紫色賽璐璐明暗與乾淨輪廓；保留巨大彩虹、完全無地面與固定羊。UI 沿用奶油色與柔和梅紫控制，原有位置不變。這次僅替換點陣資產，不修改已審查的 Swift 邏輯。

素材：imagegen `exec-09e84234-e175-4427-a2e3-b0ea88346ae0.png`。提示摘要：Original Japanese anime sky background; luminous cyan-blue summer sky, warm ivory cumulus clouds, blue-gray linework, lavender cel-shaded shadows, clean smooth painting, huge pastel rainbow; no ground, horizon, vegetation, buildings, sheep, text or interface.

## 實體 iPad Wi-Fi 遙控操作｜2026-10-03

對應 AERO-DV4／AERO-SC31 的實機驗收準備。主人要求保存「Mac 鏡像操作 iPad」聊天的既有方法並當場測試；另授權詢問「GAI月亮續杯」。本次確認使用已簽章 WebDriverAgent（WDA）XCUITest runner，並透過 Mac 的 loopback 控制頁傳送觸控。畫面是 WDA 截圖更新，不是 Apple iPhone 鏡像輸出；AirPlay 本身不提供這條觸控回傳通道。

### 前提與啟動

1. iPad 已解鎖、開發者模式啟用，與 Mac 配對且同網路可達。先用 `xcrun devicectl list devices` 回讀，再核對裝置 details 的 `ddiServicesAvailable`、`developerModeStatus` 與 transport。不要把歷史裝置 ID／IP 當固定設定，也不要保存到版本化文件。
2. 本機既有 WDA 工作區為參照聊天中的 `new-chat/work/wda`；已建置的 runner 在 `work/wda-build/Build/Products/`。用 `rg --files <既有 Products 目錄> -g '*.xctestrun'` 選擇實際存在的實機產物，不能選 Simulator runner。本輪直接重用 xctestrun，沒有重新編譯或建立／輪替憑證。
3. 以實際路徑與當次裝置 ID 取代下列佔位值，啟動一個 host；不要同時開第二個 runner，也不要在 WDA 初始化時用 devicectl 搶先啟動另一個 App。

```sh
CMV_WDA_XCTESTRUN="<已建置實機 .xctestrun 的絕對路徑>"
CMV_IPAD_ID="<當次 devicectl 回讀的 iPad ID>"
xcodebuild test-without-building \
  -xctestrun "$CMV_WDA_XCTESTRUN" \
  -destination "platform=iOS,id=$CMV_IPAD_ID" \
  '-only-testing:WebDriverAgentRunner/UITestingUITests/testRunner'
```

4. 從 host log 的 `ServerURLHere->http://<當次 iPad IP>:8100<-ServerURLHere` 取得服務位址，確認 `/status` 回 `ready: true` 後才操作。不能只憑 App 已安裝、程序存活或 HTTP 200 判定觸控成功。

```sh
CMV_WDA_URL="http://<當次 WDA log 回報的 iPad IP>:8100"
curl --noproxy '*' --connect-timeout 2 --max-time 5 "$CMV_WDA_URL/status"
CMV_IPAD_REMOTE="<參照聊天 outputs/ipad_remote.py 的絕對路徑>"
python3 "$CMV_IPAD_REMOTE" --wda "$CMV_WDA_URL" --port 8765
```

5. Mac 開 `http://127.0.0.1:8765`，可點擊畫面、更新畫面或回主畫面。既有頁面約每 1.5 秒更新；只綁 loopback。它建立並管理自己的 WDA session。不要再建立另一個 session 覆蓋它。腳本結束時會關閉 server 並刪自己的 session；WDA host 另外保留到實機驗收完成，之後僅停止本次建立的 host。

### API 與定位規則

- 不使用控制頁時，`POST /session` 傳 `{"capabilities":{"alwaysMatch":{"bundleId":"com.windsheep.cmv"}}}`，由回應的 `value.sessionId` 取得 session。每個操作者一次只持有一個 session。
- `GET /session/<id>/source` 取得 accessibility XML，`GET /session/<id>/screenshot` 的 `value` 為 Base64 PNG；`GET /session/<id>/window/size` 回傳觸控用的 point 尺寸。
- `POST /session/<id>/wda/tap` 使用 point 座標 `{"x":<point x>,"y":<point y>}`。控制頁的 `POST /tap` 使用畫面內 0–1 正規化座標，由頁面轉為 point。PNG pixel、縮放後瀏覽器尺寸與 point 不可直接混用。
- 點按前回讀畫面／XML；點按後再回讀確認預期狀態。橫直向會更換布局，本輪由直向 compact 變為橫向 sidebar，因此重新定位；側欄項目是 StaticText，不能硬找 Button。本輪寬版 XML 部分可見內容標成 `visible=false`，必須與實際截圖交叉核對，不能僅靠該旗標判定元素不存在。
- 權限、鎖定、automation mode timeout 或服務失聯時先診斷；沒有新證據不得反覆啟動。解鎖／配對／必要系統批准仍由使用者處理，不能繞過。

### 本輪觀察與證據

- 初次舊 WDA 位址與 8765 都無服務；裝置仍配對，details 確認 iPad Air 5／iPadOS 26.5、開發者模式與 DDI 可用、localNetwork tunnel connected。
- 重啟既有 runner 後 `/status` 回 `ready: true`。本機控制頁成功取得實體 CMV 畫面；以控制頁 `/tap` 點進 Settings，再切進 Music Library（XML 回讀 Loaded: 20／All songs shown · 20 total），再回 Listen Now。每個切換都取得截圖與 XML；未播放、修改曲目、變更購買權益或刪來源。
- 本機私有證據與 SHA-256：`output/mission-center-assets/ipad-remote-20261003/manifest.json` 及同目錄 PNG／XML；目錄已由既有 .gitignore 排除。原始 WDA host log 只存本機，不將裝置識別或 IP 提交 Git。
- GAI 聊天的既有紀錄證實使用同一套 WDA；build54 cleanup receipt 表示其自有 session／host 已收尾，解釋了此次服務未運作。GAI 的實測範圍與 CMV 的驗收分開記錄，不因別的 App 通過就把本專案 gate 判 Pass。
- 本輪結果：遙控鏈路與三次頁面切換通過。這不等於 AERO-DV4 的完整 NAS／背景音訊／PiP／Split View／記憶體矩陣通過；任務狀態維持原樣。

來源：[Mac 鏡像操作 iPad](thread://01a0da00-c2d6-7a41-94e0-9019367217e9?hostId=local)、[GAI月亮續杯](thread://01a0e7ca-4fdf-7ed3-994a-6d614fabc1a1?hostId=local)；均已用 read_thread 讀取，不將聊天宣稱當本輪觸控證據。

## 現有任務收尾波次｜2026-10-03

主人再次授權完成現有任務、跨領域研究、自主選擇最小安全改進，並指定 Mission Center／Antigravity Bridge／Codex Game Studios／Chrome／GitHub。沿用現有 Epic 與任務 ID，不增加產品邊界。第一波為 Q12 佇列與 I13 曲庫操作；X14 完成有證據的範圍評估；再驗 Pro、日常實機與發行 gates。主代理負責 MissionCenter、整合與驗收；Luna 分離寫入 lane，Gemini 的受限環境設計交付只作建議，不當成 source review 或編譯證據。發行外部狀態與使用者動作依具體 gate 追蹤，不虛構整體完成。

## 原 CMV 倉庫公開與清除請求｜2026-10-03

依主人最新明確指示，沿用原 `Gale0418/Celestial-Music-Vault`，已還原短暫更名並改為 Public；沒有建立額外倉庫。公開 main 的 62 個提交與 865 個 blobs 已驗證 0 個已識別私人值殘留，提交者使用 GitHub noreply。當前公開 Support／Privacy 文件匿名回讀均為 200。私有歷史備份及檢查報告只保存於本機，不推送其他 local backup／stash／internal refs。

舊 SHA 仍可由 GitHub API 讀取。主人已明确接受此限制並指示立即公開、另送清除請求。Support portal 的 Repositories 分類回 404；舊 GAI 工單已 Archived，其 follow-up 連結返回選擇帳戶。已核對官方 Support 既有郵件與 Reply-To，使用已連線 Gmail 寄出 CMV 的新請求，工具回讀 SENT。這是寄出證據，尚不是客服受理或快取清除 Pass；GAI 舊工單完成不能拿來關閉 CMV 的清除工作。請求只移除 obsolete history／cache，不刪 repo／目前主線／帳號，也不變更 Public 狀態。

## X14 本版範圍評估｜2026-10-03

`Native/SMART_LIBRARY_SCOPE.md` 記錄本版採納現有 addedAt 排序與本機歷史保存，最近播放 preset、規則 Smart Playlist、歌詞與背景 watcher 延後。未新增產品功能；核對語意、現存 source 與本輪 77-test／metadata 6-test evidence 後，低風險非感知文件評估採 critic skip。50k reconciliation 通過不是新的 150 ms UI benchmark。

## 商店草稿與隱私確認｜2026-10-03

三語 app-info 與 iOS／macOS 2.0 metadata 已寫入；33 欄回讀一致，首次上架不接受 What’s New，已保留 canonical 內容而不宣稱寫入。兩平台審核 Notes／聯絡與版權資料已填入，私人聯絡僅留 Apple 後台與權限受限 runtime 檔。年齡問卷 27 欄回讀 NONE／false 通過；不是最終審核分級結果。

App Privacy 的「不收集資料」與本機處理／manifest 一致。Apple 最後發佈按鈕要求確認回覆正確、符合法律，並承諾資料處理變更時更新；主人已同意，Chrome 已完成發佈並保存實際後台畫面。App 尚未正式送審。

X14 completion passport 已由正式 Rust transition 驗證，Review → Done 成功；只結案已核對的範圍評估，不新增延後功能。

主人已於 2026-10-03 明確回答「同意發佈」；Chrome 已按最後發佈，後台顯示數秒鐘前發佈，保留不收集資料預覽與公開 Privacy URL。此結果只確認隱私聲明發佈，不代表 App 送審。Mac universal Release 最新 build 成功，strict ad-hoc 簽章後覆蓋桌面 App，舊 App 可從垃圾桶復原；CUA 啟動顯示 1,964 首曲目且未播放。正式 Distribution 資格未由此取代。

## 本輪實機與 StoreKit 限制｜2026-10-03

實體 iPad 初步驗證 Pause／Next／Track Info／排序入口與佇列 terminate／launch 還原，未自動播放。多選及 occurrence-specific 重排未能由 WDA 穩定確證，不能把控制項可見當 Pass；舊 runner signal kill 視為工具限制，根因未證實。更新完成後仍需最新 queue fix 複驗；裝置稍後再次自動鎖定，尚未加入原創測試來源。

StoreKit compile-time 專用 DEBUG host 已證實不建立第二 AppModel／listener；pending approval 的 SKTestTransaction 變為 purchased，但 genuine 權益仍未到達，結果 0／1。購買、重啟、還原、退款與取消／失敗已有通過證據；不推論為完整三項矩陣全綠，不硬設權益或增加未證實 workaround。Apple 官方要求 Ask to Buy 核准交易經 Transaction.updates 傳遞，未找到該 hosted propagation 狀態的官方 workaround；production 根因未證實，仍需真實 Sandbox／實機驗收。

Mac 實測兩首原創 WAV 多選成功，空佇列 Add to Up Next 原會立即播放；已修為 paused metadata seed，延遲至使用者 Play／Next 才準備來源。修正版及第三輪修正後版本均已實測：加入後 Play／進度 0，重複曲目保留，明確按 Play 後進度增加，Pause 可停止。active append 路徑保留。第三輪修正後的完整佇列重排／單項移除仍未驗證：CUA 坐標操作回報 noWindowsAvailable，AX 可按播放器與選单但未獨立暴露佇列列內選單；此工具限制不視為操作通過。

## 第三輪審查與最後覆蓋版本｜2026-10-03

CodeRabbit 第三輪 4 findings 已逐項查證：有效 3 項為混合影音 append 保留既有 audio segment offset、批次資訊 Undo 移至持續可見的 TrackList toolbar，以及英文 Review Notes 匯入入口錯誤；均已修正。測試檔重複 enum／多餘大括號為誤報，實際 source parse 與先前 Xcode 執行到交易 assertion 為反證。三次審查額度已用完，修正後未宣稱另有外部零 finding 結果。

最後 production source 的 macOS universal Release、iPad device Debug build 均 BUILD SUCCEEDED；Mac Desktop 已覆蓋、strict codesign／bundle preflight 通過，1,969 首（原 1,964＋本次 5 首原創影音）保留，Track Info 可開啟並關閉。iPad 最後修正版安裝回讀 success；裝置再次鎖定，尚未完成此版操作驗收。兩平台修正後 Review Notes 遠端逐字回讀一致。

WDA 前一 host 於 remote process connection invalidated 後結束，不能推論為 CMV crash。新 host 在 Xcode preflight 等待 iPad 解鎖；僅重啟本次自有 host，未建立第二個 session。實際原創測試素材、二進位與畫面證據置於 ignored runtime 目錄，未公開使用者曲庫畫面、裝置識別或 LAN 位址。

## Review fixture 與最新受限驗收快照｜2026-10-03

前段「尚未加入原創測試來源」及「尚未完成此版操作驗收」是各自當時的歷史快照。其後原創 fixture 已可由公開 prerelease 下載：[cmv-review-fixtures-20261003](https://github.com/Gale0418/Celestial-Music-Vault/releases/tag/cmv-review-fixtures-20261003)，ZIP SHA-256 為 `e3b766ec3a828fc8d11e8ac90b1468a5cea5e8f8ba600a79184aa39e68bf72d6`。這只更新素材可取得性，不把未完成的完整審核媒體或 Sandbox 驗收標成完成。

本輪 iPad Files 解壓 AddMusic 來源由 20 首增至 25 首，通過。空佇列 Add → Play 的進度為 0，通過；佇列 `[Amber, Cobalt, Amber]` 移除未播放的 Cobalt 後為 `[Amber, Amber]`，目前曲目與進度維持不變，通過。此路徑是移除指定未播放 Cobalt，不是移除指定的重複 Amber。多選、重排、本版強制終止後還原尚未驗證；完整雙平台無剪輯影片、Split View／PiP 與 Sandbox 也尚未完成。私有 runtime evidence 僅作本機稽核，公開文件不帶裝置識別、網路位址或曲庫畫面。

本輪 WDA 只使用自有 session；session DELETE 與 host 收尾成功，沒有本輪 simulator／worker 存活。這是資源清理證據，不代表完整實機矩陣通過。

最新單一 production StoreKit listener recheck 以受限本機 log 回讀：exit 65；`activeEntitlements=1`、`unverified=0`，`allUpdates=0`、`matchingUpdates=0`、`orderRejections=0`、`hasPro=false`，約 32.3 秒逾時，判定 FAIL。診斷顯示 `compileHostFlag=true`，trace 只落在 `DEBUG && testHost`；未修改 production 解鎖邏輯，也不把結果歸咎 Apple。較早的 independent observer 32 秒 PASS 是延長等候的歷史結果，不能覆蓋本次 listener FAIL。

TrackInfo locale 的最小修正仍待 build／UI 複驗；不可宣稱最新版安裝已涵蓋。三輪 CodeRabbit 審查的有效 finding 已修正；修正後未新增外部審查輪次，不能宣稱最終零 finding。這不取代尚未完成的實機與 Sandbox gates。

## Mac Smart DJ 佇列還原缺口｜2026-10-03

桌面第三輪修正版（binary SHA-256 `8c129df1eb3a62ee1e3140d4211b4e0412087c13715d0d0beeb0086c6317a398`）由 Settings → Smart DJ 產生四首原創 WAV，Add to Queue 後 Up Next 顯示 4 total、Play 按鈕與進度 0。正常關閉並重新啟動後 Up Next 為 0 total，曲庫仍為 1,969；本機磁碟快照仍保留 version 1／revision 29／entries 4／baseEntries 4／currentIndex 0。此為實際還原失敗，不以資料檔存在判定成功；正在診斷，尚未確認根因或修正。畫面與 AX 只保存在 ignored runtime 目錄。

## Distribution 檢查修正與候選產物｜2026-10-03

本機 iOS 2.0 (1) 使用既有 Distribution 身分完成 archive 與 IPA export；未上傳。qualification 原使用 `codesign -dv`，該輸出沒有 Authority 欄位而誤拒有效簽章，已改為 `--verbose=2`。實際正式 iOS archive（arm64）檢查 exit 0，Desktop ad-hoc 負例 exit 1，其他 profile／entitlement／privacy 檢查仍保留。此輪 archive 早於最新 queue restore 修正，僅作簽署流程證據，不冒稱最終 RC。Mac candidate 仍在串行建置。

佇列還原旗標的最小修正已完成 source parse：取消中的 SwiftUI task 不再提前完成共享 restore flag；有效空快照仍採納 revision；成功 hydration 才完成 flag，既有 queue mutation guards 與不自動播放行為保留。實機重啟複驗尚未完成，取消事件本身也尚無 runtime trace，不能把推測觸發原因寫成定案。

## 核對 candidate 後的 Mac 還原與語系驗收｜2026-10-03

queuefix archive 的 binary SHA-256 為 `e59e77a7ecea161dd154840f6ccc230acc97a85bdfbbf7bc91e94f8f23c81d44`；複製為 Desktop ad-hoc 測試版後為 `dfdf4ec5debf967e16562b9dd6a903494336d766b9ffaa42a5df9725a1b7cb31`。CUA 啟動已還原四首原創 Cobalt／Violet／Amber／Silver，Up Next 4 total、Play、進度 0，曲庫 1,969；Track Info 的 Basic Information／File and Track／Done 與日期 Oct 3, 2026 為英文，限定路徑通過。較早一次複驗誤取 pre-queuefix archive，已更正 runtime receipt，不能當修正後 FAIL。

此候選含 restore 完成旗標修正，尚未含後續獨立發現的併發 revision rebase 保護。還原等待期間的新 queue mutation 必須以已載入 revision 重新保存，以免 actor 拒絕較舊 save；最小 source 修正已完成 parse，暫時 OSLog 診斷已移除，正在建立同 source 的下一組候選。沒有 runtime cancellation trace，不把該觸發原因寫成定案。雙平台 archive／IPA／Mac package 已於前候選成功、qualification 通過，仍未上傳或正式送審。

Mac 同一 queuefix 候選另驗明確 Play／Pause 狀態切換，接著對本次原創 WAV 啟動 Analyze This Track，畫面顯示 Analysis complete／Tempo around 62 BPM。這只證明該檔本機分析操作成功，不是 BPM／節目 loudness 準確度 reference 或完整使用者曲庫體感。

## 最後同 source qualification 與實機邊界｜2026-10-03

最後 distribution source manifest 與目前 source SHA 一致；Mac Release archive／signed package 及 iOS Distribution archive／IPA qualification 均通過。這些仍是 candidate 產物，尚未 upload，不等於最終 RC 或送審完成。

最後 Mac desktop 覆蓋版以同 source 實際驗證四首原創 Cobalt／Violet／Amber／Silver：current Violet 位於 index 1，Up Next 還原、Play／progress 為 0，曲庫為 1,969 首；真正 restore 且沒有自動播放，通過此限定路徑。這項結果更新前述較早的畫面還原失敗歷史快照，不延伸成完整佇列矩陣或所有來源型態通過。

最後 iPad Debug build 與 signing profile 通過，但安裝在 CoreDevice 3002／`IXRemote5 remote.installcoordination_proxy Error83` 失敗。最新鎖定狀態為 `passcodeRequired=true`、DDI usable；目前等待使用者解鎖後重試。舊 limited QA iPad 紀錄不能當成最後 source 覆蓋版通過證據。

四首本專案原創 WAV 與 pinned BS1770 做獨立比較，±0.1 LU 全部通過，最大絕對差為 0.000324；receipt 留在 ignored runtime。這只建立 fixture-level 的獨立 loudness 比較，不代表 EBU 認證、全 genre 覆蓋或完整 release gate。Sandbox 仍 pending／fail，screenshots、無剪輯 demo、rights forms 與 critic budget 仍未完成。

## 解鎖後最後 source 交付與影片路徑｜2026-10-03

解鎖後，最後 source 的 iPad Debug install 與 launch 均成功；binary SHA-256 `f7f9105e356d249183248d7a5d73a8ca173c29aab69ebcfe4161d31724ea2786` 與 final source manifest 相符。實際 QA summary 顯示 25 首曲目與本專案原創 fixture、Track Info 英文與 release `Not Available`、多選 2 項 UI 通過；enqueue 結果 Unknown，重複曲目 future remove、重排與 terminate／restore 尚未驗證。先前的 install failure 保留為歷史紀錄，不被新的成功證據抹除。

WDA test runner 本輪以 `Test crashed with signal kill.` 結束，host exit 65 後已離開；根因未知，不稱為 CMV crash。因 service unavailable，session DELETE 未能確認成功；cleanup receipt 沒有 owned host 仍存活的證據，不能把 cleanup uncertain 寫成完整通過。

同一最後 source 的 Mac CUA 原創 MOV fixture 路徑已有限通過：Play → Pause 約 1.133872027 秒，月環 → standalone native player 約 1.1291 秒且保持 paused，Return to Moon 後約 1.133872027 秒未改變；EOF 後為 Not Playing／empty，清除本次原創影片後曲庫為 1,969。這只證明單一原創影片路徑，不代表 mixed media race、PiP 或聽感認證。

App Store Connect Content Rights 已保存 `DOES_NOT_USE_THIRD_PARTY_CONTENT`，主要類別為 Music；主人再次確認不在 App 內提供內建歌曲、影片或圖片。產品範圍是 local user-authorized media，這只記錄商店權利選項與產品邊界，不等於所有私人音樂都已有可散布授權。Privacy 已有先前發佈證據。

主人新增的 Marquee overflow scope 已有 source 修正，Marquee card／PlayerBar 也已實作，正在建立新的雙平台 build；因此先前 final Distribution qualification 只屬舊 source candidate，不能宣稱為最新 source qualification。Sandbox pending／fail、screenshots、無剪輯 demo、rights forms、完整 programme matrix 與 formal critic budget 仍待完成。節目級聲學比較摘要見 `Native/ACOUSTIC_REFERENCE_QA_20261003.md`，仍不等於節目認證。

## 2026-10-03：AERO-U25 與三語商店草稿

Gemini 的受控四欄文案已審閱後整合三語 canonical；App Store Connect app-info 三語副標題及 iOS／macOS 2.0 的描述、宣傳文字共 15 欄 exact readback，一般保護欄位 24 欄 exact preserved。首發 What’s New 未寫入，未上傳／提交 App。名稱、URL、關鍵字、版權、完整 App Review Notes 沿用。

第一 Marquee candidate 雙平台編譯成功，但 Mac 實測長字部分移出可見範圍，故不能作 UI PASS。已改為每個元件 onGeometryChange 量測、要求正寬且固定動畫容器。Mac layout Debug 重建 exit 0、strict signature PASS；实际驗收中型卡片文字完整，小型卡片溢出資訊移到尾端仍可讀，短歌名與尚未播放保持固定，AX 保存完整標籤。這是有限畫面驗證，不宣稱完整 VoiceOver、Reduce Motion 實測或效能基準。修正版的雙平台 Distribution 候選仍重建中。

AERO-Q12 同份 Mac Debug 補驗：空 queue 加入原創 Cobalt 保持暫停 0；再次加入同曲保留兩個項目；只移除未播放的第二項後，原目前項保留、總數 1、仍暫停 0；正常關閉重啟還原相同一筆暫停項。最後清除本次測試 queue，使用者曲庫 1,969 首不變。完整重排、混合影音與 iPad 矩陣仍未完成。

首個 iPad candidate 已覆蓋安裝成功，但 SpringBoard 啟動回覆 Locked；沒有建立新的 WDA host/session。已要求解鎖，實機動畫與縮圖驗證維持 ToolLimited。raw screenshot／AX／ASC receipts 僅私有 runtime，不提交私人曲庫封面或裝置資料。

最後 `marquee-layout-final` 雙平台候選已完成：67 個編譯輸入前後 SHA 一致；Mac universal archive qualification／pkg 簽章、iPad Debug build／codesign、iOS archive／export／IPA qualification 全部通過。它仍非正式 RC，沒有 upload。桌面已覆蓋最後 Release 的 ad-hoc 測試副本；實際啟動保留 1,969 首、空 queue 不自動播放，短歌名固定、溢出資訊在活躍時可讀往返。

最後 iPad source 安裝另遇 CoreDevice 4000「連線後立即斷線」，未嘗試 launch／WDA。root bounded 診斷後裝置已 available／tunnel 可讀，但 `passcodeRequired=true`；`unlockedSinceBoot=true` 只代表開機後曾解鎖，不可當成目前解鎖 PASS。已在全部建置結束後再要求即時解鎖，避免等待建置導致自動鎖定。未完成前維持 ToolLimited。

遙控短案例的操作補充：先完成建置，再即時確認 `passcodeRequired=false`，依序 install／launch／啟動唯一自有 WDA host。從當次 host log 取得 URL，每次操作先讀新 source，優先點 Button／Tab，避免同名 StaticText；source 與 screenshot 串行，單一 HTTP 上限 35 秒，整個短案例上限 170 秒。畫面與幾何回讀各自驗證，不能把 HTTP 成功當 UI 通過。完成後 DELETE 自有 session 並核對回應，再 SIGINT 自有 host、確認程序結束；不終止其他任務的 runner。

公開資料整理另外遮罩歷史簽章 Team 識別碼；AERO-G17 的既有 completion passport 僅依官方 canonical digest 算法重新綁定遮罩後 task identity，status／verification／evidenceRefs／findings 完全保留，未新增或重做 QA。原 digest 與 HEAD 一致，新 digest 與目前紀錄一致；Doctor exit 0、80 tasks 通過，既有缺 passport 的 legacy warnings 如實保留。重新綁定 lineage receipt 只留私有 runtime。

StoreKit pending 唯讀診斷：最後 single-listener 測試的 `compileHostFlag=true`，approval 後 matching transaction 已 purchased、真實 `currentEntitlements` 的 activeProductCount=1；production listener allUpdates／matching／orderRejections 均為 0。因此目前證據指向事件尚未進入 receive，不能歸因 productID 過濾或交易順序拒絕，也不能定案為 Apple SDK bug。下一個最小診斷是在獨立串行 case 保留原事件契約失敗，再驗證 approval 後 production refresh 可否採納真實 verified entitlement；refresh 通過也不能替代 listener case。此輪未改測試、未重跑、未把 pending FAIL 改成 PASS。

## 最後 Marquee candidate：解鎖後 iPad 驗收｜2026-10-03

即時 `passcodeRequired=false` 後，最後 Debug binary `1f973a2c67ac28d74c62f86864dfeafce512c5a284805079ee302cd628368545` 成功覆蓋安裝並啟動。58 秒短案例顯示 Loaded: 25、直向五欄縮圖視覺收在各 card 內，未見跨欄。Raw AX 的 nested video image 仍有 width=230，不能把子節點 rect 當外層裁切結果或宣稱所有 AX bounds 都通過。

兩張畫面有文字位移，AX 保留完整標題及 metadata；完整循環、獨立短標題、VoiceOver、Reduce Motion 及效能尚未驗，Marquee runtime 判 Limited。Up Next 顯示 Synced with Up Next · 25 total／Play 且保持 paused；沒有播放或修改 queue／曲庫、沒有 NAS 或購買操作。

自有 WDA session DELETE 回 HTTP 200，host endpoint 已不可連；SIGINT 後自有 diagnostics 停滯，核對 ownership 後 TERM，controller 及診斷程序均已消失。root 獨立核對最新 binary、四個圖／XML SHA 與程序退出。私人曲庫封面和原始 receipts 只留 ignored runtime；不作公開商店素材。未建立本輪 simulator。

## 正式完成評論：首輪與證據補強｜2026-10-03

主人以「准奏」批准先前 16,000 tokens、每席 4,000、工具 24 次、30 分鐘的預算。已派三位獨立 Luna 分別盲評流程／文案、視覺／可及性、故障／持久化，再由第四位獨立 Luna 仲裁；快照為 c42375f、candidate 2.0(1)。所有稿件已封存，評論不當 smoke PASS。

視覺席在四張指定畫面中未發現可定案缺陷，仍保留 VoiceOver／Reduce Motion／效能等 unknown。仲裁保留四項：廣泛功能宣稱尚缺完整同版實機證據（High，release gate，非已證實功能不存在）、Mac 還原附件只保存 AX diff 而非完整狀態（Medium）、StoreKit pending listener 測試失敗（High，根因未知）、qualification 未保存 exact invocation 綁定（Medium，非否定一般 preflight 的 optional 設計）。

主持者已補跑最後 Release 桌面副本的原創 Cobalt：空 queue → 同曲兩筆 → 正常 quit／relaunch → 兩筆保留、current Cobalt、Play／progress 0；完整前後 AX 已保存。最後只清本次 queue，Not Playing、曲庫 1,969 不變。這補強 Mac duplicate cardinality／正常重啟／不自動播放證據，不代表 occurrence ID、重排、future remove、強制終止、iPad 或混合矩陣全部通過。

同 source 67 項 SHA 在前後均一致；已重新對 Mac archive、iOS archive 與 IPA 展開 bundle 明確執行 `--distribution --expected-version 2.0 --expected-build 1`，三次 exit 0。新私有收據記錄完整 argv、source manifest／qualifier／artifact executable／IPA SHA，補齊本次 qualification invocation 證據缺口；沒有更改 App source 或弱化簽章檢查。

預算控管偏差：流程 6、視覺 6、故障 8、仲裁 7，共 27／24 次評論工具；故障及仲裁超過各席上限。報告自估 tokens 合計 12,580，並非系統精確 usage。已停止追加評論，不宣稱預算合規或完成收斂。整體 gate 為 blocked；pending FAIL、完整實機／無障礙／聲學／Sandbox 等 coverage 尚未補齊，沒有 Done、upload 或送審。全部 raw 報告與私有路徑已排除 Git。


## 2026-10-04 全程式抓蟲續輪（進行中）

使用者授權全面稽核、最小修復與覆蓋 Mac／iPad／可回收模擬器測試。沿用 AERO-U24／Q12／F26／MON30，主代理整合；Luna 唯讀檢查播放佇列與來源背景工作，Gemini 只讀診斷 StoreKit pending。目標為沒有未修 P0/P1，並修復本輪查證的 P2/P3，不宣稱無限範圍無 bug。

2026-10-04T00:05:34+08:00 使用者同意新評論預算：critic_full／converge，總計 24,000 tokens、每席每次 3,000、工具合計 24 次、40 分鐘，涵蓋三位獨立專家、證據裁判及必要 delta／cleanup closure。正式評論須先完成本地修復驗證並凍結新 snapshot；計時從正式 dispatch 開始，既有上一輪 27/24 超支紀錄保留，不重置成通過。

本輪已確認 future audio prepare 失敗只刪 active queue 而遺留 base queue，會在關閉 shuffle 復活失效曲目並使 snapshot 不合法；restore 等待 repository 時也未檢查新播放 preparation generation。準備最小修復及實際回歸。StoreKit 加獨立 refresh reconciliation 與 external purchase probes，原 pending listener acceptance 不改成 refresh PASS。

### 2026-10-04 歌單畫面追加稽核（AERO-U24／AERO-I13）
主人指出 iPad Playlist 畫面及左右欄邏輯不一致。本輪新版實機直向 screenshot／AX 證實：空歌單 ContentUnavailableView overlay 擴張成整頁高且覆蓋 Smart DJ。先修提示卡依內容尺寸，保留 Smart DJ 操作；左右欄採實際橫向觀察與主人回覆釐清，不盲目切换導覽架構。私有證據置於 reliability-20261004 ignored 目錄。
主人已明確指定左右側欄使用一致的開關與佈局，並要求右欄長文字跑馬燈。本輪 AERO-U24 範圍追加：將寬版 iPad queue 從 inspector 改為與 Mac 共用的 inline panel；保留原 Queue 資料／操作，按鈕語意與 Reduce Motion 設定；長曲名沿用已有限幅跑馬燈，非另寫動畫循環。
主人追加指出 iPad 底部播放列視覺漂浮。本轮 AERO-U24 修復僅將 PlayerBar／MiniPlayerBar 的背景延伸至底部 container safe area，保留操作與 Home indicator 的安全距離；不移除整個 App 的安全區。須分別看直／橫向圖與 Mac 無回歸。
主人要求左右伸縮按鈕使用不同圖案：左 sidebar.left、右 music.note.list；保留同一個欄位控制 row 及 44-point 觸控區，無關資料／播放邏輯不變。

正式盲評補充發現 NativeAudioAnalyzer 的 idle cancel 會留下 UUID，讓下一次同曲分析誤取消；此屬 AERO-F27 取消契約。LocalAudioAnalyzer 已有 in-flight guard。Native 修正以每次 request token 記錄 active/cancelled，完成時清理，避免取消完成或尚未開始的請求污染下一次；八聲道焦點測試加入 idle／完成後 cancel 再分析的回歸。修復後需新 snapshot 與焦點驗證，先前 UI snapshot 不自動沿用為新程式全面通過。
主人現看桌面歌單頁指出與其他頁面格式不同；CUA 對照專輯页證實 PlaylistHub 的 List opaque white background 蓋住主題，Smart DJ row 未套共同 cloudSurface。追加 AERO-U24／I13 最小樣式修復：隱藏List底、保留List swipe/context actions，列使用同一主題卡片及邊距，空卡沿用同一surface；不是重寫歌單資料與導覽。新畫面需實測。
逐頁翻查又實際確認 CatalogTrackDetail 的 Mac List 白底遮天；共用 celestialPageBackground 在 macOS 分支原本是 no-op，補上 scrollContentBackground(.hidden)，沿用 WideRootView 的同一背景，不重複建立動畫。其他設定與來源頁保持 Form 的語意／操作。
英文 UI 的 BatchMetadataEditor 實測仍混中文標題／欄位／確認與取消，追加 AERO-I13 三語漏譯修補；Luna 工程席只負責 catalog／必要局部source，主代理驗收，不計作 formal critic 或以此取代獨立評論。

2026-10-04 評論窗口 checkpoint：新預算正式 dispatch 起算 01:37:14，截止 02:17:14；三位獨立評論＋視覺補充與獨立裁判共 15／24 次底層工具，流程席 4 次高於 chair packet 3 次。精確 tokens 不可得，不宣稱精確合規。舊四個 stable findings IDs 保留；restore 漏 guard 與任意像素輸入推測以 frozen source 反證拒絕，取消殘留已以 request token 與 hosted 2/0 修復。最終 UI／locale／取消 delta 未獨立複驗，正式 gate 仍 blocked／interrupted，不作 Done。Hardlink 增量凍結因 workspace filesystem 不支援而中止，沒有評論使用該半成品。
逐頁 Mac 八主頁與七子頁／modal 已實看；最後版 batch editor 英文 locale 已確認，取消編輯且清空測試選取，自建空 QA 歌單已回收。Catalog 白底隱藏後發現曲目文字對比不足，追加 cloudSurface 行卡片並覆用於歌單正常／缺失曲目列；双平台建置成功。iPad 真實安裝與啟動已成功，橫向空歌單／Smart DJ／貼底播放列有限驗證；最終對比版交付與驗證仍續行。

本輪逐頁後補：expanded 接下來播放主頁加共同卡片背板，避免星座標籤穿過曲目／狀態；專輯／歌手子頁三個操作 label 44-point contentShape 與 borderless，避免小觸控區及 List 自動按鈕行為。Mac 最終 universal Release build 成功，桌面覆蓋簽章驗證通過；iPad 同源最終 build／驗收續行。

最終逐頁回看追加：右欄空提示預設 ContentUnavailableView 裁字，改以可換行共用提示並保留 accessibility header；最愛空提示、設定與音樂來源 Form 使用共同 cloudSurface 背板，避免背景星座標籤穿過文字。來源頁未點重索引／重新授權，不改使用者設定與媒體。

2026-10-04 最後交付：Mac universal Release／iPad Debug 同源建置成功並覆蓋舊版本；桌面 strict／deep ad-hoc 簽章驗證成功，非 Distribution 資格。Mac 八主頁與七子頁／modal 已翻查，最後待播、右欄空提示、最愛、設定與來源頁補看。iPad 解鎖後最後版啟動成功，橫／直向歌單卡與 Smart DJ 分離、底部背景貼齊、待播背板與右欄跑馬燈已看；左右欄逐一收合／展開恢復；專輯子頁三個按鈕讀回 44 × 44。未點曲目操作、改評分、重索引或授權，保留原 25 筆待播及暫停狀態，恢復測試前橫向。原創 QA 空歌單已回收，桌面原空 queue 保留且雙欄恢復收合。

遙控補充：同名 label 不足以判斷目的，例如曲目「最愛」按鈕與側欄「最愛」；必須按所在區域與 element type 篩選，每次以新 source 驗證後才操作。最後 source delta／建置 log／二進位 SHA／實機 PNG 與 AX 存 ignored 私有 checkpoint；沒有追加逾期正式評論。Pro pending listener FAIL、完整 NAS／無障礙／聲學／Sandbox／Distribution 及最後獨立 delta 仍未完成，不宣稱 P0/P1 清零或已送審。

最後資源收尾：自有 WDA session DELETE 回應成功，核對自有 host 命令後 SIGINT，確認程序結束；本次 Simulator 已刪除，測試空歌單與選取已回收。未終止其他任務程序；舊桌面副本保留可回復備份。私有交付 checkpoint 保留最終 delta、二進位 SHA 與 PNG／AX，與先前正式評論快照分開，不能冒充獨立 delta PASS。
