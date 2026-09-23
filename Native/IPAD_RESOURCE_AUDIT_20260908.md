# iPad 資源預算檢查（AERO-F25／F26／F27）

## 使用者補充與結論

2026-09-08 主人提醒 iPad 的 RAM／儲存配置通常低於開發用 Mac，詢問一次緩衝太多是否造成卡頓、是否應依 RAM 調整。本紀錄分開保存已觀察與待驗證風險，不把 Mac 編譯／記憶體快照當成 iPad 實測。

- 已確認的 UI 熱點是頻繁布局與目錄每頁重複全量整理。F25 目錄修正須採背景輕量摘要，不以常駐完整五萬首 Track／封面換取 CPU 改善。
- 音訊使用 AVAudioPlayerNode.scheduleSegment 排程 AVAudioFile；原始碼沒有把完整佇列解碼成自行持有的 PCM buffer。不能據此推定 AVFoundation 內部零緩衝或沒有峰值。
- CachePolicy 預設預取 12 首、智慧磁碟快取預算 10 GiB。AppModel 延後 2 秒開始逐首複製，hash 每次讀 1 MiB；10 GiB 不是 RAM 配額。但預取仍可能競爭磁碟／NAS I/O，且整批預取後才 trim，不是寫入前空間保證。
- 本輪快照：測試 App PID 39244 RSS 54,736 KiB（約 53 MiB）；系統 memory_pressure 輸出 free percentage 50%；APFS 可用約 4.6 GiB。此為單一 Mac 時點，無法排除先前峰值，也不是 iPad 結論。
- IncrementalScanner 目前每 400 首送一批，批次攜帶 artworkData；單張接受上限 20 MiB，缺少批次總 bytes 上限。理論累積上限可達約 7.8 GiB 的封面 payload，尚未實際建立如此大的 fixture，不能聲稱已重現 OOM。單張限制是在 metadata load 後檢查，也不構成解碼前的峰值上限。
- TrackRecord.domain 會將 artworkData 放進 Track；大量曲目播放佇列仍需檢查封面常駐成本。目錄輕量化不代表整個 app 已改成按需封面載入，不能宣稱全程記憶體已受固定上限約束。

## 建議的驗收條件（尚未實作為完整動態政策）

1. 掃描以筆數及累積 bytes 雙門檻 flush；大封面不讓批次無限累積。先測計數／邊界，再以小型合法影音 fixture 驗證實際 flush，避免製造 GB 級測試浪費磁碟。
2. 記憶體採系統 pressure／warning 回饋，回收可重建快取、暫停非必要預取或分析；不得清掉當前播放需要的資料及來源 lease。不要只以 physicalMemory 或瞬間 free RAM 決定所有預算。
3. 磁碟快取採獨立剩餘空間與保留量、單檔 admission 檢查；釘選內容不得因自動退讓被刪除。
4. iPad 真實裝置驗證峰值 footprint、記憶體警告復原、前景捲動及背景播放；Simulator build 不能取代此項。

Apple 參考：[Responding to memory warnings](https://developer.apple.com/documentation/uikit/responding-to-memory-warnings)。
