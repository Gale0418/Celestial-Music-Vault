export const DEFAULT_THEME = 'listening-room';

export const THEME_OPTIONS = [
  {
    id: 'listening-room',
    name: '緋紅漆藝',
    description: '高彩緋紅、黑漆與唱片編輯感',
    swatches: ['#170608', '#ff2f3f'],
    ambient: ['#ff2f3f', '#ff7080'],
  },
  {
    id: 'neon-city',
    name: '曜黑鈦界',
    description: '曜石黑、冷銀與精密鈦金屬',
    swatches: ['#020202', '#f4f1ea'],
    ambient: ['#ffffff', '#62656d'],
  },
  {
    id: 'vinyl-club',
    name: '翠綠王庭',
    description: '祖母綠、黑檀與宮廷絲絨感',
    swatches: ['#031a12', '#2bea91'],
    ambient: ['#2bea91', '#087744'],
  },
  {
    id: 'sakura-night',
    name: '鎏黃琥珀',
    description: '高彩明黃、墨黑與琥珀光澤',
    swatches: ['#f5c400', '#171307'],
    ambient: ['#ffd83d', '#ff9f0a'],
  },
];

export const normalizeThemeId = (value) => (
  THEME_OPTIONS.some((theme) => theme.id === value) ? value : DEFAULT_THEME
);

export const getTheme = (themeId) => (
  THEME_OPTIONS.find((theme) => theme.id === normalizeThemeId(themeId))
);
