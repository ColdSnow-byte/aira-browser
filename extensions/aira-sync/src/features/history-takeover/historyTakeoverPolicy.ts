export const HISTORY_TAKEOVER_OPEN_MESSAGE = 'AIRA_HISTORY_TAKEOVER_OPEN';

export type HistoryBrowserKind = 'zen' | 'floorp' | 'librewolf' | 'waterfox' | 'firefox' | 'opera' | 'vivaldi' | 'edge' | 'brave' | 'chrome' | 'chromium';
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
  // These Gecko forks still contain Firefox/ in the user agent.
  if (/Zen\//i.test(ua)) return 'zen';
  if (/Waterfox\//i.test(ua)) return 'waterfox';
  if (/LibreWolf\//i.test(ua)) return 'librewolf';
  if (/Floorp\//i.test(ua)) return 'floorp';
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
    case 'zen': return 'Zen';
    case 'floorp': return 'Floorp';
    case 'librewolf': return 'LibreWolf';
    case 'waterfox': return 'Waterfox';
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

type GeckoBrowserInfo = {
  name?: string;
  vendor?: string;
};

type GeckoBrowserRuntime = {
  getBrowserInfo?: () => Promise<GeckoBrowserInfo>;
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
  const detected = resolveHistoryBrowserKind({
    userAgent: navigatorObject?.userAgent || '',
    brands,
    isBrave,
  });
  const browserName = await readGeckoBrowserName();
  return kindFromGeckoBrowserName(browserName) ?? detected;
}

function kindFromGeckoBrowserName(name: string): HistoryBrowserKind | null {
  if (/zen/i.test(name)) return 'zen';
  if (/floorp/i.test(name)) return 'floorp';
  if (/librewolf/i.test(name)) return 'librewolf';
  if (/waterfox/i.test(name)) return 'waterfox';
  return null;
}

async function readGeckoBrowserName(): Promise<string> {
  const runtimeScopes = globalThis as typeof globalThis & {
    browser?: { runtime?: GeckoBrowserRuntime };
    chrome?: { runtime?: GeckoBrowserRuntime };
  };
  const scopes = [runtimeScopes.browser, runtimeScopes.chrome];
  for (const scope of scopes) {
    if (typeof scope?.runtime?.getBrowserInfo !== 'function') continue;
    try {
      const info = await scope.runtime.getBrowserInfo();
      return `${info?.name || ''} ${info?.vendor || ''}`.trim();
    } catch {
      return '';
    }
  }
  return '';
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

  if (browser === 'firefox' || browser === 'zen' || browser === 'floorp' || browser === 'librewolf' || browser === 'waterfox') {
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
