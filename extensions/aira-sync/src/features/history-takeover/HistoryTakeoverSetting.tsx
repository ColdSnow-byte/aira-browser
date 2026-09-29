import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { SyncToggleField } from '@/components/sync/SyncSettingsFields';
import {
  HISTORY_TAKEOVER_ENABLED_KEY,
  historyBrowserLabel,
  readInstalledHistoryBrowser,
  type HistoryBrowserKind,
} from './historyTakeoverPolicy';
import {
  readHistoryTakeoverEnabled,
  readHistoryTakeoverEnabledSync,
  writeHistoryTakeoverEnabled,
} from './historyTakeoverPreferences';

export function HistoryTakeoverSetting() {
  const { t } = useTranslation();
  const [enabled, setEnabled] = useState(() => readHistoryTakeoverEnabledSync() === true);
  const [browserKind, setBrowserKind] = useState<HistoryBrowserKind | null>(null);

  useEffect(() => {
    let disposed = false;
    void readHistoryTakeoverEnabled().then((value) => {
      if (!disposed) setEnabled(value);
    });
    const listener = (changes: Record<string, chrome.storage.StorageChange>, areaName: string) => {
      if (areaName !== 'local' || !changes[HISTORY_TAKEOVER_ENABLED_KEY]) return;
      setEnabled(changes[HISTORY_TAKEOVER_ENABLED_KEY].newValue === true);
    };
    globalThis.chrome?.storage?.onChanged?.addListener(listener);
    return () => {
      disposed = true;
      globalThis.chrome?.storage?.onChanged?.removeListener(listener);
    };
  }, []);

  useEffect(() => {
    let disposed = false;
    void readInstalledHistoryBrowser().then((kind) => {
      if (!disposed) setBrowserKind(kind);
    });
    return () => {
      disposed = true;
    };
  }, []);

  return (
    <div className="space-y-2">
      <div className="overflow-hidden rounded-[8px] border border-border bg-card px-3 py-2.5">
        <SyncToggleField
          label={t('historyTakeover.toggle', { defaultValue: '接管浏览器历史页' })}
          checked={enabled}
          onCheckedChange={(value) => {
            setEnabled(value);
            void writeHistoryTakeoverEnabled(value);
          }}
        />
        <p className="mt-2 border-t border-border pt-2 text-xs leading-4 text-muted-foreground">
          {t('historyTakeover.currentBrowser', {
            defaultValue: '当前浏览器：{{browser}}',
            browser: browserKind ? historyBrowserLabel(browserKind) : '…',
          })}
        </p>
      </div>
    </div>
  );
}
