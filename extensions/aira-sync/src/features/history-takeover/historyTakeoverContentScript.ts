import {
  HISTORY_TAKEOVER_ENABLED_KEY,
  HISTORY_TAKEOVER_OPEN_MESSAGE,
  detectHistoryBrowserKind,
  detectHistoryPlatform,
  isHistoryTakeoverShortcut,
} from './historyTakeoverPolicy';

const browser = detectHistoryBrowserKind(globalThis.navigator?.userAgent || '');
const platform = detectHistoryPlatform(
  globalThis.navigator?.platform || '',
  globalThis.navigator?.userAgent || '',
);
let enabled = false;

function applyStoredValue(value: unknown): void {
  enabled = value === true;
}

function readEnabled(): void {
  const storage = globalThis.chrome?.storage?.local;
  if (!storage?.get) return;
  storage.get(HISTORY_TAKEOVER_ENABLED_KEY, (items) => {
    applyStoredValue(items?.[HISTORY_TAKEOVER_ENABLED_KEY]);
  });
}

readEnabled();
globalThis.chrome?.storage?.onChanged?.addListener((changes, areaName) => {
  if (areaName !== 'local' || !changes[HISTORY_TAKEOVER_ENABLED_KEY]) return;
  applyStoredValue(changes[HISTORY_TAKEOVER_ENABLED_KEY].newValue);
});

globalThis.addEventListener('keydown', (event) => {
  if (!enabled || event.repeat || !isHistoryTakeoverShortcut(browser, platform, event)) return;
  event.preventDefault();
  event.stopPropagation();
  globalThis.chrome?.runtime?.sendMessage({ type: HISTORY_TAKEOVER_OPEN_MESSAGE });
}, true);
