import type { HistoryBrowserKind } from '@/features/history-takeover/historyTakeoverPolicy';

// One browser owns one folder. A skin may render the shared history data, but it
// must not import another browser's layout, copy, or color tokens.
export type HistorySkinId = Extract<HistoryBrowserKind, 'chrome'>;

export type HistorySkinTheme = 'light' | 'dark';
