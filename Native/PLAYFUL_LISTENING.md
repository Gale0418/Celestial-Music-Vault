# 音色探索與原音對照

2026-10-04，AERO-PQ43。以 Codex Game Studios `dev-story` 流程做一個可審閱的小改動，保留 CMV 原本的曲庫與播放操作。

## 樂趣假設與操作

同一首熟悉的歌，換個音色會出現新的聆聽角度。音效面板現在提供一個簡短探索循環：播放歌曲 → 下一個音色 → 對照原音 → 返回音效 → 再試下一個。

- **下一個音色**依序走過土星大氣層、軌道環繞、下水道、深空電台、老卡帶、水下、大教堂、浴室演唱會，再回到土星。從原音、EQ 或自訂開始，第一站是土星。
- 保留目前強度；強度為 0 時，明確按下探索才調成 30%，讓場景可以聽出差異。自訂參數仍保留。
- **對照原音**暫時使用「原音」模式。按**返回音效**、編輯設定或離開面板，恢復所選音效；不把暫時對照寫進偏好。
- 影片使用原音，控制項停用；切入影片會結束比較，回到音樂仍使用儲存的設定。

探索與對照不啟動、暫停、跳過或重排歌曲。主動選定的新場景仍按既有方式保存，重啟保留；暫時比較不跨重啟保留。既有「恢復原音」則是正式重設設定，和暫時比較有不同用途。

這個循環提供直接選擇與即時回饋，不加入分數、連續登入、通知或播放外的獎勵。操作是否有趣仍需使用者試聽；自動化檢查不等於人類聽感。

## 實作與驗收範圍

AppModel 管理暫時比較狀態，只切換既有播放器參數；不新增 DSP、音訊圖節點、render 工作、計時器或背景 worker。`videoURL` 的狀態變更統一結束比較，涵蓋 standalone 與 mixed queue 的影片入口。面板以原生 Button／ViewThatFits 提供 44 pt label 與窄寬度堆疊，新增文字具繁中／英文／日文資源。

焦點 hosted 測試包含非空的重複曲目佇列、偏好未覆寫、同值編輯退出比較、新設定與重啟、原音／零強度邊界。完整實機 VoiceOver、聽感與商業驗收門檻延續既有紀錄，見 [SELLABLE_QUALITY.md](SELLABLE_QUALITY.md)；Bluetooth／AirPlay 依本輪使用者範圍排除，不列為 CMV 完成阻擋。

macOS popover 的關閉另由 presentation state 結束比較；完成按鈕在 dismiss 前先恢復，避免只依賴延後的 onDisappear。本輪結果記錄如下。來源與原始證據保留在 ignored 私有目錄，不把個人曲庫或開發簽章資料放進版本化文件。

## 2026-10-04 解鎖後補驗摘要

本節記錄 iPad 解鎖後 baseline production `08c2c5` 候選補驗，以及已完成的 Marquee v3 限定交付驗收；前一輪 `86bfcfc` 的操作範圍與限制保留於下方歷史段落。

- 完整 Core **97 PASS／0 failure／0 skip**；Rust **33 PASS／0 failure**，`fmt`、`clippy` 與 Swift-Rust bridge 均 PASS。Rust module source 未變。
- 完整 hosted **19：18 PASS／1 FAIL／0 skip**；唯一失敗是 pending approval 的 listener-only 自動解鎖 assertion。新拆分的 decline 測試 PASS；不把 approval failure 擴大解讀成 decline failure。
- Reliability **3 PASS**。Cache 真實 I/O fault 流程先保留 DB／queue／cache，清除 fault 後 retry PASS；另有真實 SMB cache **7 PASS**。這不是 50,000-track 全 NAS integration，也不涵蓋初始／差異索引、150 ms 或完整壓力驗收。
- Mac 同 ID 覆蓋後啟動與保存通過：1,964 entries／base、history 16、index 48。iPad 同 ID 覆蓋後啟動與保存通過：25 entries／base、history 5、index 13。
- Reduce Motion 實機 `0 → 1 → 0` 還原通過；自訂 Reverb `0 → 47.7%`，compare 保留 60% 已在 production `08c2c5` 候選驗證。
- 最大字級的按鈕拆字是實際 finding；Marquee v3 只修正 `AudioEffectsView` 圖示＋文字 HStack，並使用動態 Marquee／Reduce Motion 靜態完整換行。`source-marquee-v3.json` 的 tree 為 `f897d591…`、production source 為 `721e18c5…`；三端建置／兩端交付、source／archive integrity、實體 iPad UI 與設定還原均已完成。
- 音效偏好 **5 PASS／0 failure／0 skip** 僅屬 Marquee v1，收據為 `audio-marquee-final-summary.json`，不延伸為 v3 驗收。
- v3 最大字級動態文字位移、164×78 button frame 與完整 AX labels 已驗；靜態兩行 `Next Sound`／`Compare Original` 無拆字、無截尾。動態操作確認 `Orbit Sweep → Sewer`、Original compare 保留 60%，GUI reset 回到 Original／30%／custom factory defaults；static action 嘗試未觀察到 transition，排除為 PASS。
- `ipad-settings-restoration.json` 確認較大輔助字級 0、一般文字 67%、Reduce Motion 0、Bold 原本 ON 保留，Original／0.3／custom factory defaults 由 GUI、native AX 與 plist readback 驗證；`ipad-marquee-v3-final-startup.xml` 確認 Tracks 25、pause/play、Original 與原影片 5:14。
- 使用者明確排除 Bluetooth／AirPlay 設備，本輪不把這兩項列為 CMV 完成阻擋。仍無 Sandbox 帳號；付費 pending approval FAIL 另列為獨立阻擋。

