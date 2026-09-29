import { HISTORY_TAKEOVER_OPEN_MESSAGE } from './historyTakeoverPolicy';

type HistoryTakeoverOpenMessage = {
  type?: unknown;
};

function isHistoryTakeoverOpenMessage(message: unknown): message is { type: typeof HISTORY_TAKEOVER_OPEN_MESSAGE } {
  return Boolean(message)
    && typeof message === 'object'
    && (message as HistoryTakeoverOpenMessage).type === HISTORY_TAKEOVER_OPEN_MESSAGE;
}

async function openOrFocusHistoryPage(): Promise<void> {
  const runtime = globalThis.chrome?.runtime;
  const tabs = globalThis.chrome?.tabs;
  const windows = globalThis.chrome?.windows;
  const historyUrl = runtime?.getURL?.('history.html');
  if (!historyUrl || !tabs?.create) return;

  try {
    const existing = tabs.query ? await tabs.query({ url: `${historyUrl}*` }) : [];
    const tab = existing.find((item) => typeof item.id === 'number');
    if (tab?.id != null) {
      await tabs.update(tab.id, { active: true });
      if (windows?.update && typeof tab.windowId === 'number') {
        await windows.update(tab.windowId, { focused: true });
      }
      return;
    }
  } catch {
    // Querying by extension URL can fail; creating a tab is the fallback.
  }

  await tabs.create({ url: historyUrl, active: true }).catch(() => undefined);
}

export function bindHistoryTakeoverRuntime(): void {
  globalThis.chrome?.runtime?.onMessage?.addListener((message, _sender, sendResponse) => {
    if (!isHistoryTakeoverOpenMessage(message)) return undefined;
    void openOrFocusHistoryPage();
    sendResponse?.({ ok: true });
    return false;
  });
}
