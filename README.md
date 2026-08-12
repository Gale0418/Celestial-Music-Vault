# AeroMusic

AeroMusic 是以 Electron、React 與 Vite 製作的 macOS 音樂播放器，支援本機與 NAS 音樂資料夾、播放清單、迷你播放器、影片播放及音效等化器。

## 系統需求

- macOS（目前打包目標為 Apple Silicon arm64）
- Node.js 22 或相容版本
- npm

## 開發與驗證

```bash
npm ci
npm test
npm run lint
npm run build
npm start
```

`npm start` 會載入已產生的 `dist/`，因此首次啟動或修改前端後要先執行 `npm run build`。

## NAS 專案的 macOS 打包

本專案位於 SMB/NAS 時，macOS 可能拒絕直接載入 NAS 上的原生 Node 模組。請使用隨附腳本；它會把必要原始碼複製到 `/tmp`、以 `npm ci` 建立乾淨依賴、執行測試與建置，再輸出 App 與 DMG：

```bash
./scripts/build-macos.sh
```

若要直接輸出至指定位置：

```bash
AEROMUSIC_OUTPUT_DIR="/path/to/output" ./scripts/build-macos.sh
```

更完整的背景與問題排查請見 [`docs/PACKAGING_AND_OPTIMIZATION.md`](docs/PACKAGING_AND_OPTIMIZATION.md)。

## 專案結構

```text
build/          electron-builder 圖示與建置資源
docs/           維護與打包文件
scripts/        可重複執行的維護腳本
src/            React 應用程式
tests/          主程序安全與行為測試
dist/           可重建的 Vite 輸出（不進版控）
dist-app/       可重建的 Electron App/DMG（不進版控）
MissionCenter/  本次維護任務與驗證紀錄
```

## 安全模型

- Renderer 不啟用 Node.js integration，並啟用 context isolation。
- App 與本機媒體透過 `aeromusic://` 安全協定載入。
- 本機媒體只允許來自使用者經原生資料夾選擇器核准的根目錄。
- 移至垃圾桶、掃描資料夾與持久化資料均由主程序重新驗證路徑。
