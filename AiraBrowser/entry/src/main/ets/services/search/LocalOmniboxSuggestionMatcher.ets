import {
  BookmarkNode,
  BookmarkStorageScope,
  BrowserDataScope,
  BrowserProfileId,
  BrowserSessionPrivacyMode,
  SearchSuggestion
} from '../../common/models/BrowserModels';
import { isUserSearchableBookmark } from '../../data/repositories/BookmarkRepositoryCore';
import { BrowserTabState } from '../../core/tabs/TabManager';

export const OMNIBOX_BOOKMARK_VISIBLE_LIMIT: number = 2;
export const OMNIBOX_TAB_VISIBLE_LIMIT: number = 1;

export interface OpenTabSuggestionQuery {
  query: string;
  activeTabId: string;
  privacyMode: BrowserSessionPrivacyMode;
  dataScope: BrowserDataScope;
  profileId?: BrowserProfileId;
  limit: number;
}

interface RankedLocalSuggestion {
  suggestion: SearchSuggestion;
  score: number;
}

/**
 * Ranks bookmarks and open tabs already held in memory. Address-bar keystrokes
 * must not copy or scan the bookmark database; the repository cache is enough
 * for a few thousand bookmarks.
 */
export function matchBookmarkSuggestions(
  bookmarks: BookmarkNode[],
  query: string,
  limit: number
): SearchSuggestion[] {
  const normalizedLimit = Math.max(0, Math.floor(limit));
  const normalizedQuery = normalizeLocalOmniboxQuery(query);
  if (normalizedLimit === 0 || normalizedQuery.length === 0) {
    return [];
  }
  const ranked: RankedLocalSuggestion[] = [];
  const seenUrls: Set<string> = new Set<string>();
  for (let index = 0; index < bookmarks.length; index += 1) {
    const bookmark = bookmarks[index];
    if (!isUserSearchableBookmark(bookmark)) {
      continue;
    }
    const url = (bookmark.url ?? '').trim();
    const urlKey = normalizeLocalOmniboxQuery(url);
    if (url.length === 0 || seenUrls.has(urlKey)) {
      continue;
    }
    const title = bookmark.title.trim();
    const host = hostFromLocalOmniboxUrl(url);
    const score = scoreLocalOmniboxText(normalizedQuery, title, host, url);
    if (score <= 0) {
      continue;
    }
    seenUrls.add(urlKey);
    considerLocalSuggestion(ranked, {
      suggestion: {
        id: `bookmark-suggestion-${bookmark.id}`,
        title: displayLocalOmniboxTitle(title, host),
        source: 'bookmarks',
        target: url,
        subtitle: host,
        icon: '',
        refId: bookmark.id,
        score: score
      },
      score: score
    }, normalizedLimit);
  }
  return ranked.map((item: RankedLocalSuggestion): SearchSuggestion => item.suggestion);
}

export function matchOpenTabSuggestions(
  tabs: BrowserTabState[],
  input: OpenTabSuggestionQuery
): SearchSuggestion[] {
  const normalizedLimit = Math.max(0, Math.floor(input.limit));
  const normalizedQuery = normalizeLocalOmniboxQuery(input.query);
  if (normalizedLimit === 0 || normalizedQuery.length === 0) {
    return [];
  }
  const ranked: RankedLocalSuggestion[] = [];
  for (let index = 0; index < tabs.length; index += 1) {
    const tab = tabs[index];
    if (!isSuggestableOpenTab(tab, input)) {
      continue;
    }
    const url = resolveOpenTabUrl(tab);
    const title = tab.title.trim().length > 0 ? tab.title.trim() : tab.lastGoodTitle.trim();
    const host = hostFromLocalOmniboxUrl(url);
    const textScore = scoreLocalOmniboxText(normalizedQuery, title, host, url);
    if (textScore <= 0) {
      continue;
    }
    const ageHours = Math.max(0, (Date.now() - tab.lastActiveAt) / 3600000);
    const score = textScore + Math.max(0, 40 - Math.floor(ageHours));
    considerLocalSuggestion(ranked, {
      suggestion: {
        id: `tab-suggestion-${tab.id}`,
        title: displayLocalOmniboxTitle(title, host),
        source: 'tabs',
        target: url,
        subtitle: host,
        icon: '',
        refId: tab.id,
        score: score
      },
      score: score
    }, normalizedLimit);
  }
  return ranked.map((item: RankedLocalSuggestion): SearchSuggestion => item.suggestion);
}

