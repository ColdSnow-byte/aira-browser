import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { SyncToggleField } from '@/components/sync/SyncSettingsFields';
import { HISTORY_TAKEOVER_ENABLED_KEY } from './historyTakeoverPolicy';
import {
  readHistoryTakeoverEnabled,
  readHistoryTakeoverEnabledSync,
  writeHistoryTakeoverEnabled,
} from './historyTakeoverPreferences';

export function HistoryTakeoverSetting() {
  const { t } = useTranslation();
  const [enabled, setEnabled] = useState(() => readHistoryTakeoverEnabledSync() === true);

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

  return (
    <div className="space-y-2">
      <div className="overflow-hidden rounded-[8px] border border-border bg-card px-3 py-2.5">
        <SyncToggleField
          label={t('historyTakeover.toggle', { defaultValue: '接管浏览器历史页' })}
          description={t('historyTakeover.description', {
            defaultValue: '打开后，历史记录快捷键和历史菜单会进入 Aira 历史记录。',
          })}
          checked={enabled}
          onCheckedChange={(value) => {
            setEnabled(value);
            void writeHistoryTakeoverEnabled(value);
          }}
        />
      </div>
    </div>
  );
}
