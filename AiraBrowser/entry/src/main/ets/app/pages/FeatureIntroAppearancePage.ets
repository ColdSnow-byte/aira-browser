import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import { BrowserTabsOverviewLayoutStyle, BrowserThemeMode, BrowserThemePaletteId } from '../../common/models/BrowserModels';
import {
  FeatureIntroAppearanceCoordinator,
  FeatureIntroAppearanceHost
} from '../../core/onboarding/FeatureIntroAppearanceCoordinator';
import {
  FeatureIntroAppearancePaletteChoice,
  FeatureIntroAppearanceThemeModeChoice,
  FeatureIntroAppearanceViewModel
} from '../../core/onboarding/FeatureIntroAppearanceViewModel';
import { FeatureIntroExitDestination } from '../../core/onboarding/FeatureIntroRoutePolicy';
import { TabOverviewLayoutOptionState } from '../../core/settings/TabOverviewLayoutSettingsCoordinator';
import { sharedBrowserThemeModeCoordinator } from '../bootstrap/BrowserAppRuntime';
import { FeatureIntroSkipControl } from '../components/onboarding/FeatureIntroSkipControl';
import { TabOverviewLayoutOption } from '../components/settings/TabOverviewLayoutChoiceSheet';
import { BrowserStatusBarStyleService } from '../../services/browser/BrowserStatusBarStyleService';
import { SettingsTopSafeInsetService } from '../../services/settings/SettingsTopSafeInsetService';
import { BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY } from '../../core/theme/BrowserThemeStorageKeys';
import { STARTUP_WELCOME_INTRO_ROUTE } from '../router/AppRoutes';
import { finishOnboardingToBrowser, returnToPreviousOnboardingStep } from '../router/OnboardingNavigation';

const FEATURE_INTRO_APPEARANCE_HORIZONTAL_PADDING: number = 24;
const FEATURE_INTRO_APPEARANCE_CONTENT_MAX_WIDTH: number = 430;
const FEATURE_INTRO_APPEARANCE_ACTION_HEIGHT: number = 40;
const FEATURE_INTRO_APPEARANCE_SWATCH_SIZE: number = 36;

