export type ZenHistoryWhen = 'today' | 'week' | 'month';
export type ZenHistorySort = 'date' | 'site' | 'mostvisited' | 'lastvisited';

export type ZenHistoryCopy = {
  title: string;
  history: string;
  downloads: string;
  boosts: string;
  spaces: string;
  media: string;
  search: string;
  filter: string;
  filterTitle: string;
  done: string;
  when: string;
  today: string;
  week: string;
  month: string;
  sort: string;
  byDate: string;
  bySite: string;
  mostVisited: string;
  lastVisited: string;
  other: string;
  empty: string;
  loading: string;
  remove: string;
  reopen: string;
};

const ZH: ZenHistoryCopy = {
  title: '历史记录',
  history: '历史记录',
  downloads: '下载',
  boosts: '增强',
  spaces: '空间',
  media: '媒体',
  search: '搜索历史记录…',
  filter: '筛选',
  filterTitle: '筛选历史记录…',
  done: '完成',
  when: '何时访问？',
  today: '今天',
  week: '本周',
  month: '本月',
  sort: '排序方式',
  byDate: '按日期',
  bySite: '按网站',
  mostVisited: '按访问次数',
  lastVisited: '按上次访问',
  other: '其他',
  empty: '没有找到历史记录',
  loading: '正在加载',
  remove: '从历史记录中移除',
  reopen: '重新打开页面',
};

const EN: ZenHistoryCopy = {
  title: 'History',
  history: 'History',
  downloads: 'Downloads',
  boosts: 'Boosts',
  spaces: 'Spaces',
  media: 'Media',
  search: 'Search History…',
  filter: 'Filter',
  filterTitle: 'Filter History…',
  done: 'Done',
  when: 'When was it visited?',
  today: 'Today',
  week: 'This Week',
  month: 'This Month',
  sort: 'Sort by',
  byDate: 'By Date',
  bySite: 'By Site',
  mostVisited: 'By Most Visited',
  lastVisited: 'By Last Visited',
  other: 'Other',
  empty: 'No history found',
  loading: 'Loading',
  remove: 'Remove from history',
  reopen: 'Reopen page',
};

export function zenHistoryCopy(language: string): ZenHistoryCopy {
  return language.toLowerCase().startsWith('zh') ? ZH : EN;
}

export function zenDisplayUrl(url: string): string {
  return url.replace(/^https?:\/\/(www\.)?/, '').replace(/\/$/, '');
}
