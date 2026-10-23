# iPad 解鎖後測試報告

後續 2026-10-04 的剩餘功能、虛構歌手／來源與 50k 合成資料、Rust 搜尋與歌單 List 修復，另見 [剩餘功能驗收報告](REMAINING_VALIDATION_REPORT.md)。下方保留前輪 Marquee v3 的原始範圍與收據，不改寫成最後候選完整驗收。

日期：2026-10-04
狀態：**Marquee v3 已驗收交付／整體上市門檻仍為 Review**。本報告整理 `.cmv-local-evidence/2026-10-04-ipad-unlocked/` 的私有收據與目前 tracked 品質規範；不把未完成的裝置操作或未取得的能力寫成通過。

Mission Center 最後同步／重播已完成，Doctor 結果為 PASS；status 回讀 `sourceFresh: true`、`stale: false`。收據為 `mission-sync-final.json`、`mission-doctor-final.json`、`mission-status-final.json`，不代表正式 critic 或上市 gate 已通過。

## 已完成且可宣稱的結果

下列 Core／Rust／hosted／Reliability／SMB 收據屬解鎖後 baseline 候選；Marquee v3 只新增必要的三端建置／兩端交付、UI 與設定驗收，不宣稱重新跑完整套件。

| 項目 | 結果 | 收據／限制 |
| --- | --- | --- |
| Core | **97 PASS／0 failure／0 skip** | `test-results.json`；局部 UI 微調未改 Core 範圍 |
| Rust workspace | **33 PASS／0 failure** | `test-results.json`；本輪 Rust module source 未變，沿用同一 source 的結果 |
| Rust `fmt`／`clippy`／Swift-Rust bridge | **PASS** | `rust-extra-results.json` 三項 `exitCode: 0` |
| Hosted 最終 19 項 | **18 PASS／1 FAIL／0 skip** | `hosted-final-19-summary.json`；唯一失敗為 `testPendingApprovalArrivesThroughUpdates()` 的核准 listener-only assertion timeout，保留為已知失敗，不宣稱全套通過 |
| 拒絕新測 | **PASS** | 拒絕分支已實際驗證；不以核准 listener-only 失敗改寫結果 |
| Reliability | **3 PASS／0 failure／0 skip** | `reliability-summary.json` |
| SMB NAS cache | **7 PASS／0 failure** | `nas-cache-result.json`；production source identity 為 byte-identical |
| 音效偏好（Marquee v1） | **5 PASS／0 failure／0 skip** | `audio-marquee-final-summary.json`；只代表 Marquee v1，不延伸為 v3 實機驗收 |
| baseline build／資格 | **Mac、iPad、Simulator 三個 Release + local qualification PASS** | `final-tests-builds.json`、`last-gates.json`、`staged.json`；Mac 為 adhoc、iPad 為 Development，不能稱 Apple Distribution qualification；不代表 v3 |
| Marquee v3 build／資格 | **Mac、iPad、Simulator 三個 Release exit 0** | `marquee-v3-gates.json`、`staged-marquee-v3.json`；Mac adhoc、iPad Development strict/local preflight PASS，Simulator unsigned/local preflight PASS，仍非 Distribution |
| Marquee v3 source／archive | **111／111 source snapshot、source ZIP、三個 final app ZIP 完整** | `source-marquee-v3-integrity.json`、`marquee-v3-archive-integrity.json` |

SMB NAS cache 的 7 項涵蓋取消 prefetch 回滾、離線媒體損壞拒絕、pinned／smart cache 保留、checksum sidecar、actor 外 staging，以及同尺寸變更的完整驗證 fallback。這些結果不代表已完成真實 50,000-track NAS 的初始索引、差異索引、暫離線、記憶體壓力或 150 ms 目標驗收。

## Source、build 與交付對照

`source-final.json` 記錄最後 **111 檔** source／test／設定／資產，tree SHA-256 為 `6959f2…`，production source SHA-256 為 `08c2c5…`。`source-start-final-release.json` 的 build tree 為 `5a5e66…`，production source 相同；兩份 manifest 的唯一檔案差異是 `Native/CMV/CMVProTests/ProStoreTransactionTests.swift`。production 新源只加入 default-preserving 的 cache DI，沒有把所有 UI 收據冒稱為最後 binary。

