# Pro 付費可靠性結案 · 2026-10-04

AERO-PQ38／AERO-MON30 的 Pro 技術驗收完成。正式授權／交易監聽行為未變；修正 StoreKitTest 的 fixture 傳播等待，增加故障／未驗證交易／重複操作對立案例，驗證腳本以實際 xcresult 數量判定，零測試與 skip 不算通過。

| 最新驗證 | 實際結果 | 範圍 |
| --- | --- | --- |
| Mac StoreKitTest | 17 PASS／0 FAIL／0 skip | production ProStore，核准／拒絕／購買／取消／錯誤／退款與事件撤銷／恢復／網路故障／unverified／重複操作 |
| 實體 iPad StoreKitTest | 17 PASS／0 FAIL／0 skip | 相同17案例，獨立 Bundle ID與既有Development簽章 |
| Mac 真 Apple Sandbox | 1 PASS／0 FAIL／0 skip | 正式 SKU、直接讀到sandbox環境、既有Pro與商品價格、restore成功、fresh Store |
| iPad 真 Apple Sandbox | 1 PASS／0 FAIL／0 skip | 使用者本人完成Apple驗證後，同正式SKU與相同權益／價格／恢復／fresh Store驗收 |
| 正式 critic_full | passed／findings=[] | 三席Luna獨立盲評＋不同Luna仲裁，四份sealed報告與artifact hashes均已核對，contract validator通過 |

最新共36項通過。歴史失敗另存：raw與production listener的fixture等待差異由交叉控制確認，不宣稱Apple保證currentEntitlements讀取會強制通知；iPad第一次restore因登入未完成失敗，最終驗證後成功，未以其他PASS抹去原始收據。沒有新增production polling或假授權。

原Mac App保持正常，1,964首、Pro Unlocked與原背景；iPad同ID還原原App並啟動，25 entries／25 base、history5、index13整份queue JSON一致，自建QA App已移除。另一組QA的1-entry快照是中途測試狀態，已用其原始還原receipt核對，不回寫覆蓋正式25首。裝置已交接另一組QA，本輪不再操作它。

故障網路為StoreKitTest注入；fresh Store不等於實體radio-off冷啟動。真Sandbox既有交易只做權益讀取與恢復，未新購／退款／登出／清空交易。整體App Store Distribution、其他功能與裝置QA仍各自追蹤，此結案不是已上架或完整商店發行資格。

私人原始xcresult、ZIP CRC、phase source與failure logs：ignored `.cmv-local-evidence/2026-10-04-pro-sandbox-verification/`。正式公開審查附件：[PQ38 council](../output/mission-center-critique/AERO-PQ38-pro-36-final-20261004.json)、[MON30 council](../output/mission-center-critique/AERO-MON30-pro-36-final-20261004.json)。CompletionPassport依原生Rust的length-framed task digest（排除status）綁定canonical task；不是用評論取代實際測試。

本輪已完成暫存回收約1.17GB；3,444 bytes的受保護receipt殘留已記錄，未提升權限、未動其他任務。四位評論代理已完成，工具未提供close動作；沒有用interrupt冒稱釋放名額。
