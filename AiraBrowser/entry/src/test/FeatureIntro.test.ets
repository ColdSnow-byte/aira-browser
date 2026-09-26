import { describe, expect, it } from '@ohos/hypium';
import { FeatureIntroViewModel } from '../main/ets/core/onboarding/FeatureIntroViewModel';
import { resolveFeatureIntroLayout } from '../main/ets/core/onboarding/FeatureIntroLayoutPolicy';
import {
  clampFeatureIntroGateDrag,
  featureIntroGateBackdropColor,
  isFeatureIntroGateUnlocked,
  resolveFeatureIntroGateLogoTop,
  resolveFeatureIntroGateTravel
} from '../main/ets/core/onboarding/FeatureIntroGatePolicy';
import {
  resolveFeatureIntroExitDestination,
  resolveInitialOnboardingDestination,
  shouldResumeFeatureIntroSlides
} from '../main/ets/core/onboarding/FeatureIntroRoutePolicy';
import {
  FeatureIntroSearchEngineViewModel,
  resolveFeatureIntroSearchEngineChoice
} from '../main/ets/core/onboarding/FeatureIntroSearchEngineViewModel';
import {
  FeatureIntroHomepageViewModel,
  resolveFeatureIntroHomepageStyle
} from '../main/ets/core/onboarding/FeatureIntroHomepageViewModel';

