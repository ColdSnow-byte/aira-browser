import {
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

globalThis.addEventListener('keydown', (event) => {
  if (event.repeat || !isHistoryTakeoverShortcut(browser, platform, event)) return;
  event.preventDefault();
  event.stopPropagation();
  globalThis.chrome?.runtime?.sendMessage({ type: HISTORY_TAKEOVER_OPEN_MESSAGE });
}, true);
