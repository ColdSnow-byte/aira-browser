import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import {
  FeatureIntroSearchEngineChoice,
  FeatureIntroSearchEngineViewModel
} from '../../core/onboarding/FeatureIntroSearchEngineViewModel';
import {
  FeatureIntroSearchEngineCoordinator,
  FeatureIntroSearchEngineHost
} from '../../core/onboarding/FeatureIntroSearchEngineCoordinator';
import { FeatureIntroSkipControl } from '../components/onboarding/FeatureIntroSkipControl';
import { FeatureIntroExitDestination } from '../../core/onboarding/FeatureIntroRoutePolicy';
import { BrowserStatusBarStyleService } from '../../services/browser/BrowserStatusBarStyleService';
import { SettingsTopSafeInsetService } from '../../services/settings/SettingsTopSafeInsetService';
import { BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY } from '../../core/theme/BrowserThemeStorageKeys';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_ON_ACCENT_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../core/theme/BrowserThemeStorageKeys';
import { FEATURE_INTRO_HOMEPAGE_ROUTE } from '../router/AppRoutes';
import { finishOnboardingToBrowser, returnToPreviousOnboardingStep } from '../router/OnboardingNavigation';

const FEATURE_INTRO_SEARCH_HORIZONTAL_PADDING: number = 24;
const FEATURE_INTRO_SEARCH_CONTENT_MAX_WIDTH: number = 430;
const FEATURE_INTRO_SEARCH_ACTION_HEIGHT: number = 40;
const FEATURE_INTRO_SEARCH_ROW_HEIGHT: number = 64;
const FEATURE_INTRO_SEARCH_ICON_SIZE: number = 28;