@Entry
@Component
struct FeatureIntroAppearancePage {
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) @Watch('syncPreviewTheme')
  private storedResolvedThemeMode: string = 'light';
  @State private previewAccentColor: string = '#0A59F7';
  @State private previewOnAccentColor: string = '#FFFFFF';
  @State private previewPageBackgroundColor: string = '#F2F3F5';
  @State private previewSurfaceBackgroundColor: string = '#FFFFFF';
  @State private previewPrimaryTextColor: string = '#111318';
  @State private previewSecondaryTextColor: string = '#5F6368';
  @State private selectedThemeMode: string = 'system';
  @State private selectedPaletteId: string = 'default';
  @State private selectedTabStyle: string = 'grid';
  @State private busy: boolean = false;
  @State private topInset: number = 0;
  private readonly viewModel: FeatureIntroAppearanceViewModel = new FeatureIntroAppearanceViewModel();
  private readonly topSafeInsetService: SettingsTopSafeInsetService = new SettingsTopSafeInsetService();
  private readonly statusBarStyleService: BrowserStatusBarStyleService = new BrowserStatusBarStyleService();
  private readonly host: FeatureIntroAppearanceHost = {
    openAccount: (): void => {
      router.pushUrl({ url: STARTUP_WELCOME_INTRO_ROUTE }).catch((_error: Error) => {
        this.busy = false;
        this.coordinator.abandonLeave();
      });
    },
    leave: (destination: FeatureIntroExitDestination): void => {
      if (destination === 'startup_welcome') {
        router.pushUrl({ url: STARTUP_WELCOME_INTRO_ROUTE }).catch((_error: Error) => {
          this.busy = false;
          this.coordinator.abandonLeave();
        });
        return;
      }
      finishOnboardingToBrowser();
      this.busy = false;
      this.coordinator.abandonLeave();
    }
  };
  private readonly coordinator: FeatureIntroAppearanceCoordinator = new FeatureIntroAppearanceCoordinator(this.host);

  aboutToAppear(): void {
    this.selectedThemeMode = sharedBrowserThemeModeCoordinator.resolveCurrentMode();
    this.selectedPaletteId = this.viewModel.defaultPaletteId();
    this.selectedTabStyle = this.viewModel.defaultTabStyle();
    this.syncPreviewTheme();
  }

  onPageShow(): void {
    this.busy = false;
    this.coordinator.abandonLeave();
    this.readTopInset();
    this.syncPreviewTheme();
  }

  onBackPress(): boolean {
    if (!this.busy) {
      returnToPreviousOnboardingStep('appearance');
    }
    return true;
  }

  build() {
    Column() {
      FeatureIntroSkipControl({
        label: this.viewModel.skipLabel(),
        leadingLabel: this.viewModel.previousLabel(),
        topInsetVp: this.topInset,
        skipEnabled: !this.busy,
        onConfirm: (): void => {
          this.skipSetup();
        },
        onLeading: (): void => {
          this.returnToHomepage();
        }
      })

      Scroll() {
        Column() {
          Text(this.viewModel.title())
            .width('100%')
            .fontSize(26)
            .lineHeight(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.previewPrimaryTextColor)
            .textAlign(TextAlign.Center)

          Text(this.viewModel.subtitle())
            .width('100%')
            .fontSize(15)
            .lineHeight(23)
            .fontColor(this.previewSecondaryTextColor)
            .textAlign(TextAlign.Center)
            .margin({ top: 10 })

          this.buildThemeModeTabs()
          this.buildThemeSection()
          this.buildTabSection()
        }
        .width('100%')
        .constraintSize({ maxWidth: FEATURE_INTRO_APPEARANCE_CONTENT_MAX_WIDTH })
        .padding({
          left: FEATURE_INTRO_APPEARANCE_HORIZONTAL_PADDING,
          right: FEATURE_INTRO_APPEARANCE_HORIZONTAL_PADDING,
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
    .backgroundColor(this.previewPageBackgroundColor)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildThemeModeTabs() {
    Row({ space: 4 }) {
      ForEach(this.viewModel.themeModes(this.selectedThemeMode), (choice: FeatureIntroAppearanceThemeModeChoice) => {
        Row({ space: 6 }) {
          SymbolGlyph(sharedBrowserThemeModeCoordinator.resolveMenuIcon(choice.mode))
            .fontSize(16)
            .fontColor([choice.isSelected ? this.previewOnAccentColor : this.previewPrimaryTextColor])

          Text(choice.title)
            .fontSize(14)
            .fontWeight(choice.isSelected ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(choice.isSelected ? this.previewOnAccentColor : this.previewPrimaryTextColor)
            .maxLines(1)
        }
        .layoutWeight(1)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .borderRadius(20)
        .backgroundColor(choice.isSelected ? this.previewAccentColor : Color.Transparent)
        .onClick((): void => {
          this.selectThemeMode(choice.mode);
        })
      }, (choice: FeatureIntroAppearanceThemeModeChoice) => `${choice.mode}:${choice.isSelected ? 'selected' : 'idle'}`)
    }
    .width('100%')
    .padding(4)
    .margin({ top: 22 })
    .borderRadius(24)
    .backgroundColor(this.previewSurfaceBackgroundColor)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildThemeSection() {
    Column({ space: 14 }) {
      Text(this.viewModel.themeSectionTitle())
        .width('100%')
        .fontSize(13)
        .fontColor(this.previewSecondaryTextColor)

      Grid() {
        ForEach(this.viewModel.palettes(this.selectedPaletteId), (choice: FeatureIntroAppearancePaletteChoice) => {
          GridItem() {
            this.buildPaletteChoice(choice)
          }
        }, (choice: FeatureIntroAppearancePaletteChoice) => `${choice.id}:${choice.isSelected ? 'selected' : 'idle'}`)
      }
      .width('100%')
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(12)
      .rowsGap(16)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 28 })
  }

  @Builder
  private buildPaletteChoice(choice: FeatureIntroAppearancePaletteChoice) {
    Column({ space: 8 }) {
      Stack() {
        Row()
          .width(FEATURE_INTRO_APPEARANCE_SWATCH_SIZE)
          .height(FEATURE_INTRO_APPEARANCE_SWATCH_SIZE)
          .borderRadius(FEATURE_INTRO_APPEARANCE_SWATCH_SIZE / 2)
          .backgroundColor(choice.previewColor)
      }
      .width(FEATURE_INTRO_APPEARANCE_SWATCH_SIZE + 8)
      .height(FEATURE_INTRO_APPEARANCE_SWATCH_SIZE + 8)
      .borderRadius((FEATURE_INTRO_APPEARANCE_SWATCH_SIZE + 8) / 2)
      .border({
        width: choice.isSelected ? 2 : 1,
        color: choice.isSelected ? this.previewAccentColor : this.previewSecondaryTextColor
      })
      .alignContent(Alignment.Center)

      Text(choice.title)
        .width('100%')
        .fontSize(13)
        .fontWeight(choice.isSelected ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.previewPrimaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onClick((): void => {
      this.selectPalette(choice.id);
    })
  }

  @Builder
  private buildTabSection() {
    Column({ space: 12 }) {
      Text(this.viewModel.tabSectionTitle())
        .width('100%')
        .fontSize(13)
        .fontColor(this.previewSecondaryTextColor)

      Row({ space: 8 }) {
        ForEach(this.viewModel.tabOptions(this.selectedTabStyle), (option: TabOverviewLayoutOptionState) => {
          TabOverviewLayoutOption({
            option: option,
            previewResource: this.resolvePreviewResource(option.style),
            accentColor: this.previewAccentColor,
            primaryTextColor: this.previewPrimaryTextColor,
            onSelect: (style: BrowserTabsOverviewLayoutStyle): void => {
              this.selectTabStyle(style);
            }
          })
            .layoutWeight(1)
        }, (option: TabOverviewLayoutOptionState) => `${option.style}:${option.isSelected ? 'selected' : 'idle'}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 28 })
  }

  @Builder
  private buildContinueButton() {
    Column() {
      Button(this.viewModel.continueLabel())
        .width('100%')
        .height(FEATURE_INTRO_APPEARANCE_ACTION_HEIGHT)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.previewOnAccentColor)
        .backgroundColor(this.previewAccentColor)
        .borderRadius(FEATURE_INTRO_APPEARANCE_ACTION_HEIGHT / 2)
        .stateEffect(false)
        .enabled(!this.busy)
        .opacity(this.busy ? 0.58 : 1)
        .onClick((): void => {
          this.continueWithSelection();
        })
    }
    .width('100%')
    .constraintSize({ maxWidth: FEATURE_INTRO_APPEARANCE_CONTENT_MAX_WIDTH })
    .padding({
      left: FEATURE_INTRO_APPEARANCE_HORIZONTAL_PADDING,
      right: FEATURE_INTRO_APPEARANCE_HORIZONTAL_PADDING,
      bottom: 24
    })
  }

  private selectThemeMode(mode: BrowserThemeMode): void {
    if (this.busy || this.selectedThemeMode === mode) {
      return;
    }
    const previousMode = this.selectedThemeMode;
    this.selectedThemeMode = mode;
    sharedBrowserThemeModeCoordinator.setThemeMode(mode)
      .then((): void => {
        this.syncPreviewTheme();
      })
      .catch((_error: Error): void => {
        this.selectedThemeMode = previousMode;
      });
  }

  private selectPalette(paletteId: BrowserThemePaletteId): void {
    if (this.busy) {
      return;
    }
    this.selectedPaletteId = paletteId;
    this.syncPreviewTheme();
  }

  private selectTabStyle(style: BrowserTabsOverviewLayoutStyle): void {
    if (this.busy) {
      return;
    }
    this.selectedTabStyle = style;
  }

  private continueWithSelection(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.coordinator.continueWith(this.selectedPaletteId, this.selectedTabStyle);
  }

  private skipSetup(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.coordinator.skip();
  }

  private returnToHomepage(): void {
    if (this.busy) {
      return;
    }
    returnToPreviousOnboardingStep('appearance');
  }

  private resolvePreviewResource(style: BrowserTabsOverviewLayoutStyle): Resource {
    if (style === 'horizontal_cards') {
      return this.storedResolvedThemeMode === 'dark' ?
        $r('app.media.tab_overview_large_cards_dark') : $r('app.media.tab_overview_large_cards_light');
    }
    if (style === 'stack') {
      return this.storedResolvedThemeMode === 'dark' ?
        $r('app.media.tab_overview_stack_dark') : $r('app.media.tab_overview_stack_light');
    }
    return this.storedResolvedThemeMode === 'dark' ?
      $r('app.media.tab_overview_grid_dark') : $r('app.media.tab_overview_grid_light');
  }

  private syncPreviewTheme(): void {
    const tokens = this.viewModel.previewTokens(this.selectedPaletteId, this.storedResolvedThemeMode);
    this.previewAccentColor = tokens.accent;
    this.previewOnAccentColor = tokens.onAccent;
    this.previewPageBackgroundColor = tokens.pageBackground;
    this.previewSurfaceBackgroundColor = tokens.surfaceBackground;
    this.previewPrimaryTextColor = tokens.textPrimary;
    this.previewSecondaryTextColor = tokens.textSecondary;
    this.syncStatusBarContentStyle();
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
      })
      .catch((_error: Error) => undefined);
  }
}
