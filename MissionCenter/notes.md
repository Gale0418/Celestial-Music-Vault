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