export function resolveBookmarkSuggestionScope(
  privacyMode: BrowserSessionPrivacyMode,
  dataScope: BrowserDataScope
): BookmarkStorageScope {
  return privacyMode === 'private' || dataScope === 'session_ephemeral' ? 'private' : 'regular';
}

function isSuggestableOpenTab(tab: BrowserTabState, input: OpenTabSuggestionQuery): boolean {
  if (tab.id === input.activeTabId || tab.isHome) {
    return false;
  }
  if (tab.privacyMode !== input.privacyMode || tab.dataScope !== input.dataScope) {
    return false;
  }
  if (input.profileId !== undefined && tab.profileId !== input.profileId) {
    return false;
  }
  const url = resolveOpenTabUrl(tab).toLowerCase();
  return url.length > 0 && url !== 'about:blank' && !url.startsWith('aira:');
}

function resolveOpenTabUrl(tab: BrowserTabState): string {
  const url = tab.url.trim();
  if (url.length > 0) {
    return url;
  }
  const pending = tab.pendingUrl.trim();
  if (pending.length > 0) {
    return pending;
  }
  return tab.lastGoodUrl.trim();
}

function considerLocalSuggestion(
  ranked: RankedLocalSuggestion[],
  candidate: RankedLocalSuggestion,
  limit: number
): void {
  if (ranked.length < limit) {
    ranked.push(candidate);
    ranked.sort(compareLocalSuggestions);
    return;
  }
  if (candidate.score <= ranked[ranked.length - 1].score) {
    return;
  }
  ranked[ranked.length - 1] = candidate;
  ranked.sort(compareLocalSuggestions);
}

function compareLocalSuggestions(left: RankedLocalSuggestion, right: RankedLocalSuggestion): number {
  return right.score - left.score;
}

function scoreLocalOmniboxText(query: string, title: string, host: string, url: string): number {
  const normalizedTitle = title.trim().toLowerCase();
  const normalizedHost = host.trim().toLowerCase();
  const compactUrl = normalizeLocalOmniboxQuery(url);
  if (normalizedHost === query || compactUrl === query || normalizedTitle === query) {
    return 800;
  }
  if (normalizedHost.startsWith(query) || normalizedTitle.startsWith(query) || compactUrl.startsWith(query)) {
    return 600;
  }
  if (normalizedTitle.indexOf(query) >= 0 || normalizedHost.indexOf(query) >= 0 || compactUrl.indexOf(query) >= 0) {
    return 300;
  }
  return 0;
}

function displayLocalOmniboxTitle(title: string, host: string): string {
  const trimmedTitle = title.trim();
  if (trimmedTitle.length > 0) {
    return trimmedTitle;
  }
  return host.length > 0 ? host : '';
}

function normalizeLocalOmniboxQuery(value: string): string {
  let compact = value.trim().toLowerCase().replace(/\s+/g, '');
  if (compact.startsWith('https://')) {
    compact = compact.substring('https://'.length);
  } else if (compact.startsWith('http://')) {
    compact = compact.substring('http://'.length);
  }
  if (compact.startsWith('www.')) {
    compact = compact.substring('www.'.length);
  }
  if (compact.endsWith('/') && compact.indexOf('?') < 0 && compact.indexOf('#') < 0) {
    compact = compact.substring(0, compact.length - 1);
  }
  return compact;
}

function hostFromLocalOmniboxUrl(url: string): string {
  const compact = normalizeLocalOmniboxQuery(url);
  const slash = compact.indexOf('/');
  const hostWithPort = slash < 0 ? compact : compact.substring(0, slash);
  const port = hostWithPort.indexOf(':');
  return port < 0 ? hostWithPort : hostWithPort.substring(0, port);
}
