export const EDGE_HISTORY_DOCK_OPEN = 'AIRA_EDGE_HISTORY_DOCK_OPEN';
export const EDGE_HISTORY_DOCK_CLOSE = 'AIRA_EDGE_HISTORY_DOCK_CLOSE';

const DOCK_PATH = 'history-override.html?dock=1';

type DockMessage = {
  type?: string;
  windowId?: number;
};

let cachedWindowId: number | undefined;

export function rememberEdgeHistoryWindow(): void {
  globalThis.chrome?.windows?.getCurrent((win) => {
    if (typeof win?.id === 'number') cachedWindowId = win.id;
  });
}

export function requestEdgeHistoryDock(docked: boolean): void {
  const runtime = globalThis.chrome?.runtime;
  const sidePanel = globalThis.chrome?.sidePanel;
  if (!docked) {
    if (typeof cachedWindowId === 'number' && sidePanel?.open) {
      void sidePanel.setOptions({ path: DOCK_PATH, enabled: true });
      void sidePanel.open({ windowId: cachedWindowId });
    } else {
      runtime?.sendMessage({ type: EDGE_HISTORY_DOCK_OPEN });
    }
    if (window.history.length > 1) window.history.back();
    return;
  }
  const closeDock = (windowId: number | undefined) => {
    if (typeof windowId === 'number' && sidePanel?.close) {
      void sidePanel.close({ windowId });
      return;
    }
    runtime?.sendMessage({ type: EDGE_HISTORY_DOCK_CLOSE, windowId });
  };
  if (typeof cachedWindowId === 'number') closeDock(cachedWindowId);
  else globalThis.chrome?.windows?.getCurrent((win) => closeDock(win?.id));
}

export function bindEdgeHistoryDockRuntime(): void {
  const chromeApi = globalThis.chrome;
  chromeApi?.runtime?.onInstalled?.addListener(() => {
    void chromeApi.sidePanel?.setOptions({ path: DOCK_PATH, enabled: true });
    void chromeApi.sidePanel?.setPanelBehavior({ openPanelOnActionClick: false });
  });
  void chromeApi?.sidePanel?.setOptions({ path: DOCK_PATH, enabled: true });
  void chromeApi?.sidePanel?.setPanelBehavior({ openPanelOnActionClick: false });

  chromeApi?.runtime?.onMessage?.addListener((message, sender) => {
    const request = message as DockMessage;
    const windowId = typeof request?.windowId === 'number' ? request.windowId : sender.tab?.windowId;
    if (typeof windowId !== 'number' || !chromeApi.sidePanel) return;
    if (request.type === EDGE_HISTORY_DOCK_OPEN) {
      void chromeApi.sidePanel.open({ windowId });
      return;
    }
    if (request.type !== EDGE_HISTORY_DOCK_CLOSE) return;
    if (chromeApi.sidePanel.close) {
      void chromeApi.sidePanel.close({ windowId });
      return;
    }
    void chromeApi.sidePanel.setOptions({ enabled: false });
  });
}
