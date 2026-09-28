import { describe, expect, it } from '@ohos/hypium';
import { BrowserTabState, TabManager } from '../main/ets/core/tabs/TabManager';

function buildTab(id: string): BrowserTabState {
  return {
    id: id,
    profileId: 'profile-main',
    title: id,
    url: `https://example.com/${id}`,
    isHome: false,
    lastActiveAt: 1,
    pendingUrl: '',
    navigationHistory: [`https://example.com/${id}`],
    navigationIndex: 0,
    runtimeState: 'suspended',
    lastError: '',
    lastRestoreReason: '',
    lastDiscardReason: '',
    lastCrashReason: '',
    lastLoadedAt: 1,
    webStatePath: '',
    webStateUpdatedAt: 0,
    scrollOffsetY: 0,
    lastGoodUrl: `https://example.com/${id}`,
    lastGoodTitle: id,
    lastRestorableUrl: `https://example.com/${id}`,
    lastRestorableTitle: id,
    lastRestoreType: 'reload',
    privacyMode: 'regular',
    dataScope: 'profile_persistent',
    launchContext: {
      sourceType: '',
      sourceId: '',
      sourceUrl: '',
      key: ''
    },
    openerTabId: '',
    openSource: '',
    openedByNewWindow: false,
    pinned: false,
    muted: false,
    audible: false
  };
}

/**
 * Closing the active tab must hand the window back to the tab immediately before
 * it in list order. That order is the visual order of both the horizontal tab strip
 * (left to right) and the vertical sidebar (top to bottom), so closing the middle
 * tab of A, B, C returns to A rather than jumping to the far end of the list.
 */
export default function browserTabCloseNeighborPolicyTest(): void {
  describe('BrowserTabCloseNeighborPolicy', () => {
    it('returns to the preceding tab when the active tab in the middle is closed', 0, () => {
      const tabManager = new TabManager();
      const tabs = [buildTab('A'), buildTab('B'), buildTab('C')];

      const result = tabManager.closeTab(tabs, 'B', 'B');

      expect(result.activeTabId).assertEqual('A');
      expect(result.tabs.map((tab: BrowserTabState): string => tab.id).join(',')).assertEqual('A,C');
    });

    it('returns to the tab above when the lower active tab of a vertical list is closed', 0, () => {
      const tabManager = new TabManager();
      const tabs = [buildTab('A'), buildTab('B'), buildTab('C')];

      const result = tabManager.closeTab(tabs, 'C', 'C');

      expect(result.activeTabId).assertEqual('B');
    });

    it('steps forward only when the leading tab, which has no predecessor, is closed', 0, () => {
      const tabManager = new TabManager();
      const tabs = [buildTab('A'), buildTab('B'), buildTab('C')];

      const result = tabManager.closeTab(tabs, 'A', 'A');

      expect(result.activeTabId).assertEqual('B');
    });

    it('keeps the current tab when a background tab is closed', 0, () => {
      const tabManager = new TabManager();
      const tabs = [buildTab('A'), buildTab('B'), buildTab('C')];

      const result = tabManager.closeTab(tabs, 'A', 'C');

      expect(result.activeTabId).assertEqual('A');
      expect(result.tabs.map((tab: BrowserTabState): string => tab.id).join(',')).assertEqual('A,B');
    });

    it('clears the active tab when the only tab is closed', 0, () => {
      const tabManager = new TabManager();

      const result = tabManager.closeTab([buildTab('A')], 'A', 'A');

      expect(result.activeTabId).assertEqual('');
      expect(result.tabs.length).assertEqual(0);
    });
  });
}
