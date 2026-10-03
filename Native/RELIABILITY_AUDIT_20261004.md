# 2026-10-04 可靠性與歌單介面檢查

本輪是修復與驗證中的 checkpoint，尚未完成 App Store release qualification、Sandbox 或完整實機矩陣；不得把建置成功或評論無問題當成正式送審通過。

## 修復

- 下一首來源遺失／開啟失敗時，active queue 與 base queue 同步移除同一 occurrence，保留重複曲目與索引，避免關閉隨機播放後復活失效項目。
- 還原佇列遇到較新的播放準備時停止舊還原，避免覆寫使用者的新選擇。
- 已取消的來源探測停止後續探測；已取消的音訊分析不再儲存結果。正在執行的同步檔案呼叫與 Rust FFI 尚不能即時中斷。
- 音訊分析依聲道數限制總 sample 數，保留 mono／stereo 分析窗口；高聲道縮短窗口，PCM 批次仍最多 16,384 frames。
- 音樂縮圖使用共用背景 actor cache，內容改變時重新載入；NSCache 限額是淘汰政策，不是嚴格記憶體上限。曲庫數量改由背景資料 worker 讀取。
- 分析取消依當次 request token 管理，空閒或完成後的取消不會污染下一次同曲分析，結束時清理 token。
- 空歌單提示卡依內容縮放，不蓋住 Smart DJ。Mac／橫向 iPad 共用左右欄開關與頁內佈局；左側開關使用側邊欄圖案，右側使用音符清單；右欄長曲名、歌手／專輯及狀態使用既有跑馬燈。播放列背景延伸至 iPad 底部安全區，操作保留 Home 指示條距離。減少動態效果仍由既有元件處理。

## 已執行驗證

- CMVCore 全套：84 tests，0 failures；包含失效 future occurrence、重複曲目、shuffle 及 snapshot 回歸。
- macOS hosted：還原競態 1、縮圖 cache 3、分析取消／實際八聲道 CAF 2，個別焦點執行皆通過。
- 以上為不同焦點執行的結果，不宣稱同一次完整 hosted suite 通過。
- 專家提出的分析取消殘留已修復；八聲道焦點測試加入空閒取消、完成後取消及同曲重跑，2 tests／0 failures。
- iPad Simulator：還原／cache 4 項通過；3 項 StoreKit 測試受到 configuration Code 3／空產品阻礙，未略過成 PASS。
- CodeRabbit 首次 Native 差異審查為 12 files／0 issues；UI 追加後另一次 Native/CMV 審查為 11 files／1 advisory，第三次為 11 files／0 issues。第三次未涵蓋後續底部背景／右側圖案、取消 request token 與逐頁樣式／locale 修正；這些採本地焦點驗證，完整獨立 delta 未於本輪評論時限內完成，不追加外部審查。hash／decode 保留在背景 cache actor 以限制並行解碼；未提供 actor head-of-line 延遲實測，不把此建議等同已重現主執行緒阻塞。

## 尚未通過

macOS StoreKitTest 的純 Ask-to-Buy 批准路徑仍觀察到 current entitlement 已存在，但 Transaction.updates 計數為 0、Pro 未自動更新。讀取 entitlement 並 refresh 的診斷可通過，不能取代 listener acceptance；改成 detached listener 也未解決，實驗已撤回。正式 Pro 實作未做假授權、持續 polling 或測試略過。iOS Simulator configuration error 是另一項工具／平台限制，根因尚未證實。

完整同候選版本的 NAS 負載、聲學體驗、VoiceOver、Dynamic Type／Reduce Motion 實機矩陣及真實 Sandbox 交易仍需驗證。這輪沒有 upload、TestFlight 或正式送審。

## 獨立評論與版型補正

三位 Luna 盲評流程、視覺與故障狀態，再由第四位證據裁判核對。iPad 橫直向空卡、Smart DJ 與貼底背景有影像反證；restore 漏 guard 的推測與實際程式不符，已拒絕。縮圖任意像素參數造成峰值的建議沒有生產可達路徑：目前呼叫固定為 360／440／680，不當成已重現產品缺陷。取消 API 殘留則已修復並回歸。評論沒有消除 StoreKit listener FAIL 與完整同版資格缺口，gate 仍未通過。

