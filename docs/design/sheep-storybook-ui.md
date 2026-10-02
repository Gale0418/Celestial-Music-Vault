# 綿羊幻想鄉：彩虹繪本

模式：Operate。目標是讓私人曲庫的羊羊主題具有完整童話卡通風格，同時維持原有播放操作。

## 設計契約

- 使用者與任務：Mac／iPad 個人音樂收藏者，快速選歌、播放與管理佇列。
- 內容與證據：歌曲封面與曲庫使用真實資料；羊角色沿用既有動畫資產。
- 視覺方向：明亮粉彩天空、大彩虹、粗描邊奶油雲朵，完全沒有地面與固定羊。奶油紙卡、可可文字、梅紫原生控制、系統圓體。方向 seed：15578f8b；使用者指定風格優先。
- 難忘畫面：巨大的彩虹天空與既有羊流星。UI 不加入自動晃動。
- 約束：維持月環、播放面板、詳情卡、佇列和底部控制原位置。只作用於 emeraldAurora；其他主題的視覺與功能保持既有分支。
- 尚待驗收：原生畫面工具無法啟動 Node runtime，不能宣稱整頁截圖驗收通過。使用者指定這輪先完成 Mac，iPad 延後。

## 素材與效能

2026-10-02 使用內建 imagegen 原創並依使用者回饋編修，shipping asset：`Native/CMV/CMV/Assets.xcassets/SheepRainbowMeadow.imageset/sheep-rainbow-meadow.png`。資產識別沿用，但圖像內容已是純天空。

編修提示：Preserve the large pastel rainbow arch; remove all ground, hills, lake, trees, plants, flowers, fences, buildings and sheep. Entire image is an airy pastel turquoise sky with rounded cream clouds, no horizon or animals. Clear hand-drawn 2D cartoon storybook illustration with thicker rounded muted blue-gray outlines around cloud silhouettes and rainbow exterior, roughly 4–6 px. Broad clean center for interface, full bleed landscape 3:2, no text or watermark.

背景插畫置於 TimelineView 外；原有有限羊群池以最高 20 fps 更新並遵循 scenePhase／Reduce Motion。裝飾層不攔截操作且對 VoiceOver 隱藏。紙卡支援 Reduce Transparency 與增加對比。

## 驗證

原創修正版圖片已目視確認沒有地面或固定羊，粗描邊與彩虹符合最新要求。獨立代理完成 source／資產靜態審查，沒有確定 P0–P2；這不等於實際 GUI 驗收。最終建置、CodeRabbit 與交付結果另記 MissionCenter/smoke-tests.md。

## 最新美術修正：日式動畫

使用者於 2026-10-02 指定改為日式動畫風格。背景已重繪為清透藍天、暖白積雲、藍紫色賽璐璐明暗與乾淨輪廓；保留巨大彩虹、完全無地面與固定羊。UI 沿用奶油色與柔和梅紫控制，原有位置不變。這次僅替換點陣資產，不修改已審查的 Swift 邏輯。

素材：imagegen `exec-09e84234-e175-4427-a2e3-b0ea88346ae0.png`。提示摘要：Original Japanese anime sky background; luminous cyan-blue summer sky, warm ivory cumulus clouds, blue-gray linework, lavender cel-shaded shadows, clean smooth painting, huge pastel rainbow; no ground, horizon, vegetation, buildings, sheep, text or interface.
