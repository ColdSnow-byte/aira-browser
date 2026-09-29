import { useCallback, useDeferredValue, useEffect, useRef, useState } from 'react';
import {
  HISTORY_REVISION_STORAGE_KEY,
  sendHistoryRuntimeMessage,
  type HistoryCapabilityStatus,
} from '@/features/sync/history/historyMessages';
import type { HistorySyncVisit, HistoryTimelinePage } from '@/features/sync/history/HistorySyncModels';

const PAGE_SIZE = 200;

const EMPTY_PAGE: HistoryTimelinePage = {
  visits: [],
  total: 0,
  devices: [],
  lastSyncAt: 0,
  lastError: '',
};

export function useHistorySurfaceData() {
  const [query, setQuery] = useState('');
  const deferredQuery = useDeferredValue(query.trim());
  const [page, setPage] = useState<HistoryTimelinePage>(EMPTY_PAGE);
  const [status, setStatus] = useState<HistoryCapabilityStatus>('temporarily-unavailable');
  const [loading, setLoading] = useState(true);
  const [limit, setLimit] = useState(PAGE_SIZE);
  const requestId = useRef(0);
  const opened = useRef(false);

  const load = useCallback(async (action: 'open' | 'list' = 'list') => {
    const currentRequest = ++requestId.current;
    setLoading(true);
    try {
      const response = await sendHistoryRuntimeMessage({
        action,
        query: deferredQuery,
        limit,
      });
      if (currentRequest !== requestId.current) return;
      if (response.page) setPage(response.page);
      setStatus(response.status);
    } catch {
      if (currentRequest === requestId.current) setStatus('temporarily-unavailable');
    } finally {
      if (currentRequest === requestId.current) setLoading(false);
    }
  }, [deferredQuery, limit]);

  useEffect(() => {
    if (!opened.current) {
      opened.current = true;
      void load('open');
      return;
    }
    void load('list');
  }, [load]);

  useEffect(() => {
    const listener = (changes: Record<string, chrome.storage.StorageChange>, areaName: string) => {
      if (areaName === 'local' && changes[HISTORY_REVISION_STORAGE_KEY]) void load('list');
    };
    globalThis.chrome?.storage?.onChanged?.addListener?.(listener);
    return () => globalThis.chrome?.storage?.onChanged?.removeListener?.(listener);
  }, [load]);

  const deleteVisit = useCallback(async (visitId: string) => {
    const response = await sendHistoryRuntimeMessage({
      action: 'delete',
      visitId,
      query: deferredQuery,
      limit,
    });
    if (response.page) setPage(response.page);
    setStatus(response.status);
    return response.success;
  }, [deferredQuery, limit]);

  return {
    query,
    setQuery,
    visits: page.visits,
    total: page.total,
    loading,
    status,
    hasMore: page.visits.length < page.total,
    loadMore: () => setLimit((current) => current + PAGE_SIZE),
    deleteVisit,
  };
}

export function historyHostname(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
}

export function historyFaviconUrl(pageUrl: string): string {
  const runtime = globalThis.chrome?.runtime;
  if (!runtime?.getURL || !pageUrl) return '';
  return `${runtime.getURL('_favicon/')}?pageUrl=${encodeURIComponent(pageUrl)}&size=32`;
}

export type { HistorySyncVisit };