`staged.json` 顯示 Mac 與 iPad binary 均 strict verify、local preflight PASS，且都對應 production source `08c2c5…`。這是本機 Release／資格證據；Development／adhoc 仍不能寫成 Distribution、上傳或商店資格。

最新 Marquee v3 的 source 收據為 `source-marquee-v3.json`（tree `f897d591…`、production `721e18c5…`）。v3 變更限於 `AudioEffectsView` 的圖示＋文字 HStack，以及動態 Marquee／Reduce Motion 靜態完整換行；三端建置、source integrity、archive integrity 與 Mac／iPad 兩端交付及實體 iPad 驗收均已完成。

`desktop-delivery.json` 顯示 Mac 同 ID 覆蓋後啟動通過，保存資料為 **1,964 entries、1,964 base、history 16、current index 48**，並保留曲目順序、history 順序、index、shuffle、repeat 與 version。`ipad-final-delivery.json` 顯示 iPad 同 ID 覆蓋安裝與啟動通過，保存資料為 **25 entries、25 base、history 5、current index 13**，entries／base／history／version／index／shuffle／repeat preservation 均為 true。

v3 的 `desktop-marquee-v3-copy.json`／`desktop-marquee-v3-delivery.json` 與 `ipad-marquee-v3-delivery.json` 另外確認同 ID 覆蓋／安裝、啟動及資料 preservation：Mac 為 1,964 entries／base、history 16、index 48；iPad 為 25 entries／base、history 5、index 13，兩端 entries／base／history／index／version／shuffle／repeat 均為 true。

## iPad UI 實際證據

早先候選 `86bfcfc` 的 iPad 場景探索已保存私有 XML／PNG 證據，且實際完成下列流程：

- 場景探索與強度 60；關閉「原音對照」後沒有覆寫偏好。
- 兩首多選加入佇列後維持 paused。
- repeat 與 background return 流程。
- 影片使用原音時控制項 disabled，切回音樂後回到 Custom。

上述證據只代表私有 captures 中實際操作過的候選／流程，不把所有 UI 都宣稱為最後 production binary。音色探索與原音對照的行為定義見 [PLAYFUL_LISTENING.md](PLAYFUL_LISTENING.md)；整體上市品質限制見 [SELLABLE_QUALITY.md](SELLABLE_QUALITY.md)。

Marquee v3 的 `marquee-v3-ui-results.json` 與 captures 已確認最大字級動態文字位移，按鈕 frame 固定 164×78 且 AX label 完整；Reduce Motion 靜態兩行 `Next Sound`／`Compare Original` 無拆字、無截尾。實機動態操作確認 Next Sound `Orbit Sweep → Sewer`、Compare Original 保留 60%，GUI reset 回到 Original／30%／custom factory defaults；static action 嘗試未觀察到 transition，明確排除為 PASS。`ipad-marquee-v3-final-startup.xml` 亦確認啟動時 Tracks 25、pause/play、Original 與原影片 5:14。

v3 設定還原收據 `ipad-settings-restoration.json` 確認較大輔助字級 0、一般文字 slider 67%、Reduce Motion 0、Bold 原本 ON 保留，並由 native AX 與 plist readback 驗證 Original／0.3／custom factory defaults。

## 尚待完成的上市驗收／root 補結果

以下項目目前維持 **進行中／待 root 補結果**：

- baseline iPad Reduce Motion 已實際 0→1→0 還原；custom Reverb 實際 0→47.7%，原音對照保留 60% 強度與 custom 值。最大 Accessibility 字級已找到探索按鈕並排拆字問題，VoiceOver 語音品質未由自動化驗收。
- Marquee v3 三端建置／兩端交付、實體 iPad 操作、資料還原／preservation、設定還原與 UI captures 已完成並可宣稱；不把 v1／舊候選收據延伸為 v3 以外的測試 PASS。
- cleanup 已依 `cleanup-final.json` 完成：source 111 recheck PASS、controller exit 0、WDAhost 收到 SIGINT 後以 exit 75 停止，兩個 own PID 均不存在；所有 user-owned scratch／build／NAS fixtures 與自建 testHost 檔案均已移除。唯一殘留為 uid0 的 `dd/Build/Products/Debug/CMV.app/Contents/_MASReceipt/receipt`，1,726 bytes，及其受保護父目錄；因 PermissionError／OSError 未提升權限處理。production userAppData 保留，source／app／test integrity ZIP 與 logs 保留於 ignored evidence。
- VoiceOver 完整語音品質與完整 iPad 裝置／視覺矩陣仍未由本輪自動化驗收。

