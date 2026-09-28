/**
 * Toolbar action reorder gesture.
 *
 * Official List `onMove` only reports `onDrop` when a finger-following slide ends. A long press that
 * lifts an icon and is released without moving never gets that callback. Treating the lift itself as
 * an active reorder therefore leaves every later tap ignored.
 */
export type BrowserBottomToolbarReorderGestureKind =
  'longPress' | 'dragStart' | 'drop' | 'touchUp' | 'click';

/** How the consumed action id should change. `keep` retains the id the component already stored. */
export type BrowserBottomToolbarReorderConsumption = 'keep' | 'clear' | 'set';

export interface BrowserBottomToolbarReorderGestureEffect {
  reorderActive: boolean;
  liftArmed: boolean;
  consumption: BrowserBottomToolbarReorderConsumption;
  swallowClick: boolean;
  performFeedback: boolean;
  armClickGuard: boolean;
  clearClickGuard: boolean;
}

export function reduceBrowserBottomToolbarReorderGesture(
  reorderActive: boolean,
  liftArmed: boolean,
  consumedActionId: string,
  kind: BrowserBottomToolbarReorderGestureKind,
  actionId: string
): BrowserBottomToolbarReorderGestureEffect {
  if (kind === 'longPress') {
    return effectForLift(actionId);
  }
  if (kind === 'dragStart') {
    return effectForDragStart(actionId);
  }
  if (kind === 'drop' || kind === 'touchUp') {
    return effectForFingerUp(reorderActive, liftArmed, consumedActionId);
  }
  return effectForClick(reorderActive, liftArmed, consumedActionId, actionId);
}

function effectForLift(actionId: string): BrowserBottomToolbarReorderGestureEffect {
  if (actionId.length <= 0) {
    return unchanged(false, false);
  }
  return {
    reorderActive: false,
    liftArmed: true,
    consumption: 'set',
    swallowClick: false,
    performFeedback: true,
    armClickGuard: false,
    clearClickGuard: true
  };
}

function effectForDragStart(actionId: string): BrowserBottomToolbarReorderGestureEffect {
  if (actionId.length <= 0) {
    return unchanged(false, false);
  }
  return {
    reorderActive: true,
    liftArmed: false,
    consumption: 'set',
    swallowClick: false,
    performFeedback: false,
    armClickGuard: false,
    clearClickGuard: true
  };
}

function effectForFingerUp(
  reorderActive: boolean,
  liftArmed: boolean,
  consumedActionId: string
): BrowserBottomToolbarReorderGestureEffect {
  if (!reorderActive && !liftArmed) {
    return unchanged(reorderActive, liftArmed);
  }
  return {
    reorderActive: false,
    liftArmed: false,
    consumption: 'keep',
    swallowClick: false,
    performFeedback: false,
    armClickGuard: consumedActionId.length > 0,
    clearClickGuard: true
  };
}

function effectForClick(
  reorderActive: boolean,
  liftArmed: boolean,
  consumedActionId: string,
  actionId: string
): BrowserBottomToolbarReorderGestureEffect {
  const blocksAll = reorderActive;
  const blocksThis = consumedActionId.length > 0 && consumedActionId === actionId;
  if (!blocksAll && !blocksThis) {
    return unchanged(reorderActive, liftArmed);
  }
  return {
    reorderActive: false,
    liftArmed: false,
    consumption: 'clear',
    swallowClick: true,
    performFeedback: false,
    armClickGuard: false,
    clearClickGuard: true
  };
}

function unchanged(
  reorderActive: boolean,
  liftArmed: boolean
): BrowserBottomToolbarReorderGestureEffect {
  return {
    reorderActive: reorderActive,
    liftArmed: liftArmed,
    consumption: 'keep',
    swallowClick: false,
    performFeedback: false,
    armClickGuard: false,
    clearClickGuard: false
  };
}
