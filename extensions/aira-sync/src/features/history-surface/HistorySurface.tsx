import { useEffect, useState } from 'react';
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
  return <Skin />;
}

function initialHistoryBrowserKind(): HistoryBrowserKind | null {
  const userAgent = globalThis.navigator?.userAgent || '';
  const detected = detectHistoryBrowserKind(userAgent);
  // Chrome-like and Firefox-like user agents can still be Brave or Zen until
  // their own browser signal is read.
  return detected === 'chromium' || detected === 'firefox' ? null : detected;
}