@Entry
@Component
struct FeatureIntroSearchEnginePage {
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = '#F2F3F5';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_ON_ACCENT_KEY) private storedOnAccentColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6368';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) @Watch('syncStatusBarContentStyle')
  private storedResolvedThemeMode: string = 'light';
  @State private selectedId: string = 'bing';
  @State private busy: boolean = false;
  @State private topInset: number = 0;
  private readonly viewModel: FeatureIntroSearchEngineViewModel = new FeatureIntroSearchEngineViewModel();
  private readonly topSafeInsetService: SettingsTopSafeInsetService = new SettingsTopSafeInsetService();
  private readonly statusBarStyleService: BrowserStatusBarStyleService = new BrowserStatusBarStyleService();
  private readonly host: FeatureIntroSearchEngineHost = {
    openHomepageStyle: (): void => {
      router.pushUrl({ url: FEATURE_INTRO_HOMEPAGE_ROUTE }).catch((_error: Error) => {
        this.busy = false;
        this.coordinator.abandonLeave();
      });
    },
    leave: (destination: FeatureIntroExitDestination): void => {
      finishOnboardingToBrowser();
      this.busy = false;
      this.coordinator.abandonLeave();
    }
  };
  private readonly coordinator: FeatureIntroSearchEngineCoordinator =
    new FeatureIntroSearchEngineCoordinator(this.host);

  aboutToAppear(): void {
    this.selectedId = this.viewModel.defaultChoiceId();
    this.syncStatusBarContentStyle();
  }

  onPageShow(): void {
    this.busy = false;
    this.coordinator.abandonLeave();
    this.readTopInset();
    this.syncStatusBarContentStyle();
  }

  onBackPress(): boolean {
    if (!this.busy) {
      returnToPreviousOnboardingStep('search');
    }
    return true;
  }

  build() {
    Column() {
      FeatureIntroSkipControl({
        label: this.viewModel.skipLabel(),
        topInsetVp: this.topInset,
        skipEnabled: !this.busy,
        onConfirm: (): void => {
          this.skipSetup();
        }
      })

      Scroll() {
        Column() {
          Text(this.viewModel.title())
            .width('100%')
            .fontSize(26)
            .lineHeight(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.storedPrimaryTextColor)
            .textAlign(TextAlign.Center)

          Text(this.viewModel.subtitle())
            .width('100%')
            .fontSize(15)
            .lineHeight(23)
            .fontColor(this.storedSecondaryTextColor)
            .textAlign(TextAlign.Center)
            .margin({ top: 10 })

          this.buildChoices()
        }
        .width('100%')
        .constraintSize({ maxWidth: FEATURE_INTRO_SEARCH_CONTENT_MAX_WIDTH })
        .padding({
          left: FEATURE_INTRO_SEARCH_HORIZONTAL_PADDING,
          right: FEATURE_INTRO_SEARCH_HORIZONTAL_PADDING,
          top: 12,
          bottom: 24
        })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .align(Alignment.Top)

      this.buildContinueButton()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.storedPageBackgroundColor)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildChoices() {
    Column() {
      ForEach(this.viewModel.choices(), (choice: FeatureIntroSearchEngineChoice, index: number) => {
        this.buildChoice(choice, index, this.viewModel.choices().length)
      }, (choice: FeatureIntroSearchEngineChoice) => choice.id)
    }
    .width('100%')
    .margin({ top: 28 })
    .padding({ top: 4, bottom: 4 })
    .backgroundColor(this.storedSurfaceBackgroundColor)
    .borderRadius(22)
    .clip(true)
  }

  @Builder
  private buildChoice(choice: FeatureIntroSearchEngineChoice, index: number, total: number) {
    Column() {
      Row({ space: 12 }) {
        Image(this.choiceIcon(choice.id))
          .width(FEATURE_INTRO_SEARCH_ICON_SIZE)
          .height(FEATURE_INTRO_SEARCH_ICON_SIZE)
          .objectFit(ImageFit.Contain)

        Text(choice.label)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedPrimaryTextColor)
          .layoutWeight(1)

        Radio({
          value: choice.id,
          group: 'feature-intro-search-engine'
        })
          .checked(this.selectedId === choice.id)
          .hitTestBehavior(HitTestMode.None)
          .radioStyle({
            checkedBackgroundColor: this.storedAccentColor
          })
      }
      .width('100%')
      .height(FEATURE_INTRO_SEARCH_ROW_HEIGHT)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .onClick((): void => {
        if (!this.busy) {
          this.selectedId = choice.id;
        }
      })

      if (index < total - 1) {
        Divider()
          .width('100%')
          .height(1)
          .color(this.storedDividerColor)
          .margin({ left: 56, right: 16 })
      }
    }
    .width('100%')
  }

  @Builder
  private buildContinueButton() {
    Column() {
      Button(this.viewModel.continueLabel())
        .width('100%')
        .height(FEATURE_INTRO_SEARCH_ACTION_HEIGHT)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedOnAccentColor)
        .backgroundColor(this.storedAccentColor)
        .borderRadius(FEATURE_INTRO_SEARCH_ACTION_HEIGHT / 2)
        .stateEffect(false)
        .enabled(!this.busy)
        .opacity(this.busy ? 0.58 : 1)
        .onClick((): void => {
          this.continueWithSelection();
        })
    }
    .width('100%')
    .constraintSize({ maxWidth: FEATURE_INTRO_SEARCH_CONTENT_MAX_WIDTH })
    .padding({
      left: FEATURE_INTRO_SEARCH_HORIZONTAL_PADDING,
      right: FEATURE_INTRO_SEARCH_HORIZONTAL_PADDING,
      bottom: 24
    })
  }

  private choiceIcon(engineId: string): Resource {
    if (engineId === 'baidu') {
      return $r('app.media.search_engine_baidu');
    }
    if (engineId === 'google') {
      return $r('app.media.search_engine_google');
    }
    if (engineId === 'sogou') {
      return $r('app.media.search_engine_sogou');
    }
    if (engineId === 'qihoo') {
      return $r('app.media.search_engine_qihoo');
    }
    if (engineId === 'shenma') {
      return $r('app.media.search_engine_shenma');
    }
    return $r('app.media.search_engine_bing');
  }

  private continueWithSelection(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.coordinator.continueWith(this.selectedId);
  }

  private skipSetup(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.coordinator.skip();
  }

  private returnToSlides(): void {
    if (this.busy) {
      return;
    }
    returnToPreviousOnboardingStep('search');
  }

  private syncStatusBarContentStyle(): void {
    this.statusBarStyleService.applyLightContentStyle(
      this.getUIContext().getHostContext() as common.UIAbilityContext,
      this.storedResolvedThemeMode === 'dark'
    );
  }

  private readTopInset(): void {
    this.topSafeInsetService.resolve(this.getUIContext().getHostContext() as common.UIAbilityContext)
      .then((inset: number) => {
        this.topInset = inset;
      });
  }
}