## 歷史候選驗證（86bfcfc）

- 111 檔來源 manifest `86bfcfcf637b6cc1331f592c4c585b35992a9e7b8ce53eeee27760f8755f9b89` 建置前後一致；Mac universal／iPad arm64 Release 均 exit 0，strict 簽章與兩端本機 bundle preflight 通過。這是 Mac adhoc 與 iPad Development，尚非 Distribution 資格。
- Marquee v1 的 `AudioEffectsPreferencesTests`：5 PASS、0 FAIL、0 skip；三語資源 574 組、0 問題，diff check 通過。第一輪直接把 xcresult 存入 NAS 失敗，已改成本機產生有效結果、保存摘要與完整性驗證通過的 ZIP；不把儲存失敗或無效結果算成通過，也不把 v1 結果寫成 v3 完成。
- CUA 以獨立 App ID 與兩首原創 44.1 kHz stereo WAV 實際播放。最新候選連按九次從軌道走到下水道，包含完整八場景循環；保持 29% 強度與兩首佇列順序，Moon Voyage 播放進度持續前進。返回音效、對照後改選場景、Escape 關閉均恢復所選音效；正常重啟保留深空電台與 29%，保持暫停。初輪實際發現關閉回呼延遲，已補 presentation state 與完成按鈕恢復並重測。
- 獨立唯讀 reviewer 對最後生命週期修正無可重現 finding。Reviewer 自行啟動但未完成的測試不列入通過；本機有效 hosted 結果由主代理取得。
- Mac Desktop 同 ID 覆蓋、binary SHA 對應、strict 驗簽及啟動通過；曲庫／佇列 1,964、base 1,964、history 16、index 48 與播放模式保留。正常保存會更新 occurrence UUID，以曲目順序與映射後 history 比對，未冒稱 byte identity。

- iPad 同 ID 覆蓋安裝成功，前後 queue byte identity 相同：25 entries、25 base、history 5、index 13。第一個安裝因連線關閉失敗；檢查 tunnel／installed apps 後，單次重試成功。當時裝置仍為 Locked，因此該歷史候選未把啟動算成通過；解鎖後結果見上方補驗摘要。

該歷史候選未重跑完整 Core／Rust／StoreKit 套件；既有品質候選測試保持原範圍。當時未完成項目包括 iPad 解鎖後啟動與觸控、真實路由／聽感、完整無障礙，以及 [SELLABLE_QUALITY.md](SELLABLE_QUALITY.md) 的商業驗收門檻；解鎖後補驗不等於完整上市驗收。

Marquee v3 的三端建置／兩端交付、實體 iPad 操作、資料還原／preservation、設定還原與 UI 驗收已完成。`cleanup-final.json` 確認 source 111 recheck PASS、controller exit 0、WDAhost 收到 SIGINT 後以 exit 75 停止、兩個 own PID 均不存在；user-owned scratch／build／NAS fixtures 與自建 testHost 已移除。唯一殘留為 uid0 的 1,726-byte `_MASReceipt/receipt` 與受保護父目錄，PermissionError／OSError 未提升權限處理；production userAppData 保留，完整 VoiceOver／Stage Manager／contrast／裝置矩陣、50k NAS、commerce／Distribution、`critic_full` 與 Mission CLI sync／doctor 仍待各自收據，不以 v3 限定驗收延伸宣稱上市完成。
