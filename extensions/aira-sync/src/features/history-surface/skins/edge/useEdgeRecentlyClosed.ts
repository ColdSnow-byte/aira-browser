import { useEffect, useState } from 'react';

export type EdgeClosedTab = {
  sessionId: string;
  title: string;
  url: string;
};

export type EdgeClosedEntry = {
  id: string;
  sessionId: string;
  title: string;
  url: string;
  lastModified: number;
  tabs: EdgeClosedTab[];
};

type SessionTab = {
  sessionId?: string;
  title?: string;
  url?: string;
  pendingUrl?: string;
};

type ClosedSession = {
  lastModified?: number;
  tab?: SessionTab;
  window?: {
    sessionId?: string;
    tabs?: SessionTab[];
  };
};

export function useEdgeRecentlyClosed(active: boolean) {
  const [entries, setEntries] = useState<EdgeClosedEntry[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!active) return undefined;
    const sessions = globalThis.chrome?.sessions;
    if (!sessions?.getRecentlyClosed) {
      setEntries([]);
      return undefined;
    }
    let disposed = false;
    setLoading(true);
    const finish = (result: EdgeClosedEntry[]) => {
      if (disposed) return;
      setEntries(result);
      setLoading(false);
    };
    const handle = (sessionsResult?: ClosedSession[]) => {
      finish((sessionsResult || []).map(toClosedEntry).filter((entry): entry is EdgeClosedEntry => entry !== null));
    };
    try {
      sessions.getRecentlyClosed({ maxResults: 25 }, handle);
    } catch {
      finish([]);
    }
    return () => {
      disposed = true;
    };
  }, [active]);

  return { entries, loading };
}

function toClosedEntry(session: ClosedSession, index: number): EdgeClosedEntry | null {
  const lastModified = Number(session.lastModified || 0);
  const windowTabs = (session.window?.tabs || [])
    .map(toClosedTab)
    .filter((tab): tab is EdgeClosedTab => tab !== null);
  if (windowTabs.length > 1) {
    const first = windowTabs[0];
    return {
      id: session.window?.sessionId || `window-${index}`,
      sessionId: session.window?.sessionId || first.sessionId,
      title: first.title,
      url: first.url,
      lastModified,
      tabs: windowTabs,
    };
  }
  const tab = windowTabs[0] || toClosedTab(session.tab || {});
  if (!tab) return null;
  return {
    id: tab.sessionId || `tab-${index}`,
    sessionId: tab.sessionId,
    title: tab.title,
    url: tab.url,
    lastModified,
    tabs: [],
  };
}

function toClosedTab(tab: SessionTab): EdgeClosedTab | null {
  const url = String(tab.url || tab.pendingUrl || '').trim();
  const sessionId = String(tab.sessionId || '').trim();
  if (!url) return null;
  return {
    sessionId,
    title: String(tab.title || '').trim() || url,
    url,
  };
}

export function restoreEdgeSession(sessionId: string, fallbackUrl = ''): void {
  const sessions = globalThis.chrome?.sessions;
  if (sessionId && sessions?.restore) {
    void Promise.resolve(sessions.restore(sessionId)).catch(() => openFallback(fallbackUrl));
    return;
  }
  openFallback(fallbackUrl);
}

function openFallback(url: string): void {
  if (!url) return;
  if (globalThis.chrome?.tabs?.create) void globalThis.chrome.tabs.create({ url, active: true });
}
