import { describe, expect, it } from '@ohos/hypium';
import {
  BrowserGestureOnboardingPromptEligibilityInput,
  shouldShowBrowserGestureOnboardingPrompt
} from '../main/ets/core/browser/BrowserGestureOnboardingPromptCoordinator';

function eligibleInput(
  homePageStyle: BrowserGestureOnboardingPromptEligibilityInput['homePageStyle']
): BrowserGestureOnboardingPromptEligibilityInput {
  return {
    shellFamily: 'phone',
    appVisible: true,
    privateMode: false,
    blockingSurfaceVisible: false,
    topOffsetVp: 36,
    homePageStyle: homePageStyle
  };
}

export default function browserGestureOnboardingPromptPolicyTest(): void {
  describe('shouldShowBrowserGestureOnboardingPrompt', () => {
    it('shows the bottom gesture hint only on the classic homepage', 0, () => {
      expect(shouldShowBrowserGestureOnboardingPrompt(eligibleInput('classic'), false)).assertTrue();
      expect(shouldShowBrowserGestureOnboardingPrompt(eligibleInput('centered'), false)).assertFalse();
      expect(shouldShowBrowserGestureOnboardingPrompt(eligibleInput('minimal'), false)).assertFalse();
    });

    it('does not show the hint again after it has been dismissed', 0, () => {
      expect(shouldShowBrowserGestureOnboardingPrompt(eligibleInput('classic'), true)).assertFalse();
    });
  });
}
