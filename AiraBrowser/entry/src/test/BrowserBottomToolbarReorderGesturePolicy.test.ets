import { describe, expect, it } from '@ohos/hypium';
import {
  reduceBrowserBottomToolbarReorderGesture
} from '../main/ets/core/browser/BrowserBottomToolbarReorderGesturePolicy';

export default function browserBottomToolbarReorderGesturePolicyTest(): void {
  describe('browserBottomToolbarReorderGesturePolicyTest', () => {
    it('does not latch reorder when a long press is released without moving', 0, () => {
      const lifted = reduceBrowserBottomToolbarReorderGesture(false, false, '', 'longPress', 'downloads');
      expect(lifted.reorderActive).assertFalse();
      expect(lifted.liftArmed).assertTrue();
      expect(lifted.performFeedback).assertTrue();
      expect(lifted.consumption).assertEqual('set');

      const released = reduceBrowserBottomToolbarReorderGesture(
        lifted.reorderActive,
        lifted.liftArmed,
        'downloads',
        'touchUp',
        ''
      );
      expect(released.reorderActive).assertFalse();
      expect(released.liftArmed).assertFalse();
      expect(released.armClickGuard).assertTrue();
      expect(released.consumption).assertEqual('keep');

      const otherTool = reduceBrowserBottomToolbarReorderGesture(
        released.reorderActive,
        released.liftArmed,
        'downloads',
        'click',
        'history'
      );
      expect(otherTool.swallowClick).assertFalse();
      expect(otherTool.reorderActive).assertFalse();

      const releaseClick = reduceBrowserBottomToolbarReorderGesture(
        released.reorderActive,
        released.liftArmed,
        'downloads',
        'click',
        'downloads'
      );
      expect(releaseClick.swallowClick).assertTrue();
      expect(releaseClick.consumption).assertEqual('clear');
      expect(releaseClick.reorderActive).assertFalse();

      const nextClick = reduceBrowserBottomToolbarReorderGesture(false, false, '', 'click', 'downloads');
      expect(nextClick.swallowClick).assertFalse();
    });

    it('clears a stuck reorder latch on the next click', 0, () => {
      const dragging = reduceBrowserBottomToolbarReorderGesture(false, false, '', 'dragStart', 'downloads');
      expect(dragging.reorderActive).assertTrue();

      const blocked = reduceBrowserBottomToolbarReorderGesture(
        dragging.reorderActive,
        dragging.liftArmed,
        'downloads',
        'click',
        'history'
      );
      expect(blocked.swallowClick).assertTrue();
      expect(blocked.reorderActive).assertFalse();
      expect(blocked.liftArmed).assertFalse();
      expect(blocked.consumption).assertEqual('clear');

      const recovered = reduceBrowserBottomToolbarReorderGesture(
        blocked.reorderActive,
        blocked.liftArmed,
        '',
        'click',
        'history'
      );
      expect(recovered.swallowClick).assertFalse();
    });

    it('still swallows the release click after a real drag', 0, () => {
      const lifted = reduceBrowserBottomToolbarReorderGesture(false, false, '', 'longPress', 'downloads');
      const dragging = reduceBrowserBottomToolbarReorderGesture(
        lifted.reorderActive,
        lifted.liftArmed,
        'downloads',
        'dragStart',
        'downloads'
      );
      expect(dragging.reorderActive).assertTrue();
      expect(dragging.liftArmed).assertFalse();

      const dropped = reduceBrowserBottomToolbarReorderGesture(
        dragging.reorderActive,
        dragging.liftArmed,
        'downloads',
        'drop',
        ''
      );
      expect(dropped.reorderActive).assertFalse();
      expect(dropped.armClickGuard).assertTrue();

      const releaseClick = reduceBrowserBottomToolbarReorderGesture(
        dropped.reorderActive,
        dropped.liftArmed,
        'downloads',
        'click',
        'downloads'
      );
      expect(releaseClick.swallowClick).assertTrue();

      const idleTouch = reduceBrowserBottomToolbarReorderGesture(false, false, '', 'touchUp', '');
      expect(idleTouch.armClickGuard).assertFalse();
      expect(idleTouch.clearClickGuard).assertFalse();
    });
  });
}
