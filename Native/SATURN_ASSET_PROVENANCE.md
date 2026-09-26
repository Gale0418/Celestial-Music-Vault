# 土星環軌站背景素材紀錄

- 產生日期：2026-09-27（Asia/Taipei）
- 產生工具：本次 Codex 工作階段的 OpenAI imagegen
- 用途：`SkySaturnOrbit`，Mac／iPad App 內的 Pro 背景
- 原始輸出：1586 × 992 PNG，SHA-256 `511857e813ba2c7d6f2193c1aff58e91d1003bc64c63c7123fd5da9ee4841476`
- 交付轉碼：HEIC，品質參數 82，SHA-256 `a32853ab3e45283ed48638a8132b271586de2625c73bf96268e890e57e5854c3`
- 輸入參考：先以純文字要求原創土星背景，再兩次編修同一次生成的草稿；最後一版依使用者指出的環面角度，要求星環長軸與大氣雲帶投影方向平行。未上傳或直接改作 NASA 影像。
- 視覺要求：右側巨大半顆土星、與大氣條帶方向一致的斜向赤道星環、左側深色文字空間、無字樣、標誌及點狀星星。
- 科學參考：[NASA Saturn's Atmosphere and Rings](https://science.nasa.gov/photojournal/saturns-atmosphere-and-rings/)；僅參考土星大氣與環的形態，未將照片作為輸入或複製到產物。
- 條款參考：[OpenAI Terms of Use](https://openai.com/policies/terms-of-use/) 的內容權利章節；產生內容的相似性與最終發布適切性仍由發布者檢查。

這份紀錄說明素材來源，不宣稱 NASA 核可或背書，也不代替上架前的整體素材權利審核。

## 原創動態雲圖

- `SaturnCloudMap.imageset/saturn-cloud-map.png` 為主代理以確定性週期雜訊親自繪製的 2048 × 1024 雲層紋理；未取用外部圖片。
- 生成器：`Native/tools/generate_saturn_clouds.swift`，使用 macOS CoreGraphics／ImageIO，固定參數可重建同一張 PNG。
- SHA-256：`5633e83207f031195eb01a936d00d48193b31b57297176c186f2e9b708d1cd4b`。
- Metal 將無縫經度貼圖投影到固定球面，七帶獨立旋轉；原背景提供固定光照、輪廓與星環。
- 球面遮罩以原始圖片九列輪廓亮度梯度擬合：圓心約 `(1393, 420)`、半徑 `553`（來源圖片像素）；輪廓殘差約 ±5 像素，邊緣柔化 8–40 像素，避免雲圖滲出球緣。
