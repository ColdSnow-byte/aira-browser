import { useEffect, useState } from 'react';
import { HistoryApp } from '@/features/sync/history/HistoryApp';
import {
  detectHistoryBrowserKind,
  readInstalledHistoryBrowser,
  type HistoryBrowserKind,
} from '@/features/history-takeover/historyTakeoverPolicy';
import { resolveHistorySkin } from './skins/registry';

export function HistorySurface() {
  const [kind, setKind] = useState<HistoryBrowserKind | null>(() => initialHistoryBrowserKind());

  useEffect(() => {
    let disposed = false;
    void readInstalledHistoryBrowser().then((detected) => {
      if (!disposed) setKind(detected);
    });
    return () => {
      disposed = true;
    };
  }, []);

  if (!kind) return null;
  const Skin = resolveHistorySkin(kind);
  if (!Skin) return <HistoryApp />;
  return <Skin />;
}

function initialHistoryBrowserKind(): HistoryBrowserKind | null {
  const userAgent = globalThis.navigator?.userAgent || '';
  const detected = detectHistoryBrowserKind(userAgent);
  // A Chrome-like user agent can still be Brave until its own signal is read.
  return detected === 'chromium' ? null : detected;
}
