# 舊版退場驗收（AERO-RT4）

日期：2026-10-08。範圍僅為已核准的 Electron／React／Node 舊實作退場，不代表 App Store 已發布。

| 驗收要求 | 實際證據 | 結果 |
| --- | --- | --- |
| 移除清單及 Git 復原基準可追溯 | 40 個 legacy tracked paths 均不存在；Git commit `7e033ae3b776f116695b3f2df0f0293bd76322f9` 存在，40 個檔案全部可由該 commit 取回 | PASS |
| 保留曲庫、音樂、憑證與原生工具 | 40 個路徑皆為舊 source／入口／打包檔；原退場資料保護見 MissionCenter/smoke-tests.md 的 2026-10-04 AERO-RT4 收據。本輪只讀核對，沒有新刪除。docs/history 仍保留 | PASS（限定退場） |
| Native Swift／Rust／雙平台建置通過 | 現行來源 Swift 焦點 38 tests／0 failures、Rust workspace 34 tests／0 failures；現行102項production輸入與final-v2雙平台Release成功收據一致，原build raw均有BUILD SUCCEEDED | PASS（所列範圍） |
| 舊版執行／打包入口無殘留 | package.json/package-lock.json/main.cjs/preload.cjs/index.html/vite.config.js、node_modules/dist/dist-app皆不存在 | PASS |

原361MB回收是歷史結果，不稱本轮新的容量回收。Swift38為焦點範圍，不冒稱完整Swift套件或實機矩陣。既有Mac/iPad Release build因production來源相符而重用，不冒稱新的Distribution archive。

CodeRabbit與Completion Critic路由為skip：低風險、非感知的退休實作清理，沒有新產品source或新的UI/音訊交付物；移除清單、Git可復原性及Native回歸已核。未將先前Lite/Full路由降級，未宣稱正式critic passed。

詳細收據與測試raw保留在Git忽略目錄：

- [主代理收據](../.cmv-local-evidence/2026-10-08-task-zero/rt4-closure/primary-closeout-receipt.json)
- [實際路徑／Git讀回](../.cmv-local-evidence/2026-10-08-task-zero/rt4-closure/rt4-current-readback.json)
- [Swift本輪收據](../.cmv-local-evidence/2026-10-08-task-zero/rt4-closure/swift-current-focused-receipt.json)
- [Rust本輪收據](../.cmv-local-evidence/2026-10-08-task-zero/rt4-closure/rust-workspace-current-receipt.json)

主代理收據SHA-256：`eff31d87e6f1239670778f66099ea4695e68a5001281d52f570e00391f7fb2fd`。