export default function featureIntroTest(): void {
  describe('FeatureIntroViewModel', () => {
    it('keeps the four first-open slides in order', 0, () => {
      const slides = new FeatureIntroViewModel().slides();

      expect(slides.length).assertEqual(4);
      expect(slides[0].id).assertEqual('ad_block');
      expect(slides[0].title).assertEqual('少一点广告打扰');
      expect(slides[1].id).assertEqual('video_takeover');
      expect(slides[1].title).assertEqual('接管网页视频');
      expect(slides[2].id).assertEqual('user_scripts');
      expect(slides[2].title).assertEqual('支持用户脚本');
      expect(slides[3].id).assertEqual('sync');
      expect(slides[3].title).assertEqual('换一台，接着用');
    });

    it('uses next on every slide, including the last', 0, () => {
      const viewModel = new FeatureIntroViewModel();

      expect(viewModel.actionLabel(0)).assertEqual('下一步');
      expect(viewModel.actionLabel(2)).assertEqual('下一步');
      expect(viewModel.isLast(2)).assertFalse();
      expect(viewModel.actionLabel(3)).assertEqual('下一步');
      expect(viewModel.isLast(3)).assertTrue();
      expect(viewModel.gateActionLabel()).assertEqual('向右滑动开始使用');
      expect(viewModel.gateSkipLabel()).assertEqual('跳过');
      expect(viewModel.skipConfirmTitle()).assertEqual('跳过介绍');
      expect(viewModel.skipConfirmMessage()).assertEqual('跳过后将直接进入主页，不再显示这些介绍。');
      expect(viewModel.skipConfirmCancelLabel()).assertEqual('取消');
      expect(viewModel.skipConfirmEnterLabel()).assertEqual('进入主页');
    });
  });

  describe('featureIntroGate', () => {
    it('uses a black backdrop in dark mode and white otherwise', 0, () => {
      expect(featureIntroGateBackdropColor('dark')).assertEqual('#000000');
      expect(featureIntroGateBackdropColor('light')).assertEqual('#FFFFFF');
    });

    it('unlocks only after the knob travels almost the full track', 0, () => {
      const travel = resolveFeatureIntroGateTravel(320);

      expect(clampFeatureIntroGateDrag(-20, travel)).assertEqual(0);
      expect(clampFeatureIntroGateDrag(travel + 40, travel)).assertEqual(travel);
      expect(isFeatureIntroGateUnlocked(travel * 0.5, travel)).assertFalse();
      expect(isFeatureIntroGateUnlocked(travel * 0.86, travel)).assertTrue();
      expect(isFeatureIntroGateUnlocked(10, 0)).assertFalse();
    });

    it('keeps the logo in the upper middle without covering the slider', 0, () => {
      const phoneTop = resolveFeatureIntroGateLogoTop(844, 36, 108);
      const shortTop = resolveFeatureIntroGateLogoTop(480, 24, 96);

      expect(phoneTop).assertEqual(236);
      expect(shortTop < 480 - 96 - 120).assertTrue();
    });
  });

  describe('resolveFeatureIntroLayout', () => {
    it('keeps a phone slot near 9:8', 0, () => {
      const layout = resolveFeatureIntroLayout({
        windowWidthVp: 390,
        windowHeightVp: 844,
        topInsetVp: 36,
        bottomInsetVp: 28
      });

      expect(layout.videoHeightVp).assertEqual(347);
      expect(layout.contentMaxWidthVp).assertEqual(430);
      expect(layout.bottomPaddingVp).assertEqual(28);
    });

    it('shrinks the slot on a short window so the copy still fits', 0, () => {
      const layout = resolveFeatureIntroLayout({
        windowWidthVp: 360,
        windowHeightVp: 520,
        topInsetVp: 24,
        bottomInsetVp: 16
      });

      expect(layout.videoHeightVp).assertEqual(244);
    });

    it('caps the slot on a wide window', 0, () => {
      const layout = resolveFeatureIntroLayout({
        windowWidthVp: 800,
        windowHeightVp: 1200,
        topInsetVp: 32,
        bottomInsetVp: 24
      });

      expect(layout.videoHeightVp).assertEqual(440);
      expect(layout.horizontalPaddingVp).assertEqual(24);
    });

    it('does not invent a slot from empty measurements', 0, () => {
      const layout = resolveFeatureIntroLayout({
        windowWidthVp: 0,
        windowHeightVp: -1,
        topInsetVp: 0,
        bottomInsetVp: 0
      });

      expect(layout.videoHeightVp).assertEqual(0);
    });
  });

  describe('featureIntroSearchEngine', () => {
    it('offers six built-in engines, with Bing selected by default', 0, () => {
      const viewModel = new FeatureIntroSearchEngineViewModel();
      const choices = viewModel.choices();

      expect(viewModel.title()).assertEqual('选择默认搜索引擎');
      expect(viewModel.continueLabel()).assertEqual('下一步');
      expect(viewModel.skipLabel()).assertEqual('跳过');
      expect(viewModel.defaultChoiceId()).assertEqual('bing');
      expect(choices.length).assertEqual(6);
      expect(choices[0].id).assertEqual('bing');
      expect(choices[0].label).assertEqual('必应');
      expect(choices[1].id).assertEqual('baidu');
      expect(choices[1].label).assertEqual('百度');
      expect(choices[2].id).assertEqual('google');
      expect(choices[2].label).assertEqual('谷歌');
      expect(choices[3].id).assertEqual('sogou');
      expect(choices[3].label).assertEqual('搜狗');
      expect(choices[4].id).assertEqual('qihoo');
      expect(choices[4].label).assertEqual('360搜索');
      expect(choices[5].id).assertEqual('shenma');
      expect(choices[5].label).assertEqual('神马');
      expect(resolveFeatureIntroSearchEngineChoice('sogou')).assertEqual('sogou');
      expect(resolveFeatureIntroSearchEngineChoice('qihoo')).assertEqual('qihoo');
      expect(resolveFeatureIntroSearchEngineChoice('shenma')).assertEqual('shenma');
      expect(resolveFeatureIntroSearchEngineChoice('brave')).assertEqual('bing');
    });
  });

  describe('featureIntroHomepage', () => {
    it('offers the two built-in homepage cards, with classic selected by default', 0, () => {
      const viewModel = new FeatureIntroHomepageViewModel();
      const choices = viewModel.choices(viewModel.defaultStyle());

      expect(viewModel.title()).assertEqual('选择主页样式');
      expect(viewModel.continueLabel()).assertEqual('下一步');
      expect(viewModel.previousLabel()).assertEqual('上一步');
      expect(viewModel.skipLabel()).assertEqual('跳过');
      expect(viewModel.defaultStyle()).assertEqual('classic');
      expect(choices.length).assertEqual(2);
      expect(choices[0].style).assertEqual('classic');
      expect(choices[0].title).assertEqual('经典主页');
      expect(choices[0].isActive).assertTrue();
      expect(choices[1].style).assertEqual('centered');
      expect(choices[1].title).assertEqual('简约主页');
      expect(choices[1].isActive).assertFalse();
      expect(viewModel.cards('classic').length).assertEqual(2);
      expect(viewModel.cards('classic')[0].kind).assertEqual('system');
      expect(viewModel.cards('centered')[1].isCurrent).assertTrue();
      expect(resolveFeatureIntroHomepageStyle('centered')).assertEqual('centered');
      expect(resolveFeatureIntroHomepageStyle('other')).assertEqual('classic');
    });
  });

  describe('resolveInitialOnboardingDestination', () => {
    it('shows the feature intro only before the sync welcome is finished', 0, () => {
      expect(resolveInitialOnboardingDestination(false, false)).assertEqual('feature_intro');
      expect(resolveInitialOnboardingDestination(true, false)).assertEqual('startup_welcome');
      expect(resolveInitialOnboardingDestination(false, true)).assertEqual('browser');
      expect(resolveInitialOnboardingDestination(true, true)).assertEqual('browser');
    });

    it('returns to the sync welcome after the feature intro on a new install', 0, () => {
      expect(resolveFeatureIntroExitDestination(false)).assertEqual('startup_welcome');
      expect(resolveFeatureIntroExitDestination(true)).assertEqual('browser');
    });

    it('resumes the intro slides only for the search-engine back navigation', 0, () => {
      expect(shouldResumeFeatureIntroSlides('1')).assertTrue();
      expect(shouldResumeFeatureIntroSlides(undefined)).assertFalse();
      expect(shouldResumeFeatureIntroSlides('')).assertFalse();
    });
  });
}
