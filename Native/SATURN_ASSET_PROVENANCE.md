# 土星環軌站背景素材紀錄

- 產生日期：2026-09-27（Asia/Taipei）
- 產生工具：本次 Codex 工作階段的 OpenAI imagegen
- 歷史素材：`SkySaturnOrbit`；目前 Pro 土星改由下述原創程序球面／星環渲染，不再顯示這張靜態大氣圖。
- 原始輸出：1586 × 992 PNG，SHA-256 `511857e813ba2c7d6f2193c1aff58e91d1003bc64c63c7123fd5da9ee4841476`
- 交付轉碼：HEIC，品質參數 82，SHA-256 `a32853ab3e45283ed48638a8132b271586de2625c73bf96268e890e57e5854c3`
- 輸入參考：先以純文字要求原創土星背景，再兩次編修同一次生成的草稿；最後一版依使用者指出的環面角度，要求星環長軸與大氣雲帶投影方向平行。未上傳或直接改作 NASA 影像。
- 視覺要求：右側巨大半顆土星、與大氣條帶方向一致的斜向赤道星環、左側深色文字空間、無字樣、標誌及點狀星星。
- 科學參考：[NASA Saturn's Atmosphere and Rings](https://science.nasa.gov/photojournal/saturns-atmosphere-and-rings/)；僅參考土星大氣與環的形態，未將照片作為輸入或複製到產物。
- 條款參考：[OpenAI Terms of Use](https://openai.com/policies/terms-of-use/) 的內容權利章節；產生內容的相似性與最終發布適切性仍由發布者檢查。

這份紀錄說明素材來源，不宣稱 NASA 核可或背書，也不代替上架前的整體素材權利審核。

## 使用者指定的角度（2026-09-27 追加修正）

- 構圖參照使用者提供的原始 `exec-e9b5173c-7ebe-4fa6-9a71-1a19ca9cb3ce.png`：右側巨大半球、扁薄星環由左下向右上穿過前景。
- 動態場景以共軸球面／環面重建，球心 `(1393,420)`、半徑 `553`；畫面斜角約 `−25.8°`、環面開口參數 `0.12`。這是依圖調整的藝術化幾何，不將舊圖大氣混回動畫。
- 不為了完整露出北極六角而提高觀看仰角；極區可由構圖自然裁切。
- 依使用者追加要求，以固定亂數種子的極座標格撒上糖霜狀星光：位置、大小與閃爍相位各異，少數帶明亮短星芒；環面上下另有稀疏星光，軌道高度依種子錯落於球半徑的 ±0.06–0.11。四組軌道週期為 64／80／96／120 秒，星光獨立計算球體及冰塵遮擋；屬原創美術效果，不代表真實星體位於土星環內。

## 原創動態雲圖

- `SaturnCloudMap.imageset/saturn-cloud-map.png` 為主代理以確定性週期雜訊親自繪製的 2048 × 1024 雲層紋理；未取用外部圖片。
- 生成器：`Native/tools/generate_saturn_clouds.swift`，使用 macOS CoreGraphics／ImageIO，固定參數可重建同一張 PNG。
- SHA-256：`93294007673ffc0bcd28a2bf27f7a86709d4bd6913b58fd7ba65c4341eedfccd`。
- Metal 將無縫經度貼圖投影到完整程序球面，十二帶獨立差速旋轉（18–80 秒一圈）；所有可見緯度（含球緣及星環後方）皆取樣動態雲圖，不混入靜態大氣底圖。
- 球面、北極與星環共用同一軸；以正交射線與環面交點深度計算球體遮擋。光源、輪廓、環面及鏡頭固定；星環細紋、行星投影與微光皆為原創數學渲染。

## 銀河遠景與電影光照（2026-09-27）

- 新增 `SkyMilkyWayDepth.imageset/sky-milky-way-depth.heic`；內建 imagegen 生成，未提供外部影像輸入。
- 原始 PNG：1586 × 992，SHA-256 `72e13ac78d91ae2537d26672b225aa68b4efdcf1cd4777f2fd44e364200dbc30`。
- HEIC 品質 85，SHA-256 `38b1c930b9e06186d49590c13a1e6a81c41627e00712f75ca4bfe4b3b00ef01f`。
- 銀河為獨立遠景，不參與大氣旋轉。程序土星以預乘透明度覆蓋遠景，沒有圖片去背接縫；星圖置於行星背後。
- 雲圖生成器增加五處經度週期旋渦及較明顯的帶狀對比；雲圖 SHA-256 已更新。暖金側光與明暗交界由固定光源計算。
- 六角噴流形態參考 [NASA Cassini 極區影像](https://science.nasa.gov/photojournal/in-full-view-saturns-streaming-hexagon/)，為程式繪製的藝術化極區結構，未複製 NASA 照片。六角邊界不隨差速雲帶整體旋轉；近側面半球構圖可能裁切極區，並非極地俯視圖或科學模擬。
- 銀河中的細小星塵是生成美術，不能當成天文目錄；可識別前景星點仍由既有星圖渲染器繪製。

- 微小雲內閃電參考 [NASA Cassini 土星閃電影像](https://science.nasa.gov/photojournal/lightning-flashing-on-saturn/) 的局部雲頂亮斑形式；以原創 Gaussian 光暈和短促雙閃繪製，未使用 NASA 圖像或音訊。尺寸、頻率、色調均為背景美術設計，非氣象預測／科學模擬。

### imagegen 完整提示詞

Use case: stylized-concept. Asset type: original far-background bitmap for a premium native music player on Mac and iPad, layered behind an existing giant golden Saturn on the right. Generate a cinematic deep-space Milky Way panorama, wide landscape approximately 16:10. A richly detailed but restrained curved diagonal galactic dust river crosses from lower left toward upper middle, with ink-indigo voids, intricate charcoal dust lanes, diffuse cool silver-blue stellar haze, faint violet and a very small warm champagne core glow in upper middle-left. The leftmost 20 percent and lower middle remain predominantly dark so white UI text reads clearly. Brightest structure should occupy upper middle rather than the entire image. The right third is calmer deep midnight space because Saturn will occupy that area. Beautiful realistic astrophotographic nebulosity, delicate depth, no planets, no rings, no earthly horizon, no clouds resembling terrestrial weather, no typography, no logos, no lens flares, no artificial diffraction spikes, no large individual point stars. Dense unresolved stellar dust is welcome; visible point stars will be drawn separately by the app's astronomical star catalog. Not a UI screenshot. The composition should work behind glass album cards and remain tasteful with foreground readable. Produce a finished full-bleed image, no frame.
