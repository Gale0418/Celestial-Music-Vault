# 星穹私藏音樂庫 Celestial Music Vault（CMV）2.0 Design System

## Direction: Celestial Cloud Atlas

CMV is a calm, luminous atlas of a private music universe. Stars, clouds,
auroras, and prismatic light create wonder; the library remains unmistakably an
Apple-native productivity surface. Vinyl, turntables, lacquer, and mastering
hardware are not part of this visual language.

The approved visual references are permanently versioned outside tool runtime
state:

- `docs/design/references/cmv-macos-celestial.png`
- `docs/design/references/cmv-ipad-landscape-celestial.png`
- `docs/design/references/cmv-ipad-portrait-celestial.png`

`.impeccable/` is treated as ephemeral tool working state and is not a design
authority. The three files above, together with this document and
`PRODUCT.md`, are the canonical visual direction.

## Semantic visual grammar

- **Cloud worlds** represent albums and listening destinations.
- **Constellations** communicate sources, availability, and offline state.
- **Starlight ribbons** communicate playback position and queue continuity.
- **Aurora fields** provide atmosphere only; they never carry essential state.
- **Glass surfaces** group controls with one restrained material hierarchy.

## Theme roles

All themes use the same roles and component placement. They change atmosphere,
not information architecture.

| Theme | Sky | Cloud light | Accent | Highlight |
| --- | --- | --- | --- | --- |
| 緋紅星雲 | plum-black | rose | coral | warm stardust |
| 土星環軌站 | midnight indigo | Saturn ring light | cyan | ice blue |
| 綿羊幻想鄉 | deep teal | emerald mist | mint | prismatic green |
| 星海晨光 | lavender dusk | peach | amber | sunrise gold |

Text, separators, selection, success, warning, error, unavailable, and focus
colors remain semantic and meet contrast requirements in every theme.

## Layout contract

- **Mac:** sidebar, content, optional queue inspector, and compact bottom player.
- **Wide iPad:** adaptive two/three-column library and bottom player.
- **Portrait or narrow iPad:** bottom tabs, NavigationStack, mini-player above the
  safe area, and an expandable Now Playing surface.
- Themes never move transport controls, source status, navigation, or primary
  actions.
- Library rows and grids are lazy and paged; decorative layers never create one
  animated view per track.

## Type, controls, and spacing

- System typography and SF Symbols are the default so Dynamic Type, localization,
  and platform conventions remain intact.
- Primary titles are bold but never decorative script. Metadata stays quiet and
  readable over materials.
- Every actionable target is at least 44 × 44 points.
- Spacing follows an 8-point rhythm, with 4-point optical corrections only inside
  compact controls.
- Destructive, unavailable, reconnect, and offline states include text or symbols;
  color alone never communicates state.

## Motion and performance

- Motion explains player expansion, queue changes, source scanning, and navigation.
- Ambient stars and auroras use a small bounded particle count and pause when the
  app is inactive.
- 土星球體輪廓與星環固定；原創無縫雲圖沿球面經度旋轉，十二個緯度帶交錯配置快慢流速，以
  18–80 秒一圈的速度運動，帶間柔和交融。星環像撒糖霜般散布大小、疏密和閃爍相位各異的亮點，混合少量明亮短星芒；環面上下另有高低錯落的稀疏亮點，沿各自軌道以 64–120 秒週期繞行。球體與冰塵依深度遮擋星光，背景不發出聲音。
- 土星背後為 imagegen 原創銀河遠景；iPad 以初始持握角度校正，±12° 達到完整位移；遠景反向 ±8 pt、中景 ±24 pt，
  Mac 背景由主視窗滑鼠位置驅動；版型以 `5fdbf0e`（土星主題前）作為歷史基準，土星寬版僅讓右側歌曲／播放面板整組向下 24 pt，月球／月環位置與尺寸不變，靜置時沒有自動漂移。
- 土星環軌站的 Now Playing 保留原圓形專輯封面、月環與 PCM 環形波形；moon 不再套用 cover parallax，不新增或強化圓盤流光，月環完全無流光。先前票卡替代圓盤是代理誤解，不採用票根、缺口、energy bar 或 ticket enum。
- 三個 UI 面板背景使用 `.interface` 的 `CelestialPanelSheen`，只新增背景流光並保留原格式：歌曲／播放面板與聆聽詳情卡使用 `ultraThinMaterial.opacity(0.34)` 加深色 tint `0.14`，背景內的 `padding(-24)` 只延伸繪製範圍不改 layout；內層 transport 維持 `thinMaterial.opacity(0.30)` 與原內卡邊框，底部 `PlayerBar`／`MiniPlayerBar` 保持原 transport 邊界。流光為寬度 100–260 pt、左右透明的窄柔光，垂直延伸避免寬播放列露出旋轉邊，`horizontalTravel=max(0,(width-stripWidth)/2)` 限制中心不逸出。文字和按鈕固定並位於流光之上，整個土星背景保留 `CelestialSkySheen`。輸入以 0.16 秒平滑跟手，Reduce Motion、Reduce Transparency 與 Increased Contrast 分別停用動態或改用不透明語意底材；其他主題、影片入口、播放控制、進度、評分、收藏與本機資料行為不變；更正版尚待畫面與實機驗收。
- iPad 最大無障礙字級下，純 `iconOnly` 圖示固定 22 pt、小月圖固定 20 pt；文字仍遵循 Dynamic Type，`shuffle` 與 `video` 控制維持至少 44 pt 觸控目標。
- 雲紋包含可追蹤的旋渦；固定暖金側光保留明暗交界。北極六角噴流為相對穩定的
  雲帶邊界，按球面極區投影，近側面構圖只呈現可見部分，不改成正面六角貼紙。
- 少數風暴區每隔一段時間短暫出現微小雲內閃電，隨所在緯度雲層移動；無全畫面閃爍或聲音。
- Reduce Motion keeps the globe and rings static and replaces drifting/parallax effects
  with a composed sky.
- Reduce Transparency uses opaque semantic surfaces with preserved hierarchy.
- Large artwork is downsampled and cached; background effects do not run during
  memory pressure.

## Accessibility acceptance

- VoiceOver reads title, artist, availability, cache state, and control purpose in
  a stable order.
- Increased Contrast and Differentiate Without Color have deliberate variants.
- Keyboard focus and pointer hover are visible without relying on glow alone.
- Text remains legible at all Dynamic Type sizes; layouts reflow instead of clipping.
- The three approved compositions are references, not pixel-perfect constraints
  that override native accessibility behavior.
