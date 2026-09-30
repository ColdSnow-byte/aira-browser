export type EdgeHistoryTheme = 'light' | 'dark';
export type EdgeHistorySection = 'all' | 'closed' | 'devices';

export type EdgeHistoryCopy = {
  title: string;
  searchHistory: string;
  searchClosed: string;
  searchDevices: string;
  all: string;
  closed: string;
  devices: string;
  openTab: string;
  openWindow: string;
  openPrivate: string;
  copyLink: string;
  remove: string;
  clearData: string;
  more: string;
  pin: string;
  unpin: string;
  openHistoryPage: string;
  exportData: string;
  showDuplicates: string;
  moreFromSite: string;
  empty: string;
  emptyClosed: string;
  emptyDevices: string;
  loading: string;
  login: string;
  andMore: (count: number) => string;
  reopenHint: string;
};

const ZH: EdgeHistoryCopy = {
  title: '历史记录',
  searchHistory: '搜索 历史记录',
  searchClosed: '搜索 最近关闭',
  searchDevices: '搜索 来自其他设备的标签页',
  all: '全部',
  closed: '最近关闭',
  devices: '来自其他设备的标签页',
  openTab: '在新标签页中打开',
  openWindow: '在新窗口中打开',
  openPrivate: '在新建 InPrivate 窗口中打开',
  copyLink: '复制链接',
  remove: '删除',
  clearData: '删除浏览数据',
  more: '更多选项',
  pin: '固定历史记录',
  unpin: '取消固定',
  openHistoryPage: '打开历史记录页面',
  exportData: '导出浏览数据',
  showDuplicates: '显示重复页',
  moreFromSite: '来自相同站点的更多内容',
  empty: '没有历史记录',
  emptyClosed: '没有最近关闭的标签页',
  emptyDevices: '没有来自其他设备的标签页',
  loading: '正在加载',
  login: '请先连接后再查看同步的历史记录',
  andMore: (count) => `和另外 ${count} 个标签页`,
  reopenHint: 'Ctrl+Shift+T',
};

const EN: EdgeHistoryCopy = {
  title: 'History',
  searchHistory: 'Search history',
  searchClosed: 'Search recently closed',
  searchDevices: 'Search tabs from other devices',
  all: 'All',
  closed: 'Recently closed',
  devices: 'Tabs from other devices',
  openTab: 'Open in new tab',
  openWindow: 'Open in new window',
  openPrivate: 'Open in new InPrivate window',
  copyLink: 'Copy link',
  remove: 'Delete',
  clearData: 'Delete browsing data',
  more: 'More options',
  pin: 'Pin history',
  unpin: 'Unpin',
  openHistoryPage: 'Open history page',
  exportData: 'Export browsing data',
  showDuplicates: 'Show duplicate pages',
  moreFromSite: 'More from this site',
  empty: 'No history',
  emptyClosed: 'No recently closed tabs',
  emptyDevices: 'No tabs from other devices',
  loading: 'Loading',
  login: 'Connect to see synced history',
  andMore: (count) => `and ${count} more tabs`,
  reopenHint: 'Ctrl+Shift+T',
};

export function edgeHistoryCopy(language: string, platform = ''): EdgeHistoryCopy {
  const copy = language.toLowerCase().startsWith('zh') ? ZH : EN;
  const mac = /mac/i.test(platform);
  return {
    ...copy,
    reopenHint: mac ? '⌘⇧T' : copy.reopenHint,
  };
}

export function edgeHistorySearchPlaceholder(section: EdgeHistorySection, copy: EdgeHistoryCopy): string {
  if (section === 'closed') return copy.searchClosed;
  if (section === 'devices') return copy.searchDevices;
  return copy.searchHistory;
}
