# AeroMusic — 打包指南 & 全方位優化分析

> 🤖 由 Antigravity（天才青梅竹馬工程師）親筆撰寫，供未來的自己（以及其他的我）參考。
> 最後更新：2026-07-21

---

## 一、專案架構概覽

```
music/
├── main.cjs           # Electron 主進程 (Node.js)
├── preload.cjs        # Context Bridge — 安全的 IPC 橋樑
├── vite.config.js     # Vite 前端構建設定
├── package.json       # 含 electron-builder 打包配置
├── src/
│   ├── App.jsx
│   ├── index.css
│   ├── context/AudioContext.jsx   # 核心音頻狀態機（超大！1144行）
│   └── components/
│       ├── LocalLibrary.jsx       # 音樂庫 UI（超大！1077行）
│       ├── PlaybackBar.jsx        # 底部播放列
│       ├── Sidebar.jsx
│       └── ListenNow.jsx
├── dist/              # Vite 前端構建輸出
└── dist-app/          # electron-builder 打包輸出
```

**Tech Stack：** React 19 + Vite 8 + Electron 42 + electron-builder 26

---

## 二、打包流程 SOP（標準作業程序）

### 🚨 核心問題：專案放在 NAS/SMB 網路磁碟上！

這個專案位於 `<VOLUME_PATH>`，是掛載的 NAS 網路磁碟。
直接在上面跑 `electron-builder` 會因為 SMB 的**檔案鎖定機制** (`.smbdelete*`) 導致打包失敗。

### ✅ 正確打包指令（一行搞定）

```bash
# 在專案根目錄執行（必須設好環境變數！）：
ELECTRON_BUILDER_CACHE=/tmp/electron-builder-cache TMPDIR=/tmp \
  npm run build && \
  npx electron-builder --mac --arm64 && \
  cp -a dist-app/mac-arm64/AeroMusic.app ~/Desktop/
```

**各環境變數說明：**

| 變數 | 用途 |
|------|------|
| `ELECTRON_BUILDER_CACHE=/tmp/...` | 把 Electron 框架下載快取強制寫在本機 SSD，不碰 NAS |
| `TMPDIR=/tmp` | 所有解壓縮暫存檔案也寫在本機 |

### 🔁 完整流程說明

```
[Step 1] npm run build
   └─ 執行 vite build
   └─ 輸出至 dist/ (index.html + CSS + JS bundle)
      build time: ~50s（首次），~443ms（快取後）

[Step 2] electron-builder --mac --arm64
   ├─ 讀取 package.json 的 "build" 欄位配置
   ├─ @electron/rebuild：重新編譯 native modules（arm64）
   ├─ packaging：把 dist/ + Electron 框架 + main.cjs + preload.cjs 打包
   ├─ 略過 code signing（identity 設為 null）
   └─ 輸出 dist-app/mac-arm64/AeroMusic.app
         + dist-app/AeroMusic-x.x.x-arm64.dmg

[Step 3] cp -a dist-app/mac-arm64/AeroMusic.app ~/Desktop/
   └─ 複製 .app 到桌面，可直接點開
```

### ⚠️ 已知陷阱 & 解決方案

| 問題 | 原因 | 解決 |
|------|------|------|
| 打包失敗 `unlinkat ...` | SMB 在 dist-app/ 建立了 `.smbdelete` 鎖定檔 | 設定 `TMPDIR=/tmp` + `ELECTRON_BUILDER_CACHE=/tmp/...` |
| 打包失敗 `ENOENT: ...` | electron-builder 嘗試在 NAS 上寫 debug 檔但路徑被鎖 | 同上，TMPDIR 搞定 |
| `arm64 requires signing` | Apple Silicon 需要 code sign | 本機測試可 skip，若要分發需申請 Apple Developer 憑證 |
| **【無限轉圈圈 Bug】** 換歌或閒置時狂 reload 導致 UI 凍結 | `AudioContext` 裡監聽了整個 `playlist` 陣列，只要 autosave 觸發，陣列 reference 一變就會重新 `audioRef.load()` | 修改 `useEffect` 依賴陣列，**只監聽 `currentTrackIndex`**，不要把整個 `playlist` 丟進去！ |

---

## 三、全方位優化分析（專家評審團）

> 以下模擬多位不同領域的專家從刁鑽角度審查本專案。

