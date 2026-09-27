import { describe, expect, it } from '@ohos/hypium';
import {
  BrowserTabsOverviewSelectionDisplacementCoordinator,
  BrowserTabsOverviewSelectionDisplacementInput
} from '../main/ets/core/browser/tabsOverview/BrowserTabsOverviewSelectionDisplacementCoordinator';

function displacementInput(
  itemIndex: number,
  columnCount: number
): BrowserTabsOverviewSelectionDisplacementInput {
  return {
    tabId: `tab-${itemIndex}`,
    itemIndex: itemIndex,
    selectedTabId: 'tab-1',
    selectedIndex: 1,
    columnCount: columnCount,
    cardWidth: 200,
    itemHeight: 300,
    gridGap: 12
  };
}

export default function browserTabsOverviewSelectionDisplacementCoordinatorTest(): void {
  describe('BrowserTabsOverviewSelectionDisplacementCoordinator', () => {
    const coordinator = new BrowserTabsOverviewSelectionDisplacementCoordinator();

    it('keeps grid neighbors moving along their row and column', 0, () => {
      const left = coordinator.resolveForLayout('grid', displacementInput(0, 2));
      const below = coordinator.resolveForLayout('grid', displacementInput(2, 2));

      expect(left.x).assertEqual(-212);
      expect(left.y).assertEqual(0);
      expect(below.x).assertEqual(0);
      expect(below.y).assertEqual(312);
    });

    it('does not slide strip neighbors up and down', 0, () => {
      // The old caller passed a column count of 1, which is exactly one vertical column.
      const left = coordinator.resolveForLayout('horizontal_cards', displacementInput(0, 1));
      const right = coordinator.resolveForLayout('horizontal_cards', displacementInput(2, 1));

      expect(left.x).assertEqual(0);
      expect(left.y).assertEqual(0);
      expect(right.x).assertEqual(0);
      expect(right.y).assertEqual(0);
    });

    it('does not add the grid offset on top of the deck', 0, () => {
      const left = coordinator.resolveForLayout('stack', displacementInput(0, 3));
      const right = coordinator.resolveForLayout('stack', displacementInput(2, 3));

      expect(left.x).assertEqual(0);
      expect(left.y).assertEqual(0);
      expect(right.x).assertEqual(0);
      expect(right.y).assertEqual(0);
    });
  });
}
