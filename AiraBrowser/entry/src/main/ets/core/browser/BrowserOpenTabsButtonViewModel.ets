import { BrowserTabState } from '../tabs/TabManager';
import { BrowserTabsOverviewSectionPolicy } from './tabsOverview/BrowserTabsOverviewSectionPolicy';

/**
 * The split-toolbar tab button and the tabs-overview middle count are the same number:
 * ordinary tabs only. Home and privacy tabs stay out of both.
 */
export class BrowserOpenTabsButtonViewModel {
  private sectionPolicy: BrowserTabsOverviewSectionPolicy = new BrowserTabsOverviewSectionPolicy();

  resolveTabCount(tabs: BrowserTabState[]): number {
    return this.sectionPolicy.countVisibleTabs(tabs, 'tabs', {});
  }
}