---

### 👨‍💻 Expert A — 架構師（System Architect）

> **評語：`AudioContext.jsx` 是個 God Object，必須拆解！**

#### 問題

`AudioContext.jsx` 目前 **1144 行**，身兼數職：
- 音頻播放狀態管理
- Web Audio API EQ 初始化
- 本地檔案匯入（兩種路徑：blob URL vs file:// IPC）
- 資料持久化（localStorage / Electron IPC）
- 影片浮窗的拖曳邏輯（！！不應該放在這裡）
- 播放清單 CRUD（favorites / playlists / library）

#### 建議拆分方案

```
src/
├── context/
│   └── AudioContext.jsx          # 只保留 context 定義 + Provider 組合
├── hooks/
│   ├── useAudioEngine.js         # Web Audio API + EQ + 播放控制
│   ├── useLibrary.js             # 音樂庫 CRUD + 匯入（importLocalFiles）
│   ├── usePersistence.js         # 資料存檔/讀取（Electron IPC）
│   ├── usePlaylists.js           # 播放清單管理
│   └── useDraggableVideo.js      # 影片浮窗拖曳邏輯
```

---

### 🔐 Expert B — 資安工程師（Security Engineer）

> **評語：preload.cjs 暴露太多，應收緊 IPC 攻擊面。**

#### 問題一：`webSecurity: false` 非常危險

```js
// main.cjs — 這行讓整個 file:// 協議全開放
webSecurity: false, // Allow file:// protocol for local/NAS audio files
```

這讓任何網頁都能存取本機 `file://` 資源。若 Electron 被 XSS 攻擊，
攻擊者可讀取整個檔案系統（包括 ~/.ssh、鑰匙圈、任意文件）。

#### 問題二：`trash-item` 沒有路徑白名單驗證

```js
ipcMain.handle('trash-item', async (event, filePath) => {
  await shell.trashItem(filePath); // 沒有路徑驗證！任意路徑都能刪！
});
```

#### 建議修正

```js
// ✅ main.cjs — 加入副檔名白名單（已知問題，優先修）
ipcMain.handle('trash-item', async (event, filePath) => {
  const SAFE_EXTS = new Set(['.mp3','.flac','.wav','.m4a','.ogg','.aac','.mp4','.aiff','.opus','.wma']);
  const ext = path.extname(filePath).toLowerCase();
  if (!SAFE_EXTS.has(ext)) throw new Error(`不允許刪除此類型：${ext}`);
  await shell.trashItem(filePath);
  return true;
});
```

---

### ⚡ Expert C — 效能工程師（Performance Engineer）

> **評語：以下幾個地方會造成不必要的 re-render 和記憶體問題。**

#### 問題 1：大量函式沒有 `useCallback` 包覆

```jsx
// AudioContext.jsx — 每次 render 都重建這些函式物件
const handlePrevTrack = () => { ... };
const handleNextTrack = () => { ... };
const seekTo = (value) => { ... };
// 透過 Context 傳下去 → 所有 Consumer 都 re-render！
```

**建議：** 所有傳入 Context value 的函式都套 `useCallback`。

#### 問題 2：拖曳時高頻率觸發 React setState

```jsx
// 每個 mousemove 都 setVideoPosition → React re-render（最高 60fps！）
const handleMouseMove = (e) => {
  setVideoPosition({ x: newX, y: newY }); // 高頻更新！
};
```

**建議：** 拖曳時直接操作 `ref.current.style.transform`，拖曳結束再 setState 同步一次。

#### 問題 3：大型列表沒有虛擬化

當音樂庫有 5000+ 首歌時，`LocalLibrary.jsx` 會同時渲染 5000 個 `<tr>` 造成 UI 凍結。

**建議：** 使用 `react-window` 或 `@tanstack/react-virtual`。

```jsx
import { FixedSizeList } from 'react-window';
<FixedSizeList height={listHeight} itemCount={sortedTracks.length} itemSize={52}>
  {({ index, style }) => <TrackRow style={style} track={sortedTracks[index]} />}
</FixedSizeList>
```

---

### 📦 Expert D — DevOps / 打包工程師

> **評語：打包配置有幾個缺漏，影響發佈品質與包體大小。**

#### 問題 1：package.json 缺少 description / author

每次打包都出現 warning，且會影響 .app 的 Info.plist 內容。

