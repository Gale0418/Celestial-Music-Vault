# 月光柱與繁星背景（AERO-F26，2026-09-14）

## 本輪確認的規格

- 音柱改為向外灑出的光柱：寬根、漸細、柔弧收尖，透明度在尖點前淡出；白根至主題色，保留外側藍影。
- 保留真實 PCM 能量、四秒整圈輪動、月環原中心及大小；光束可以超出畫面。
- 背景增加大小、亮度與節奏不同的閃爍繁星。
- 落星走不同起點／角度／速度的**直線**，不使用彎曲軌道；五角星下落時翻面。
- 夏季大三角與北斗七星固定在背景，局部星位保持等比例；兩組各自構圖，不是特定地點／時間的即時全天星圖。其餘繁星與落星為裝飾分布。

## 實作與資源邊界

- `CelestialViews.swift`：128 主光束＋半格藍影，各束線性淡出，共用一次模糊薄霧；最長 156pt、Canvas 外伸 168pt，中心容器不變。
- 繁星預設 180 顆（256 顆硬上限）；位置、大小及節奏預先計算，每幀只更新亮度。背景 30Hz，與月環顯示時鐘分離；Mac 保留獨立裝飾 hosting graph。
- `StarfallRenderer.swift`：固定 36 粒子池，包含 4 顆流星；尾點有限、無歷史軌跡累積。五角星以橫向縮放及小角度旋轉翻面，頭尾保持同一直線。
- `ConstellationRenderer.swift`：只含 10 顆命名恆星及 10 段連線，位於動畫時鐘外的靜態 Canvas；北向上、赤經增加朝左。局部投影為近似，不是科學級天文渲染器。
- Reduce Motion 使用靜態繁星，停止月環空間旋轉並不繪製落星；scene inactive 時停止背景計時，裝飾不攔截點按。Reduce Transparency 不使用月光薄霧。
- 沒有新增圖片、第三方依賴、連網執行需求、定位或獨立計時器。iPad 實機 FPS／記憶體峰值尚未量測，不能由固定粒子數或 Simulator 編譯推定流暢。

## 驗證紀錄

- 原始 `beamPath` 方法摘錄的 Swift 測試：1,152 組不同方向／半徑／長度的 Canvas 邊界及中心排除檢查通過（`/tmp/cmv-moonlight-geometry.swift`）。不是播放端到端測試。
- 實際 StarfallRenderer 的 native ImageRenderer fixture：t=0／2／4 能渲染、101 組直線共線取樣通過（`/tmp/cmv-starfall-preview.swift`）；不是 App 或 iPad 截圖。
- 初始月光柱 Mac Release 通過。第一輪 iPad build 在星雨新檔加入前已產生來源清單，因找不到 StarfallRenderer 失敗；不列為最終通過證據。
- 初次整合 Mac／iPad Simulator Release 均 BUILD SUCCEEDED；Mac 桌面啟動與 1,967 首曲庫可見，strict codesign、executable cmp 通過。
- 畫面檢查發現全窗星圖被內容／佇列遮蔽，iPad TabView 的不透明底層遮住星空；修正為收聽內容內的背景及頂部留白星圖，第二次 Mac／iPad Release 均 BUILD SUCCEEDED，兩端實際截圖可見月光柱、三角與北斗。截圖：`/tmp/cmv-starlight-mac-confirm.png`、`/tmp/cmv-starlight-ipad-confirm.png`。
- 使用者回報歌曲頁頂部錯位，另從 iPad 截圖發現星圖橫向偏移；對 `CelestialBackground` 加入 GeometryReader 及明確 frame／clipped，防止 scaledToFill 圖片影響裝飾層尺寸。追加修正 Mac Debug、Mac／iPad Release 均 BUILD SUCCEEDED（`/tmp/cmv-sky-bounds-*.log`）；獨立 QA 收聽頁截圖沒有全窗 gap。AX 切歌曲頁未成功，不把該截圖冒稱歌曲頁驗收；最後尺寸修正後的 iPad 畫面／實機 FPS 仍待驗。
- 最終 Release 已替換 `/Users/<LOCAL_USER>/Desktop/CMV.app`，strict codesign／executable cmp 通過；最後一次替換未停止既有桌面程序，需使用者重新開啟生效。舊版皆移入明確命名的垃圾桶備份，可復原。獨立 QA 程序與本輪啟動的 iPad Simulator 已停止。
- 桌面更新時重啟了使用者的 App。原曲庫與收藏資料保留，但記憶體中的播放佇列沒有自動恢復；未將佇列持久化列為本輪已修功能。
- 10:54 左右唯讀 SQLite 核對實際桌面程序開啟的 store：1,967 曲目、112 來源；但曲目均 `ZISEXCLUDED=1`，因此 UI 顯示 0。已詢問使用者是否主動移出，尚未取得回答；未直接改寫／清除資料庫或取消排除標記。
- 本輪不重跑未改動的 Rust／Swift 核心全套測試，不把歷史測試當成此次視覺效能證據。

## 星位來源與呈現限制

使用 SIMBAD ICRS(J2000) 座標作固定近似投影；原始座標與每顆來源 URL 保存在 `ConstellationRenderer.swift` 註解。Summer Triangle 成員另核對 NASA。

- [SIMBAD Vega](https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Vega)、[Deneb](https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Deneb)、[Altair](https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Altair)
- [SIMBAD Dubhe](https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Dubhe)、[Merak](https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Merak)、[Phecda](https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Phecda)、[Megrez](https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Megrez)、[Alioth](https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Alioth)、[Mizar](https://simbad.u-strasbg.fr/simbad/sim-basic?Ident=zet+uma)、[Alkaid](https://simbad.cds.unistra.fr/simbad/sim-basic?Ident=Alkaid)
- [NASA: Summer Triangle Corner — Altair](https://science.nasa.gov/solar-system/skywatching/night-sky-network/summer-triangle-corner-altair/)

## 任務中心與審查界線

正式 Rust Mission Center 0.5.2 sync 可執行。這次 SMB 重連位址為 `<NAS_SHARE_URL>`，實際掛載 `<LOCAL_VOLUME_PATH>`；未建立第二份原始碼或強制卸載其他磁碟。

本輪為局部視覺變更，未新增 CodeRabbit 外部審查。依 Mission Center 完成評論規範，視覺切片屬 critic_lite；缺少該閘門要求的總量／席位／工具／時間預算授權，未派正式評論席，不能冒稱已通過。AERO-F26 維持 Review，實作子代理與主代理檢查不充當正式 council。
