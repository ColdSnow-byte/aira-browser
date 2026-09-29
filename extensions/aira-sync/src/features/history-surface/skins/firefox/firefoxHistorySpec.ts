export type FirefoxHistoryFolder = 'all' | 'today' | 'yesterday' | 'week' | 'month';

export type FirefoxHistoryCopy = {
  title: string;
  history: string;
  today: string;
  yesterday: string;
  week: string;
  month: string;
  all: string;
  search: string;
  organize: string;
  delete: string;
  name: string;
  url: string;
  date: string;
  open: string;
  openTab: string;
  copy: string;
  empty: string;
  loading: string;
  back: string;
  forward: string;
};

const ZH: FirefoxHistoryCopy = {
  title: '我的足迹',
  history: '历史记录',
  today: '今天',
  yesterday: '昨天',
  week: '最近 7 天',
  month: '本月',
  all: '全部',
  search: '搜索历史记录',
  organize: '管理',
  delete: '删除',
  name: '名称',
  url: '网址',
  date: '上次访问',
  open: '打开',
  openTab: '在新标签页中打开',
  copy: '复制',
  empty: '此文件夹为空',
  loading: '正在加载',
  back: '后退',
  forward: '前进',
};

const EN: FirefoxHistoryCopy = {
  title: 'Library',
  history: 'History',
  today: 'Today',
  yesterday: 'Yesterday',
  week: 'Last 7 days',
  month: 'This month',
  all: 'All',
  search: 'Search History',
  organize: 'Organize',
  delete: 'Delete',
  name: 'Name',
  url: 'Location',
  date: 'Most Recent Visit',
  open: 'Open',
  openTab: 'Open in New Tab',
  copy: 'Copy',
  empty: 'This folder is empty',
  loading: 'Loading',
  back: 'Back',
  forward: 'Forward',
};

export function firefoxHistoryCopy(language: string): FirefoxHistoryCopy {
  return language.toLowerCase().startsWith('zh') ? ZH : EN;
}

export function firefoxFolderLabel(folder: FirefoxHistoryFolder, copy: FirefoxHistoryCopy): string {
  if (folder === 'today') return copy.today;
  if (folder === 'yesterday') return copy.yesterday;
  if (folder === 'week') return copy.week;
  if (folder === 'month') return copy.month;
  return copy.all;
}
