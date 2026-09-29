import type { ComponentType } from 'react';
import type { HistoryBrowserKind } from '@/features/history-takeover/historyTakeoverPolicy';
import { ChromeHistoryPage } from './chrome/ChromeHistoryPage';
import { EdgeHistoryPage } from './edge/EdgeHistoryPage';

// Add a browser by dropping its page into its own folder and registering it here.
// Browsers without a skin keep the existing Aira history page.
const HISTORY_SKINS: Partial<Record<HistoryBrowserKind, ComponentType>> = {
  chrome: ChromeHistoryPage,
  edge: EdgeHistoryPage,
};

export function resolveHistorySkin(kind: HistoryBrowserKind): ComponentType | null {
  return HISTORY_SKINS[kind] ?? null;
}
