# 重大教訓

> 只收錄已發生、具有再次發生價值，且解法已有證據支持的重大問題。
> 詳細事故資料位於 incidents/。
> 此文件必須保持精簡。

## 主動教訓

| ID | 適用情境 | 症狀 | 根因 | 正確處理 | 禁止重犯 | 驗證方式 | Incident | 最後確認 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CL-001 | 多個 Mission Center 版本同時存在時 | Doctor 通過但其實執行了舊版腳本 | 未在執行前核對已安裝 plugin manifest 與實際腳本路徑 | 先讀取 manifest 版本、確認 SKILL.md 雜湊，再從相同版本目錄執行全部腳本 | 不得因某版 Doctor OK 就宣稱已升級指定版本 | 核對 manifest 為 0.3.1、personal/plugin SKILL.md SHA-256 一致、Resume schema 1.1 | INC-001.md | 2026-08-14 |

## 已解決索引

| ID | 狀態 | Resolved by | Incident |
| --- | --- | --- | --- |
