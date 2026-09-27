# 土星 UI 面板全息流光

範圍：土星環軌站的歌曲播放面板、聆聽詳情卡、底部 `PlayerBar`／`MiniPlayerBar` 全息流光與整體背景光澤。模式：Operate；讓使用者辨識封面、歌曲並操作播放，同時感受到隨輸入觀看的立體材質。月環完全不承載流光；原 PCM 環形波形、圓形封面、其他主題、影片入口、播放控制、進度、評分、收藏及本機資料持久化沿用原行為。

## Direction contract

**THESIS**：保留既有圓形專輯封面與月環／PCM 環形波形；由滑鼠或重力驅動的全息流光只放在歌曲播放面板、聆聽詳情卡與底部播放列的背景，圓形封面與月環維持原樣，月環完全無流光。沒有操作時不自動搖擺。

**OWN-WORLD**：延續 Celestial Cloud Atlas；深色底材、冰藍切邊與金色土星。真實封面維持圓形 mask，無封面時沿用既有 fallback。整個背景與土星 UI 面板使用分層全息光澤，文字和控制維持 Apple 原生語意。

**STORY**：先辨識封面與歌曲，再播放、調整進度或評分。月環與 PCM 環形波形仍是播放狀態的視覺回饋，但月環不加流光；播放控制固定在既有資訊區與底部播放列，不移入封面或背景。

**FIRST VIEWPORT**：以 `5fdbf0e`（土星主題前）作為版型歷史基準；寬窄排版、歌曲資訊與播放控制位置依該基準，土星寬版只讓右側歌曲／播放面板整組向下 `24 pt`。月球／月環位置與尺寸不改，背景全幅承接同一輸入樣本。

**FORM**：先前票卡替代圓盤是代理對需求的誤解，本輪改為 UI 面板流光的局部延伸；不保留票券輪廓、缺口、票根、energy bar 或 ticket enum。移除 moon 的 cover parallax；`.interface` 只讓三個 UI 面板背景流光，月環不套用流光，輸入以 0.16 秒平滑跟手。Reduce Motion 停止輸入動態；Reduce Transparency／提高對比讓面板回到不透明語意底材。

## 實作對照

- `Native/CMV/CMV/LibraryViews.swift` 的 `NowPlayingView` 以 `5fdbf0e` 作為原版型基準，維持原 headline、影片入口、進度、評分、收藏與本機資料流；土星寬版只對右側歌曲／播放面板整組套用 `.offset(y: 24)`。歌曲／播放面板與聆聽詳情卡均以 `ultraThinMaterial.opacity(0.34)` 疊深色 tint `0.14`，背景內的 `padding(-24)` 只延伸繪製範圍，不改 layout；內層 transport 控制維持 `thinMaterial.opacity(0.30)` 與原內卡邊框。
- `Native/CMV/CMV/CelestialViews.swift` 的 `AlbumWorldView` 維持圓形 artwork、fallback、`AudioEnergyRing` 與 PCM 環形波形；月環位置與尺寸以 `5fdbf0e` 為基準，月環完全無流光，土星主題不替換月環或圓盤，moon 不再套用 cover parallax。
- `Native/CMV/CMV/CelestialParallax.swift` 的 `.interface` 只在歌曲播放面板、聆聽詳情卡與底部 `PlayerBar`／`MiniPlayerBar` 背景提供 `CelestialPanelSheen`；面板流光是寬度 100–260 pt、左右透明的窄柔光，並垂直延伸避免寬播放列露出旋轉邊，`horizontalTravel = max(0, (width - stripWidth) / 2)` 限制中心不逸出。文字與按鈕固定在流光之上且不被覆蓋。整個背景保留 `CelestialSkySheen`，所有效果只由輸入驅動，更新以 `easeOut` 0.16 秒跟手；Reduce Transparency／Increased Contrast 時面板改用不透明底材。
- 一般字級圖示維持原樣；僅 iPad 最大無障礙字級下，純 `iconOnly` 圖示由 `PlaybackIconSize` 固定 22 pt、小月圖固定 20 pt，文字仍遵循 Dynamic Type，`shuffle` 與 `video` 控制維持原 44 pt 觸控框。

## Git 歷史定位

- `5fdbf0e`（2026-09-26 03:46 +08:00）是土星改版前的版型基準。
- `74df366`（2026-09-27 03:19 +08:00）開始為歌曲／播放區加上 24 pt layout padding，並替圓形封面加入 cover parallax；這是本次定位的首個差異。後續土星背景提交沒有再改這兩區的主要幾何。
- 本輪恢復前版量測與固定月環；保留使用者後續指定的半透明 UI 背景、流光及寬版右面板下移 24 pt。

## 驗證狀態與限制

- 最新四個 Swift 檔經隔離 CodeRabbit review，`review_completed`、0 findings；大型素材未傳入。
- 最新 macOS arm64 Debug 與 Release 均建置成功；主代理在保留側欄與 Up Next 的原生視窗確認月環在左、半透明播放區在右、下方詳情卡可見背景，月環無面板流光。
- 獨立視覺專家在原生隔離預覽檢查兩端輸入位置與睡眠選單；未見 P0／P1／P2、月環漂移、面板硬邊或控制遮擋。
- 桌面正式版經原生 sandbox entitlement 重新簽署、strict verify，原生畫面確認 1,964 首曲目與既有側欄狀態。
- 本輪不宣稱完整 VoiceOver、真實 iPad 手持傾斜、長時間 GPU 效能或實際音訊播放驗證；安裝結果另記 MissionCenter 煙霧測試。

## 參考與素材

- [LerSent001/holo-card](https://github.com/LerSent001/holo-card)：分層視差／重力輸入概念參考；未引入程式碼或依賴。

- 全息背景／前景／UI 分層與輸入光澤僅作概念參考；本輪 brief 範圍包含歌曲播放面板、聆聽詳情卡與底部 `PlayerBar`／`MiniPlayerBar`，採原生 SwiftUI 與既有 Celestial parallax 實作，不引入票卡 runtime 或外部圖片分割服務。
- 沿用既有土星背景、使用者歌曲封面與原創素材來源；不新增點陣素材。原創素材來源見 `Native/SATURN_ASSET_PROVENANCE.md`。
