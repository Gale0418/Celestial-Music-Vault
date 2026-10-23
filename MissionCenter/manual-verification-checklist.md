# 主人集中驗收清單 · 2026-10-08

## 2026-10-08 07:36 Xcode / WDA TOOLING_RECOVERY_PASS_SCOPED

Xcode／WDA／鏡像連線修復完成，TOOLING_RECOVERY_PASS_SCOPED。官方Components安裝後iPad及Any iOS destination恢復available；WDA build-for-testing actual0／TEST BUILD SUCCEEDED，ready status與HTML/XML/PNG HTTP200成立。主人已手動重載並直接確認『已看到 iPad 畫面』；owner的CUA同tab讀回已連線，沒有繞過網址政策。

Root親核recovery-02的50檔payload／15,854,585bytes SHA與大小全exact、五檔before/after byte exact；SQLite複本integrity ok、429曲／10來源／0歌單，queue19 current1 rev226保留。WDA同bundle更新僅一份，CMV未重安，原install URL相同；不稱fresh installed CMV binary SHA已核。沒有播放、選檔、停機還原或重測窄Cancel。

已回收本輪確認閒置Symbols與完成的compile cache/intermediates，共5,915,204KiB（約5.64GiB）；symbol metadata保留，清後destination仍eligible、XML/PNG HTTP200。Mac最新可用17.40GB（16.21GiB）。保留唯一必要iOS平台/runtime及active BuildProducts；WDA host與relay仍供主人使用，未終止其他程序。

窄Cancel仍沿用主人USER_PASS；PiP、聽感、等待容忍、容量scope接受結果不變。工具修復門檻已解除；真NAS slow/stale實际刺激仍未觸發，整體 Review／limited，不列產品FAIL、不宣稱全項PASS或新的full council passed。

收據：xcode-wda-recovery-02-20261008/recovery-receipt.json SHA6c77926200d7ee281d31a920efde4fcaeb9c72ab35a993f93e16074062232dac；delta-manifest SHA5a70cd3fcef6cf6cd5647a9ebce330ba360357434b154c9c59fbbc49b0b35f07；Root readback：tooling/recovery02-primary-readback.json。


目前整體維持 **Review**；S02四席審查完成，其 blocked 為舊標準下的封存結論。目前搜尋依主人約60秒容忍範圍接受，Mac整體聽感也已通過。已接受的人工結果不重問；工程補測、成品核對與資料還原由 Codex 處理。最終四席額度已獲「無限，能完成任務即可」授權，沒有待核准額度。

## 已有人工結果

- 窄窗資料夾選擇器取消：主人確認以前已測過、沒問題，採 USER_PASS，不重測。這是既有人工验收確認，不稱本輪工具自動操作或精確374pt實測；舊 UNKNOWN_TOOL_BLOCKED 收據保留歷史。
- Evidence: council/manual-deltas/manual-narrow-picker-user-pass-20261008.json; nas-final-recovery/primary-readback.json; human SHA 71e1e2791d2d6e8eaff0c87b633df5deff7d2b0bae5ac17f7e371e19b17e56a6

- iPad 旁白：**USER_PASS**。主人「感覺都可以全旁白 PASS~」；這是整體使用者驗收，不補造逐控制的 Codex 朗讀紀錄。
- iPad 整體聽感：**USER_PASS**。主人於「測試 iPad 連線」回報「聽感也OK啦～ 就是回聲很多的感覺嘛～～」。不延伸為逐模式客觀聲學量測。
- iPad PiP：**USER_PASS**。主人確認進 PiP、暫停、播放、返回 CMV，以及時間／曲目／pause state 正常。已讀回主人原話並核對人工收據 SHA `53164d07…`；這是人工結果，先前 `INCONCLUSIVE_TOOL_CONTROL` 紀錄保留。
- Mac 整體音樂／影片聽感：**USER_PASS**。主人最新回報「聽感沒問題」，依上一輪唯一剩Mac聽感的語境接受；不延伸為逐preset客觀量測。收據SHA `14124185…` 已核對。
- Mac 旁白、全斷網、Bluetooth、AirPlay：**USER_EXCLUDED**，不列本輪未完成門檻。
- 重開機／斷線：依主人指示記 `ENV_INTERRUPTED`；缺乏可重現缺陷的異常記 `NOT_REPRODUCED`。未測／工具限制仍不自動 PASS。

## 仍需人工結果

PiP與兩端整體聽感均已接受，不重問；iPad容量已獲主人最新數字，不再待答。窄picker取消已確認USER_PASS，不再待答。真NAS slow／stale補測仍未觸發，維持unknown。

## 容量條件項

主人最新回報iPad已用 **53.5GB／總64GB**，按顯示數字約剩 **10.5GB（9.78GiB）**，記 `USER_REPORTED`；設定顯示有四捨五入，不稱machine exact。容量待答已解除。主人說不需把10GB全部塞入，完整10GiB實填改 `USER_NOT_REQUIRED`，舊14GiB安全門檻不再阻擋縮小scope；這不代表完整10GiB實機壓測PASS。小檔工程scope已核對：既有真SMB同source7／7與新增local小檔11／11 checks、Rust3／3 tests通過，涵蓋淘汰/pinned/新actor重開與計數邊界。Root raw/source/digest readback及本次temp清理完成，仍不稱iPad硬體或完整10GiB壓測PASS。本次「可重建檔可清」授權是Mac工作資源清理，不推定為刪除iPad私人內容。

## 最新成品與還原

Mac final-v2 binary `be9c4d1f…`／iPad `4d684522…` 已同源 Release、簽章與資產核對。iPad 已完成音樂／影片播放、Next、暫停、Emerald、最大輔助字級、Reduce Motion 與約374pt真窄窗核心操作 scoped PASS；窄 picker 取消由主人確認先前人工驗收無問題 USER_PASS，擴回原尺寸後已返回。

iPad 最終九表逐列／integrity／app-owned preferences exact；queue19 current1、revision220→223且其他字段 exact。原曲0:00 paused、原字級0/67%、Reduce Motion0已還原。Mac最終重開九表schema/逐列／integrity／app-owned preferences exact；queue1962 current59 revision289→292且其他字段exact。正式Desktop App目前原曲0:00paused。

工程效能與最終審查進度見 [tasks.md](tasks.md)；Main 50k暖查詢既有p95約5.65～7.19秒，依主人約60秒容忍範圍接受，旧150ms未達保留為歷史，不列目前阻擋。Mac閒置模擬器/runtime/編譯與debugSymbols快取已清；最新df可用30.575GB（28.475GiB），正式App/資料/證據保留。
