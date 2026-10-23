# 2026-10-23 審查修復與 2.0（2）發布紀錄

2.0（2）final archive、PKG／IPA export、Distribution qualification 與 resource guard 已完成並 PASS；正式新版 upload／attach／送審尚未完成。Apple 核准不由本機測試保證。

## 審查要求與修法

- iOS 2.1(b)：審查人員無法找到 Pro。保留「設定 → CMV Pro → 探索 CMV Pro」，並在寬版側欄新增「CMV Pro」快捷入口。價格仍由 StoreKit 提供；一次買斷，不自動續訂。
- macOS 2.3.3：多數截圖未呈現實際 App。新版素材以 App 實播原創示範影片後的原始截圖為主；裝置宣傳合成圖另行標示，不能當成未經加工的實機擷取證據。
- macOS 5.1.1(ii)：依 Apple 要求補上繁中、英文、日文的 `NSAppleMusicUsageDescription`，描述自選本機／NAS 媒體的系統播放資訊與控制中心操作，不宣稱瀏覽或修改 Apple Music 曲庫，也不新增讀庫 API。
- iPad 大字體：寬版播放列改為佔用實際版面高度，內容可捲動，不使用固定底部補白猜測播放列高度。
- 三語：627 項 UI 字串涵蓋繁中、英文與日文；新增 37 個天文名稱、修訂 21 項既有文案，背景名稱在繪製時依 App 語言查表。

## 已驗證範圍

- final macOS／iPadOS archive 均建立成功；PKG／IPA export、Distribution qualification 與 resource guard 均 PASS。版本為 2.0、build 2，建置期間 218 個 source file 維持未變，證據在 `output/cmv-review-release-20261023/final-artifacts.json` 與對應 final logs。
- Mac 三語 6 張 2880×1800 實機商店圖、iPad 11 吋三語 6 張 2360×1640 實機商店圖均已回讀，checksum／順序／尺寸與 `COMPLETE` 狀態核對通過；13 吋 required slot 的舊 AI 圖仍待替換，不能把 11 吋素材冒稱 13 吋。
- iOS Development 同 Release 成品已完成 install／launch exit 0；WDA 中止，故只記錄啟動成功，不稱 UI 驗收完成。Mac Development 重簽副本已通過簽章與版本檢查，尚未安裝。
- macOS 26.5.2 最小 sandbox 測試 AVAudioEngine、Now Playing 初始化／狀態與 Remote Command 註冊未出現 Apple Music 提示；因此完整觸發條件仍未重現，三語用途字串是審查相容性修復，不能宣稱已保證通過。
- Swift／Core 115 項測試，4 項因專用 fixture 缺少而 skip、0 failure；Rust 34 項、0 failure；Python focused 10 項、2 skip、0 failure；三語 627 鍵檢查 0 issues。
- CodeRabbit 149 檔第一輪與 10 檔 focused 第二輪完成，第二輪 0 findings。後續 duplicate focused（#5）PASS、VideoMeter hosted（#7）PASS；fixture 項（#4）只證 source／skip behavior，未完成 full hosted；StoreKit scheme 的 LaunchAction 語義（#9）仍 UNKNOWN，未盲改。

## 發布關卡

目前保持 HOLD，剩餘條件如下：

- 13 吋 required screenshot slot 必須以正確尺寸的實機／Simulator 素材替換舊 AI 圖，並重新以 ASC validator 與遠端回讀核對；已完成的 11 吋素材不得冒稱 13 吋。
- iOS 雖已用同一 Release 成品 install／launch exit 0，WDA 中止使 UI 驗收仍 pending；Mac Development 副本尚未安裝，不能把簽章驗證當成實機 UI PASS。
- 正式新版 PKG／IPA 的 upload、build attach、既有 unresolved submission 重用與重新送審仍待 action-time gate；不能把歷史 2.0（1）拒審回條或本機 qualification 當成 2.0（2）已送審。
- fresh completion arbiter 的 `PASS_SCOPED` 更新仍在整理；在 final gates 未封存前，REV23 維持 In Progress／Review／Backlog，不寫 Done、clean convergence 或 Apple ready。

本機原始截圖、帳號／裝置回讀、影音及收據保存在 Git 忽略目錄；公開文件只記錄可核對的結果，不提交私人曲庫、憑證或完整帳號。
