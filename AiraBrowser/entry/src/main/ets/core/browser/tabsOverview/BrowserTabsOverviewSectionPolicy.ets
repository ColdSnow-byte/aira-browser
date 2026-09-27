import { BrowserTabState } from '../../tabs/TabManager';
import { BrowserProfileBoundaryService } from '../BrowserProfileBoundaryService';

/**
 * The tabs overview is one surface with three peer sections. `tabs` and `privacy` are tab
 * collections; `devices` owns no tabs at all — it hosts the cross-device page, whose remote
 * tabs belong to other installations and can only be opened, never closed or mutated here.
 */
export type BrowserTabsOverviewSection = 'tabs' | 'privacy' | 'devices';

export class BrowserTabsOverviewSectionPolicy {
  private profileBoundaryService: BrowserProfileBoundaryService = new BrowserProfileBoundaryService();

  resolveTabsForSection(
    tabs: BrowserTabState[],
    section: BrowserTabsOverviewSection
  ): BrowserTabState[] {
    return tabs.filter((tab: BrowserTabState) => this.belongsToSection(tab, section));
  }

  /**
   * The ordinary-tab count shown on the tabs overview and on the split toolbar's tab button.
   * Home tabs and the other section never count, and ids already removed inside the overview
   * drop out before the close is committed.
   */
  countVisibleTabs(
    tabs: BrowserTabState[],
    section: BrowserTabsOverviewSection,
    removedTabIds: Record<string, boolean>
  ): number {
    const sectionTabs = this.resolveTabsForSection(tabs, section);
    let count = 0;
    for (let index = 0; index < sectionTabs.length; index += 1) {
      if (removedTabIds[sectionTabs[index].id] !== true) {
        count += 1;
      }
    }
    return count;
  }

  resolveSectionForTab(tab: BrowserTabState | undefined): BrowserTabsOverviewSection {
    return this.isPrivateTab(tab) ? 'privacy' : 'tabs';
  }

  isPrivateTab(tab: BrowserTabState | undefined): boolean {
    if (tab === undefined) {
      return false;
    }
    return this.profileBoundaryService.isSessionEphemeral(
      this.profileBoundaryService.buildBoundaryInput(tab.profileId, tab.privacyMode, tab.dataScope)
    );
  }

  belongsToSection(tab: BrowserTabState, section: BrowserTabsOverviewSection): boolean {
    if (tab.isHome) {
      return false;
    }
    if (section === 'devices') {
      // No local tab ever belongs to the cross-device section.
      return false;
    }
    return section === 'privacy' ? this.isPrivateTab(tab) : !this.isPrivateTab(tab);
  }
}