上述 v3 項目已完成，但本報告仍不標成完整 iPad UI／上市驗收，因完整 VoiceOver、Stage Manager、Increased Contrast、背景／鎖定與其他裝置矩陣尚未完成。

## 能力限制與上市判定

使用者明確將 Bluetooth／AirPlay 排除本輪 CMV 功能驗收，因此不列為完成阻礙。使用者最新確認目前正使用 Sandbox 帳號維持付費狀態，撤回「沒有 Apple Sandbox 帳號」的舊判斷；Mac Pro 管理介面已實際確認解鎖。這不是完整 iPad Sandbox 交易矩陣證據，也不以 local StoreKit 收據補稱通過。hosted 19 項的 1 FAIL 是歷史結果，最新焦點交易補驗見文末。

Mission 目前維持 **Review**，不是 `sellableReady`。依 [SELLABLE_QUALITY.md](SELLABLE_QUALITY.md) 的限制，正式販售仍受正式 Pro completion review、完整 iPad A11y／Stage Manager／Increased Contrast／裝置矩陣、真實 50k NAS、commerce／Distribution qualification 與正式 `critic_full` 阻擋；本輪沒有 CompletionPassport。cleanup 已完成，但保留 cleanup-final.json 所記錄的 uid0 受保護 receipt 殘留。

## 2026-10-04 Pro 焦點補驗更新

目前 Mac 與實體 iPad StoreKitTest 各 **17 PASS／0 FAIL／0 skip**，每項有實際 xcresult 計數；歷史 pending FAIL 保留為原始結果，其「production listener 故障」推論已由 test-only 傳播等待與 raw 對照修正。正式授權／監聽行為未變。Mac 真實 Apple Sandbox 既有正式 SKU：交易環境直接讀為 sandbox，權益／恢復／fresh ProStore／商品價格通過（1 PASS）；iPad 最新真Sandbox與還原均完成，見文末；歷史受阻與失敗收據保留。

網路故障為注入錯誤，fresh ProStore 不等於實體斷網冷啟動；本輪未操作真實新購或退款。完整 App、Distribution 與無障礙 gates 仍各自保留。詳見 [SELLABLE_QUALITY.md](SELLABLE_QUALITY.md) 的目前結果與私有收據定位。

### 最新 iPad Sandbox 補驗結果（目前）

使用者在裝置本人完成 Apple 帳號驗證後，私人 v2 probe 的正式 SKU smoke **1 PASS／0 FAIL／0 skip**：direct transaction environment Sandbox、商品價格、既有 Pro、AppStore.sync 恢復成功與 fresh Store 均通過。先前1 FAIL與等待密碼的截圖保存為歷史證據，不混算最新PASS，不宣稱為ProStore程式缺陷。兩平台17例本機交易＋各1例真Sandbox，最新共 **36 PASS／0 FAIL／0 skip**。

原 iPad App 同ID還原、launch通過；production 25 entries／25 base、history5、index13整份queue JSON一致。先前1-entry revision88為另一組QA中途狀態，另一任務已還原原始25首，並有device回讀receipt，不將其誤判為install資料遺失或写回覆蓋。DB與pinned檔未變，StoreKit內部cursor可正常更新；本輪自建QA App已移除。裝置已以共享工作區handoff交接其他QA，本輪Pro不再操作它。

正式 critic_full 已完成：3位Luna＋獨立仲裁，converge passed／findings=[]，四份報告與來源雜湊核對、contract validator及CompletionPassport通過；AERO-PQ38／MON30已由原生transition轉Done。網路故障為注入、fresh Store不等於實體斷網冷啟動；真實新購／退款未操作。完整Distribution與整體App gates仍各自保留，不包裝成已上架。

Pro 技術結案的完整範圍與結果見 [PRO_RELIABILITY_REPORT.md](PRO_RELIABILITY_REPORT.md)；整體App Store readiness依原gate追蹤。
