# Mission Center 摘要同步失敗診斷

日期：2026-09-08（Asia/Taipei）

## 症狀與已確認原因

已安裝 `0.5.1+codex.20260907200516` 的 `resume` 回報 `derived view stale`，`sync` 回傳 `command_error`。`doctor` 可解析 76 項任務且 tasks pass；這不代表摘要同步成功。

現有 `focus.md` 為 6,643 bytes。17 項未完成 P0 任務的焦點欄位原始內容合計約 5,957 bytes，加入表頭後超過 4 KiB。已安裝 arm64 binary 經唯讀反組譯確認，focus 讀取及生成上限仍為 4 KiB；Mission Center 維護工作樹已有 `FOCUS_MAX_BYTES = 16 * 1024`，但尚未進入此執行檔。CLI 沒有將此大小超限轉成專用錯誤碼。

## 隔離驗證

- 原始 MissionCenter 複製到本機磁碟、使用 `/private/var/...` 真實路徑且不帶 writer lock：sync 仍失敗。
- 僅縮短 working-set 的六項任務：仍失敗。
- 僅在隔離副本縮短未完成 P0 的下一步／驗證欄位：sync committed。
- 正式 `tasks.md` 沒有縮短、改狀態或變更驗收條件。
- `/var` 是 symlink；以該別名呼叫會另觸發安全路徑拒絕，不應混入摘要大小的判斷。

## 殘留鎖

原始 writer.lock 屬於 `cmv-perf-resume-20260908-03`，PID 99587 已不存在；確認內容後移至 `.mission-center/recovered-locks/` 保存。

本輪 `cmv-lock-recovery-20260908` 失敗後，在 SMBFS 留下 PID 61771 的 lock；本機副本相同錯誤則能清鎖。PID 結束及 token 再核對後，同樣保存至 recovered-locks。未終止任何其他工作程序。SMB 上清理失敗的底層 OS 原因尚未取得，不宣稱已修復所有鎖定情境。

## 修復與驗收狀態

根因已交付正在維護外掛的「確認超級螃蟹母艦狀態」任務整合。等待已驗證新版套件；之後需以原始完整 CMV 任務表確認 sync 成功、status sourceFresh、resume 無 derived-view stale，並確認鎖已釋放。尚未宣稱修復完成。

## 新版核心隔離驗收

2026-09-08：維護任務交付新版 debug binary，SHA-256 `5a79e911a9495562b547a9fbfd0accd15f8cce3bdc44cc36e5e3a0d12e7346a8` 已由本任務實際核對。以完整 78 項 CMV 任務表在 `/private/tmp` 隔離副本執行：

- sync：committed。
- status：sourceFresh=true、stale=false。
- resume：canonicalFallback=false、sourceFresh=true、fallbackReason=null。
- 生成 focus：7,338 bytes，超過舊版 4 KiB 上限仍成功。
- tasks.md 前後 SHA-256 相同，writer.lock 已釋放；隔離副本已清理。

這證實新版核心可處理 CMV 完整摘要；未改寫正式工作區摘要，也未安裝 debug binary 為正式外掛。正式套件安裝及 SMB 原位同步仍待完成。

## 2026-09-08 正式安裝與原工作區驗收

- 上游 PR #18 已合併，main `9f26db3cacbc3104c48538f6a81f5e1f6b02443f`；GitHub Actions run `34226932141` success。
- 四平台 stable artifact `10056160470` checksum 驗證通過；plugin-creator cachebuster 後 native `install apply` receipt `cmv-mc-fix-20260908-01` committed，保留 rollback backup。
- `codex plugin add mission-center@mission-center-local` 成功，正式安裝 `0.5.1+codex.20260908124259`。
- 原 SMB 工作區 `sync --root . --operation-id cmv-formal-sync-20260908-01 --timestamp 2026-09-08T12:50:00Z` 回傳 committed。
- `resume --root .` 回傳 `sourceFresh=true`、`canonicalFallback=false`、`fallbackReason=null`。沒有再使用 debug binary 改寫原專案摘要。
- 本次 SMB 曾讀取逾時，恢復後才進行以上原工作區驗收；此連線中斷與已修復的 focus 4 KiB 上限問題分開記錄。
