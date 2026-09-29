import type { HistorySkinTheme } from '../types';

// Chrome history page, measured from the native light and dark screenshots.
// Structure is shared. Only the color tokens change with the browser theme.
export const CHROME_HISTORY_SPEC = {
  layout: {
    headerHeight: 64,
    sidebarWidth: 256,
    searchHeight: 40,
    searchWidth: 680,
    cardRadius: 16,
    navRadius: 20,
    rowHeight: 48,
    icon: 20,
    favicon: 16,
  },
  light: {
    page: '#ffffff',
    card: '#ffffff',
    cardBorder: '#dadce0',
    cardShadow: '0 1px 2px rgba(60, 64, 67, 0.12), 0 1px 3px rgba(60, 64, 67, 0.08)',
    text: '#1f1f1f',
    secondary: '#444746',
    accent: '#0b57d0',
    accentBackground: '#e8f0fe',
    search: '#f0f4f9',
    hover: '#f0f4f9',
    divider: '#e1e3e1',
    line: '#c4c7c5',
    menu: '#ffffff',
    menuBorder: '#dadce0',
  },
  dark: {
    page: '#1f1f1f',
    card: '#28292a',
    cardBorder: 'transparent',
    cardShadow: 'none',
    text: '#e3e3e3',
    secondary: '#c4c7c5',
    accent: '#a8c7fa',
    accentBackground: '#3c4043',
    search: '#303134',
    hover: '#3c4043',
    divider: '#444746',
    line: '#5f6368',
    menu: '#2d2e30',
    menuBorder: '#444746',
  },
} as const;

export type ChromeHistoryCopy = {
  title: string;
  search: string;
  history: string;
  otherDevices: string;
  clearData: string;
  open: string;
  openNewTab: string;
  remove: string;
  selected: (count: number) => string;
  closeSelection: string;
  deleteSelected: string;
  empty: string;
  emptyOther: string;
  loading: string;
  login: string;
};

const ZH_COPY: ChromeHistoryCopy = {
  title: '历史记录',
  search: '搜索记录',
  history: 'Chrome 历史记录',
  otherDevices: '从其他设备打开的标签页',
  clearData: '删除浏览数据',
  open: '打开',
  openNewTab: '在新标签页中打开',
  remove: '从历史记录中删除',
  selected: (count) => `已选择 ${count} 项`,
  closeSelection: '取消选择',
  deleteSelected: '删除',
  empty: '没有找到历史记录',
  emptyOther: '没有其他设备的标签页',
  loading: '正在加载',
  login: '请先连接 Aira 后再查看同步的历史记录',
};

const EN_COPY: ChromeHistoryCopy = {
  title: 'History',
  search: 'Search history',
  history: 'Chrome History',
  otherDevices: 'Tabs from other devices',
  clearData: 'Delete browsing data',
  open: 'Open',
  openNewTab: 'Open in new tab',
  remove: 'Remove from history',
  selected: (count) => count === 1 ? '1 selected' : `${count} selected`,
  closeSelection: 'Clear selection',
  deleteSelected: 'Delete',
  empty: 'No history found',
  emptyOther: 'No tabs from other devices',
  loading: 'Loading',
  login: 'Connect Aira to see synced history',
};

export function chromeHistoryCopy(language: string): ChromeHistoryCopy {
  return language.toLowerCase().startsWith('zh') ? ZH_COPY : EN_COPY;
}

export function chromeHistoryTokens(theme: HistorySkinTheme) {
  return CHROME_HISTORY_SPEC[theme];
}

export function formatChromeHistoryDay(timestamp: number, language: string, now = Date.now()): string {
  const date = new Date(timestamp);
  const day = new Date(date);
  day.setHours(0, 0, 0, 0);
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  const diff = Math.round((today.getTime() - day.getTime()) / 86_400_000);
  const locale = language.toLowerCase().startsWith('zh') ? 'zh-CN' : language || 'en';
  const formatted = new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long',
  }).format(date);
  const prefix = diff === 0
    ? (locale === 'zh-CN' ? '今天' : 'Today')
    : diff === 1
      ? (locale === 'zh-CN' ? '昨天' : 'Yesterday')
      : '';
  return prefix ? `${prefix} - ${formatted}` : formatted;
}

export function formatChromeHistoryTime(timestamp: number, language: string): string {
  const locale = language.toLowerCase().startsWith('zh') ? 'zh-CN' : language || 'en';
  return new Intl.DateTimeFormat(locale, {
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(new Date(timestamp));
}
