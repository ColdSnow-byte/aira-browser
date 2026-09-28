import { describe, expect, it } from '@ohos/hypium';
import { BookmarkNode } from '../main/ets/common/models/BrowserModels';
import { BrowserTabState } from '../main/ets/core/tabs/TabManager';
import {
  matchBookmarkSuggestions,
  matchOpenTabSuggestions
} from '../main/ets/services/search/LocalOmniboxSuggestionMatcher';

function bookmark(id: string, title: string, url: string): BookmarkNode {
  return {
    id: id,
    type: 'bookmark',
    title: title,
    url: url,
    position: 0,
    createdAt: 1,
    updatedAt: 1,
    sync: {
      state: 'synced',
      source: 'local',
      lastModifiedAt: 1,
      lastModifiedBy: 'test',
      deviceId: 'device',
      originId: id
    }
  };
}

function tab(id: string, title: string, url: string, lastActiveAt: number): BrowserTabState {
  return {
    id: id,
    profileId: 'profile-main',
    title: title,
    url: url,
    isHome: false,
    lastActiveAt: lastActiveAt,
    pendingUrl: '',
    navigationHistory: [url],
    navigationIndex: 0,
    runtimeState: 'active',
    lastError: '',
    lastRestoreReason: '',
    lastDiscardReason: '',
    lastCrashReason: '',
    lastLoadedAt: lastActiveAt,
    webStatePath: '',
    webStateUpdatedAt: 0,
    scrollOffsetY: 0,
    lastGoodUrl: url,
    lastGoodTitle: title,
    lastRestorableUrl: url,
    lastRestorableTitle: title,
    lastRestoreType: 'none',
    privacyMode: 'regular',
    dataScope: 'profile_persistent',
    launchContext: {
      sourceType: '',
      sourceId: '',
      sourceUrl: '',
      key: ''
    },
    openerTabId: '',
    openSource: 'user_new_tab',
    openedByNewWindow: false,
    pinned: false,
    muted: false,
    audible: false
  };
}

export default function localOmniboxSuggestionMatcherTest(): void {
  describe('LocalOmniboxSuggestionMatcher', () => {
    it('ranks a bookmark title prefix ahead of a later substring', 0, () => {
      const matches = matchBookmarkSuggestions([
        bookmark('late', '银行发票', 'https://late.example'),
        bookmark('prefix', '发票中心', 'https://invoice.example')
      ], '发票', 2);

      expect(matches[0].refId).assertEqual('prefix');
      expect(matches[0].source).assertEqual('bookmarks');
      expect(matches[0].target).assertEqual('https://invoice.example');
    });

    it('suggests another open tab and skips the active tab', 0, () => {
      const now = Date.now();
      const tabs: BrowserTabState[] = [
        tab('active', '当前', 'https://current.example', now),
        tab('other', 'Aira 仓库', 'https://github.com/aira', now - 1000)
      ];

      const matches = matchOpenTabSuggestions(tabs, {
        query: 'github',
        activeTabId: 'active',
        privacyMode: 'regular',
        dataScope: 'profile_persistent',
        profileId: 'profile-main',
        limit: 1
      });

      expect(matches.length).assertEqual(1);
      expect(matches[0].source).assertEqual('tabs');
      expect(matches[0].refId).assertEqual('other');
    });

    it('does not suggest a private tab in a regular session', 0, () => {
      const privateTab = tab('private', '秘密', 'https://secret.example', Date.now());
      privateTab.privacyMode = 'private';
      privateTab.dataScope = 'session_ephemeral';

      const matches = matchOpenTabSuggestions([privateTab], {
        query: 'secret',
        activeTabId: 'other',
        privacyMode: 'regular',
        dataScope: 'profile_persistent',
        limit: 1
      });

      expect(matches.length).assertEqual(0);
    });
  });
}