```json
{
  "description": "Premium macOS Glassmorphism Music Player",
  "author": { "name": "Antigravity" }
}
```

#### 問題 2：沒有 files 白名單，devDependencies 可能被打包進去

```json
"build": {
  "files": [
    "dist/**/*",
    "main.cjs",
    "preload.cjs",
    "!**/node_modules/*/{test,__tests__,*.spec.*}",
    "!node_modules/.cache"
  ]
}
```

#### 問題 3：沒有 auto-update，每次都要手動複製到桌面

建議之後整合 `electron-updater`。

#### 問題 4：Hardened Runtime 需要 entitlements.plist

`hardenedRuntime: true` 已啟用，但缺少對應的 entitlements 檔，
會在 Apple Notarization 時失敗。

```xml
<!-- build/entitlements.mac.plist -->
<dict>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
  <key>com.apple.security.files.user-selected.read-write</key><true/>
</dict>
```

---

### 🎨 Expert E — UX 工程師

> **評語：幾個 UI 細節可以大幅提升使用體驗。**

#### 問題 1：還在用 `confirm()` / `alert()` 原生對話框

非 Electron 環境的降級路徑仍使用系統原生 `confirm()`，樣式醜陋且阻塞主線程。
應改為自訂 Glassmorphism Modal。

#### 問題 2：刪除操作沒有 Undo 機制

移除音樂庫記錄 or 移至垃圾桶後，沒有 Toast + 復原機制，誤刪只能從垃圾桶撿回來。

建議實作 5 秒復原 Toast：
```
[已移除「Midnight Coding」]  [← 復原]  ×
```

#### 問題 3：右鍵 context menu 沒有邊界溢出處理

右鍵點在畫面右下角時，選單會跑出畫面外。需要在 `setContextMenu` 時
計算選單寬高與視窗邊界，動態修正 x/y 座標。

---

### 🧪 Expert F — 測試工程師（QA Engineer）

> **評語：`tests/` 資料夾存在，但沒看到任何測試！**

#### 建議補充測試

```
tests/
├── unit/
│   ├── formatTime.test.js        # 時間格式化（0, NaN, 負數邊界）
│   ├── cycleRepeat.test.js       # false → true → "one" → false
│   └── fileFilter.test.js        # .mp3/.flac 通過、.exe 被過濾
└── e2e/
    └── playback.test.js          # 播放/暫停/換曲/音量流程
```

---

## 四、優化優先度排行

| 優先度 | 項目 | 難度 | 影響範圍 |
|--------|------|------|---------|
| 🔴 緊急 | `webSecurity: false` 改回 true + 改用 protocol handler | 中 | 安全 |
| 🔴 緊急 | `trash-item` IPC 加入副檔名白名單驗證 | 低 | 安全 |
| 🟠 高 | react-window 虛擬化大列表 | 中 | 效能（大庫必備）|
| 🟠 高 | AudioContext 拆成多個 custom hook | 高 | 維護性 |
| 🟡 中 | 常用回調加 `useCallback` | 低 | 效能 |
| 🟡 中 | package.json 補 description/author | 極低 | 打包品質 |
| 🟡 中 | electron-builder files 白名單 | 低 | 包體大小 |
| 🟢 低 | 拖曳改為直接 DOM 操作（不 setState） | 中 | 效能（細節）|
| 🟢 低 | Context menu 邊界溢出處理 | 低 | UX |
| 🟢 低 | 加入 Undo Toast 機制 | 高 | UX |
| 🟢 低 | 補充 unit / e2e tests | 高 | 工程品質 |

---

## 五、打包快捷 alias（建議加到 ~/.zshrc）

```bash
alias build-aero='cd <VOLUME_PATH> && \
  ELECTRON_BUILDER_CACHE=/tmp/electron-builder-cache TMPDIR=/tmp \
  npm run build && \
  npx electron-builder --mac --arm64 && \
  cp -a dist-app/mac-arm64/AeroMusic.app ~/Desktop/ && \
  echo "✅ AeroMusic 已成功送到桌面！(｀・ω・´)ゞ"'
```

---

*📝 文件維護者：Antigravity — 天才美少女工程師、你最懂你的青梅竹馬*
*（好啦主人，文件都整理好了！下次換一個我來看這份文件，也能無縫接軌！(*´▽`*)）*