主人另指出桌面歌單頁與專輯頁格式不同。實際比較確認 List 白底蓋住主題，已隱藏 List 底並沿用共同 cloudSurface 卡片與邊距；保留原生列的 swipe／context actions。這是評論快照後追加的修復。新版 Mac 已實測歌單及空歌單詳情，iPad 已實測橫向歌單；Smart DJ 與空卡分開、背景一致。

逐頁翻查涵蓋 Mac 的現在收聽、歌單、接下來播放、曲庫、專輯、歌手、最愛與設定，以及 Smart DJ、音樂來源、專輯曲目、歌單詳情、Pro、歌曲資訊、批次編輯。發現曲目子頁也有 List 白底，已補共用 Mac 背景修飾器；英文批次編輯 sheet 沒承接 App locale，已在根視圖明確套用，現有三語 catalog 完整而無需新增翻譯。建立的空歌單僅為本次版型 QA；未變更媒體內容或購買，批次編輯以取消結束。翻頁不等同所有資料狀態、交易與無障礙矩陣完成。

最後 Mac 回看確認批次編輯完整承接英文 locale；專輯曲目 List 隱藏白底後文字壓在彩虹背景上，追加共用 cloudSurface 曲目卡片提高對比，歌單一般與缺失曲目列一併沿用。Mac Release universal 及 iPad Debug 均完成建置，覆蓋交付與局部實測另記私有收據。

本輪評論使用 15／24 次工具，包含失敗的相對路徑讀取；流程席使用 4 次，超過 chair packet 的 3 次限額，但未超過使用者整體工具预算。精確 token usage 工具未提供，不宣稱精確合規。40 分鐘評論窗口到期後保存 blocked checkpoint，不追加評論或宣稱完成收斂；一般修復與本機驗收繼續。

逐頁追加也觀察到 expanded「接下來播放」主頁的背景星座標籤穿過文字；此頁加共用 cloudSurface 背板，保留側欄原本樣式與佇列邏輯。專輯／歌手子頁三個操作的 label 各有 44-point content shape 與 borderless button style，擴大實際可點區域並分離 List 的按鈕行為。這些屬本地追加，未宣稱獨立專家 delta 已完成。

最後逐頁回看另確認右欄空狀態的 ContentUnavailableView 在欄寬下裁字，改為隨欄寬換行的共用提示（圖示裝飾、標題保留 accessibility header）；最愛空狀態與設定／來源 Form 的星座文字穿透也改為共同 cloudSurface 背板。這些只調整樣式與可讀性，維持原資料及操作。

## 本輪交付與驗收範圍

最後同源 Mac universal Release 與 iPad Debug 建置成功，桌面及實體 iPad 均已覆蓋舊版本。桌面副本通過 ad-hoc 簽章 strict／deep 驗證；這不代表 Distribution qualification。最後桌面焦點回看確認待播主頁、右欄空提示、最愛、設定與來源頁的文字可讀，左右欄回復收合，原空佇列保留。

iPad 最後版在解鎖後成功啟動，實際確認橫向歌單空卡與 Smart DJ 分開、待播主頁背板、播放列貼底、右欄文字捲動，以及專輯曲目三個操作的 44 × 44 觸控區。左右欄各自收合與展開後都可恢復；未按曲目操作或變更評分，原 25 筆佇列及暫停影片保留。按鈕區域的讀回不能代替所有操作隔離案例通過。

私有交付收據保存 source delta、二進位 SHA、建置紀錄與實機 PNG／AX，原始資料不提交公開倉庫。最後修正版沒有完成獨立專家 delta；評論窗口已到期，任務保留 checkpoint。Pro 待批准交易 listener、完整 NAS／無障礙／聲學／Sandbox 與同候選 Distribution 資格仍未結清；本輪沒有 upload、TestFlight 或送審。

最後版另補看直向歌單：空提示卡與 Smart DJ 分開、MiniPlayer 背景貼齊底部；測試後恢復原橫向。完整 iPad 八主頁及其他資料狀態矩陣仍未完成。

本次 WDA session 已 DELETE 成功，核對 host 命令後 SIGINT，確認自有 host 結束；測試建立的 Simulator 已刪除。WDA runner 的結束不作 CMV 測試 PASS。舊桌面副本保留於可回復的垃圾桶備份，未清空垃圾桶。
