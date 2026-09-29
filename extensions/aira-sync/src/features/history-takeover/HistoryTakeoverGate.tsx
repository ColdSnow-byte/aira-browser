import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { HistoryApp } from '@/features/sync/history/HistoryApp';
import { HISTORY_TAKEOVER_ENABLED_KEY } from './historyTakeoverPolicy';
import {
  readHistoryTakeoverEnabled,
  readHistoryTakeoverEnabledSync,
  writeHistoryTakeoverEnabled,
} from './historyTakeoverPreferences';

export function HistoryTakeoverGate() {
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

  useEffect(() => {
    document.title = enabled
      ? t('historyTakeover.pageTitle', { defaultValue: '历史记录' })
      : t('historyTakeover.offTitle', { defaultValue: '历史页接管未开启' });
  }, [enabled, t]);

  if (enabled) return <HistoryApp />;

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-6 text-foreground">
      <div className="w-full max-w-md space-y-4">
        <h1 className="text-lg font-semibold leading-7">
          {t('historyTakeover.offTitle', { defaultValue: '历史页接管未开启' })}
        </h1>
        <p className="text-sm leading-6 text-muted-foreground">
          {t('historyTakeover.offBody', {
            defaultValue: '这个浏览器已经把历史记录页交给了 Aira-sync，关闭开关也无法恢复原来的历史页。打开接管后，历史快捷键和历史菜单都会进入 Aira 历史记录。',
          })}
        </p>
        <Button
          type="button"
          className="h-10 rounded-[8px]"
          onClick={() => {
            setEnabled(true);
            void writeHistoryTakeoverEnabled(true);
          }}
        >
          {t('historyTakeover.enableAction', { defaultValue: '开启接管' })}
        </Button>
      </div>
    </main>
  );
}
