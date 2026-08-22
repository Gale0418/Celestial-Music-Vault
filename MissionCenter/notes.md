# 筆記

## 研究紀錄

| 搜尋前構想 | 參考來源 | 採納內容 | 授權狀態 |
| --- | --- | --- | --- |
| 沿用既有 NAS 打包 SOP | `docs/PACKAGING_AND_OPTIMIZATION.md` 與 Git 歷史 | 保留本機暫存與 electron-builder cache 策略，修正過期資訊 | 專案自有內容 |
| 關閉 `webSecurity` 並改用自訂協定 | Electron Security / Protocol 官方文件 | 採 `protocol.handle`、secure/standard/stream scheme 與核准根目錄檢查 | 官方文件，可引用概念 |
| 整理 App 圖示 | electron-builder Icons 官方文件 | 使用預設 `build/icon.png`、`build/icon.icns` 結構 | 官方文件，可引用概念 |
| 避免破壞 NAS 依賴 | 本機 Vite 錯誤與既有 SOP | 在 `/tmp` 以 `npm ci` 乾淨重建 | 專案自有決策 |
| Electron 主進程安全強化 | [Electron Security](https://www.electronjs.org/docs/latest/tutorial/security) | 限制導覽、新視窗、驗證 IPC sender、更新支援版本 | 官方文件，可引用概念 |
| 防止多實例競爭 | [Electron app API](https://www.electronjs.org/docs/latest/api/app) | 使用 `app.requestSingleInstanceLock()` 並聚焦主要視窗 | 官方文件，可引用概念 |
| 大型清單轉換快取 | [React useMemo](https://react.dev/reference/react/useMemo) | 快取大型陣列轉換並避免新陣列造成 Effect 過度觸發 | 官方文件，可引用概念 |
| 獨立架構與風險審查 | Antigravity cascade `272654c8-130a-4a3f-acd5-0def63d2d1dd` | 直接覆寫 JSON、NAS 離線存在性過濾與全量列表重算列為主要風險 | 本機授權協作；含 1 次 SEARCH_WEB 軌跡 |
| 確認 Mission Center 使用版本 | 已安裝 `.codex-plugin/plugin.json`、插件快取路徑與 SKILL.md SHA-256 | 基礎版為 0.3.1；執行中腳本來自 `0.3.1+codex.9ed1bfeca60445639f45a35d424aa16e` | 本機已安裝插件；只讀核對 |
