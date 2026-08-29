# 星穹私藏音樂庫 Celestial Music Vault（CMV）2.0 Design System

## Direction: Celestial Cloud Atlas

CMV is a calm, luminous atlas of a private music universe. Stars, clouds,
auroras, and prismatic light create wonder; the library remains unmistakably an
Apple-native productivity surface. Vinyl, turntables, lacquer, and mastering
hardware are not part of this visual language.

The approved visual references are:

- `.impeccable/mocks/approved/cmv-macos-celestial.png`
- `.impeccable/mocks/approved/cmv-ipad-landscape-celestial.png`
- `.impeccable/mocks/approved/cmv-ipad-portrait-celestial.png`

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
| 鈦銀月蝕 | midnight indigo | moon silver | cyan | ice blue |
| 翠綠極光 | deep teal | emerald mist | mint | prismatic green |
| 琥珀晨曦 | lavender dusk | peach | amber | sunrise gold |

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
- Reduce Motion replaces drifting/parallax effects with a static, composed sky.
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
