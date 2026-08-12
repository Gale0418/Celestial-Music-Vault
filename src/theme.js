export const DEFAULT_THEME = 'listening-room';

export const THEME_OPTIONS = [
  {
    id: 'listening-room',
    name: '深夜聆聽室',
    description: '炭黑、珊瑚紅與唱片編輯感',
    swatches: ['#0a0a0a', '#ff6257'],
    ambient: ['#ff5a4f', '#ff9a7e'],
  },
  {
    id: 'neon-city',
    name: '霓虹夜城',
    description: '深藍、電光青與未來介面',
    swatches: ['#07101f', '#36e4ff'],
    ambient: ['#36e4ff', '#8f6bff'],
  },
  {
    id: 'vinyl-club',
    name: '曜金劇院',
    description: '漆黑、金箔與舞台精品感',
    swatches: ['#070706', '#d9b75f'],
    ambient: ['#d9b75f', '#8f6a18'],
  },
  {
    id: 'sakura-night',
    name: '紙白藝廊',
    description: '暖白、墨黑與日間極簡排版',
    swatches: ['#f6f4ef', '#181818'],
    ambient: ['#d8d3c8', '#ffffff'],
  },
];

export const normalizeThemeId = (value) => (
  THEME_OPTIONS.some((theme) => theme.id === value) ? value : DEFAULT_THEME
);

export const getTheme = (themeId) => (
  THEME_OPTIONS.find((theme) => theme.id === normalizeThemeId(themeId))
);
