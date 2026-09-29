export const HISTORY_TAKEOVER_ENABLED_KEY = 'aira_history_takeover_enabled_v1';
export const HISTORY_TAKEOVER_OPEN_MESSAGE = 'AIRA_HISTORY_TAKEOVER_OPEN';

export type HistoryBrowserKind = 'firefox' | 'opera' | 'vivaldi' | 'edge' | 'brave' | 'chrome' | 'chromium';
export type HistoryPlatform = 'mac' | 'other';

export type HistoryBrowserSignals = {
  userAgent?: string;
  brands?: readonly string[];
  isBrave?: boolean;
};

export type HistoryShortcutEvent = {
  key?: string;
  code?: string;
  ctrlKey: boolean;
  metaKey: boolean;
  altKey: boolean;
  shiftKey: boolean;
};

export function detectHistoryBrowserKind(userAgent: string): HistoryBrowserKind {
  return resolveHistoryBrowserKind({ userAgent });
}

export function resolveHistoryBrowserKind(signals: HistoryBrowserSignals = {}): HistoryBrowserKind {
  const ua = signals.userAgent || '';
  const brands = (signals.brands || []).map((brand) => brand.toLowerCase());
  const hasBrand = (name: string) => brands.some((brand) => brand.includes(name));

  if (signals.isBrave === true || hasBrand('brave')) return 'brave';
  if (/Firefox\//i.test(ua)) return 'firefox';
  if (/OPR\/|Opera\//i.test(ua) || hasBrand('opera')) return 'opera';
  if (/Vivaldi\//i.test(ua) || hasBrand('vivaldi')) return 'vivaldi';
  if (/Edg\//i.test(ua) || hasBrand('microsoft edge')) return 'edge';
  if (hasBrand('google chrome')) return 'chrome';
  if (/Chrome\//i.test(ua) && signals.isBrave === false) return 'chrome';
  return 'chromium';
}

export function historyBrowserLabel(kind: HistoryBrowserKind): string {
  switch (kind) {
    case 'firefox': return 'Firefox';
    case 'opera': return 'Opera';
    case 'vivaldi': return 'Vivaldi';
    case 'edge': return 'Edge';
    case 'brave': return 'Brave';
    case 'chrome': return 'Chrome';
    default: return 'Chromium';
  }
}

type HistoryBrowserNavigator = {
  userAgent?: string;
  brave?: { isBrave?: () => Promise<boolean> };
  userAgentData?: { brands?: Array<{ brand?: string }> };
};

export async function readInstalledHistoryBrowser(
  navigatorObject: HistoryBrowserNavigator | null = globalThis.navigator ?? null,
): Promise<HistoryBrowserKind> {
  let isBrave = false;
  try {
    if (typeof navigatorObject?.brave?.isBrave === 'function') {
      isBrave = await navigatorObject.brave.isBrave() === true;
    }
  } catch {
    isBrave = false;
  }
  const brands = navigatorObject?.userAgentData?.brands
    ?.map((item) => String(item?.brand || '').trim())
    .filter(Boolean) || [];
  return resolveHistoryBrowserKind({
    userAgent: navigatorObject?.userAgent || '',
    brands,
    isBrave,
  });
}

export function detectHistoryPlatform(platform: string, userAgent = ''): HistoryPlatform {
  return /Mac|iPhone|iPad|iPod/i.test(`${platform} ${userAgent}`) ? 'mac' : 'other';
}

function matchesLetter(event: HistoryShortcutEvent, letter: string): boolean {
  const code = String(event.code || '');
  if (code) return code === `Key${letter.toUpperCase()}`;
  return String(event.key || '').toLowerCase() === letter.toLowerCase();
}

function hasPrimaryModifier(platform: HistoryPlatform, event: HistoryShortcutEvent): boolean {
  if (event.altKey) return false;
  if (platform === 'mac') return event.metaKey && !event.ctrlKey;
  return event.ctrlKey && !event.metaKey;
}

// Page override already owns the history command on Chromium browsers that honor
// chrome_url_overrides. Only intercept shortcuts the override cannot see.
export function isHistoryTakeoverShortcut(
  browser: HistoryBrowserKind,
  platform: HistoryPlatform,
  event: HistoryShortcutEvent,
): boolean {
  if (!hasPrimaryModifier(platform, event)) return false;

  // Edge on Windows/Linux: the requested history shortcut is Ctrl+Y. Ctrl+H is
  // already covered by the history page override, so stealing it would also
  // fight Redo on other Chromium browsers. Mac Edge uses Command+Y, which the
  // page override receives.
  if (browser === 'edge') {
    return platform !== 'mac' && matchesLetter(event, 'y') && !event.shiftKey;
  }

  if (browser === 'chromium' || browser === 'chrome' || browser === 'brave') return false;

  if (browser === 'opera') {
    if (!matchesLetter(event, 'h')) return false;
    return platform === 'mac' ? event.shiftKey : !event.shiftKey;
  }

  if (browser === 'firefox') {
    if (!matchesLetter(event, 'h')) return false;
    return platform === 'mac' ? event.shiftKey : true;
  }

  if (!matchesLetter(event, 'h') && !(platform === 'mac' && matchesLetter(event, 'y') && !event.shiftKey)) {
    return false;
  }
  return true;
}

export function isNativeHistoryPageUrl(url: string): boolean {
  const value = String(url || '').trim();
  if (!value) return false;
  return /^(?:chrome|edge|brave|opera|vivaldi|whale|yandex):\/\/history(?:\/|$|\?|#)/i.test(value)
    || /^about:history(?:$|\?|#)/i.test(value);
}
