/**
 * System homepage frame.
 * `classic` is the original home.
 * `centered` (简约主页) adds the wordmark and search field, and draws shortcuts smaller and circular.
 * `minimal` (极简主页) keeps that wordmark and search field, and leaves the shortcut grid off.
 * Toolbar chrome follows the frame: classic floats, and the other two split.
 */
export type BrowserHomePageStyle = 'classic' | 'centered' | 'minimal';

export function readBrowserHomePageStyle(value: string | undefined): BrowserHomePageStyle | undefined {
  if (value === 'classic') {
    return 'classic';
  }
  if (value === 'centered') {
    return 'centered';
  }
  if (value === 'minimal') {
    return 'minimal';
  }
  return undefined;
}

export function normalizeBrowserHomePageStyle(value: string | undefined): BrowserHomePageStyle {
  return readBrowserHomePageStyle(value) ?? 'classic';
}

/** Wordmark and search field, with the shortcut grid only on `centered`. */
export function usesCenteredHomeFrame(style: BrowserHomePageStyle): boolean {
  return style === 'centered' || style === 'minimal';
}

export interface HomePagePresentationSettings {
  showFavoritesTitle: boolean;
  showShortcutNames: boolean;
  showRecentlyClosedTitle: boolean;
  showSettingsButton: boolean;
  /**
   * Built-in homepage frame. Synced with the other core preferences.
   */
  homePageStyle: BrowserHomePageStyle;
}
