import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import { BrowserHomePageStyle } from '../../common/models/HomePagePresentationSettingsModels';
import { ShortcutRecord } from '../../common/models/BrowserModels';
import { FeatureIntroHomepageCoordinator } from '../../core/onboarding/FeatureIntroHomepageCoordinator';
import {
  FeatureIntroHomepageViewModel,
  resolveFeatureIntroHomepageStyle
} from '../../core/onboarding/FeatureIntroHomepageViewModel';
import { FeatureIntroHost } from '../../core/onboarding/FeatureIntroCoordinator';
import { FeatureIntroExitDestination } from '../../core/onboarding/FeatureIntroRoutePolicy';
import {
  CustomHomepagePreviewLayoutState,
  CustomHomepagePreviewViewModel
} from '../../core/customhome/CustomHomepagePreviewViewModel';
import { CustomHomepageEnvironmentService } from '../../services/customhome/CustomHomepageEnvironmentService';
import { CustomHomepagePicker } from '../components/customhome/CustomHomepagePicker';
import { FeatureIntroSkipControl } from '../components/onboarding/FeatureIntroSkipControl';
import { sharedShortcutIconResolverService, sharedShortcutRepository } from '../bootstrap/BrowserAppRuntime';
import { HomeShortcutLogicService } from '../../services/shortcuts/HomeShortcutLogicService';
import { BrowserStatusBarStyleService } from '../../services/browser/BrowserStatusBarStyleService';
import { SettingsTopSafeInsetService } from '../../services/settings/SettingsTopSafeInsetService';
import { BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY } from '../../core/theme/BrowserThemeStorageKeys';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_ON_ACCENT_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../core/theme/BrowserThemeStorageKeys';
import { BROWSER_SHELL_ROUTE, STARTUP_WELCOME_INTRO_ROUTE } from '../router/AppRoutes';

const FEATURE_INTRO_HOMEPAGE_HORIZONTAL_PADDING: number = 24;
const FEATURE_INTRO_HOMEPAGE_CONTENT_MAX_WIDTH: number = 430;
const FEATURE_INTRO_HOMEPAGE_ACTION_HEIGHT: number = 40;

@Entry
@Component
struct FeatureIntroHomepagePage {
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = '#F2F3F5';
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_ON_ACCENT_KEY) private storedOnAccentColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6368';
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) @Watch('syncStatusBarContentStyle')
  private storedResolvedThemeMode: string = 'light';
  @State private selectedStyle: BrowserHomePageStyle = 'classic';
  @State private focusedIndex: number = 0;
  @State private busy: boolean = false;
  @State private topInset: number = 0;
  @State private previewViewportWidth: number = 390;
  @State private previewViewportHeight: number = 844;
  @State private previewAvailableWidth: number = 0;
  @State private pickerBodyHeight: number = 0;
  @State private previewShortcuts: ShortcutRecord[] = [];
  @State private previewRevision: number = 0;
  @State private previewLayoutState: CustomHomepagePreviewLayoutState = new CustomHomepagePreviewViewModel()
    .buildCarouselLayoutState({
      viewportWidth: 390,
      viewportHeight: 844,
      availableWidth: 358,
      availableHeight: 640
    });
  private readonly viewModel: FeatureIntroHomepageViewModel = new FeatureIntroHomepageViewModel();
  private readonly previewViewModel: CustomHomepagePreviewViewModel = new CustomHomepagePreviewViewModel();
  private readonly environmentService: CustomHomepageEnvironmentService = new CustomHomepageEnvironmentService();
  private readonly topSafeInsetService: SettingsTopSafeInsetService = new SettingsTopSafeInsetService();
  private readonly statusBarStyleService: BrowserStatusBarStyleService = new BrowserStatusBarStyleService();
  private readonly shortcutLogicService: HomeShortcutLogicService = new HomeShortcutLogicService();
  private readonly host: FeatureIntroHost = {
    leave: (destination: FeatureIntroExitDestination): void => {
      router.clear();
      router.replaceUrl({ url: this.resolveExitRoute(destination) }).catch((_error: Error) => {
        this.busy = false;
        this.coordinator.abandonLeave();
      });
    }
  };
  private readonly coordinator: FeatureIntroHomepageCoordinator = new FeatureIntroHomepageCoordinator(this.host);

  aboutToAppear(): void {
    this.selectedStyle = this.viewModel.defaultStyle();
    this.syncStatusBarContentStyle();
    this.loadPreviewShortcuts();
  }

  onPageShow(): void {
    this.busy = false;
    this.coordinator.abandonLeave();
    this.readTopInset();
    this.refreshPreviewWindowViewport();
    this.syncStatusBarContentStyle();
  }

  onBackPress(): boolean {
    if (!this.busy) {
      router.back();
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
          this.returnToSearchEngine();
        }
      })

      Text(this.viewModel.title())
        .width('100%')
        .padding({ left: FEATURE_INTRO_HOMEPAGE_HORIZONTAL_PADDING, right: FEATURE_INTRO_HOMEPAGE_HORIZONTAL_PADDING })
        .fontSize(26)
        .lineHeight(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })

      Text(this.viewModel.subtitle())
        .width('100%')
        .padding({
          left: FEATURE_INTRO_HOMEPAGE_HORIZONTAL_PADDING,
          right: FEATURE_INTRO_HOMEPAGE_HORIZONTAL_PADDING
        })
        .fontSize(15)
        .lineHeight(23)
        .fontColor(this.storedSecondaryTextColor)
        .textAlign(TextAlign.Center)
        .margin({ top: 10 })

      CustomHomepagePicker({
        cards: this.viewModel.cards(this.selectedStyle),
        layoutState: this.previewLayoutState,
        shortcuts: this.previewShortcuts,
        showShortcuts: true,
        previewRevision: this.previewRevision,
        pageBackground: this.storedPageBackgroundColor,
        focusedIndex: this.focusedIndex,
        busy: this.busy,
        applyVisible: false,
        onCardFocus: (index: number): void => {
          this.focusCard(index);
        }
      })
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 28 })
        .onAreaChange((_oldArea: Area, newArea: Area): void => {
          this.updatePickerArea(newArea);
        })

      this.buildContinueButton()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.storedPageBackgroundColor)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildContinueButton() {
    Column() {
      Button(this.viewModel.continueLabel())
        .width('100%')
        .height(FEATURE_INTRO_HOMEPAGE_ACTION_HEIGHT)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedOnAccentColor)
        .backgroundColor(this.storedAccentColor)
        .borderRadius(FEATURE_INTRO_HOMEPAGE_ACTION_HEIGHT / 2)
        .stateEffect(false)
        .enabled(!this.busy)
        .opacity(this.busy ? 0.58 : 1)
        .onClick((): void => {
          this.continueWithSelection();
        })
    }
    .width('100%')
    .constraintSize({ maxWidth: FEATURE_INTRO_HOMEPAGE_CONTENT_MAX_WIDTH })
    .padding({
      left: FEATURE_INTRO_HOMEPAGE_HORIZONTAL_PADDING,
      right: FEATURE_INTRO_HOMEPAGE_HORIZONTAL_PADDING,
      bottom: 24
    })
  }

  private continueWithSelection(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.coordinator.continueWith(this.selectedStyle);
  }

  private skipSetup(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.coordinator.skip();
  }

  private focusCard(index: number): void {
    const cards = this.viewModel.cards(this.selectedStyle);
    if (this.busy || index < 0 || index >= cards.length) {
      return;
    }
    this.focusedIndex = index;
    this.selectedStyle = resolveFeatureIntroHomepageStyle(cards[index].systemStyle);
  }

  private returnToSearchEngine(): void {
    if (this.busy) {
      return;
    }
    router.back();
  }

  private resolveExitRoute(destination: FeatureIntroExitDestination): string {
    return destination === 'startup_welcome' ? STARTUP_WELCOME_INTRO_ROUTE : BROWSER_SHELL_ROUTE;
  }

  private refreshPreviewLayoutState(): void {
    const availableHeight = this.pickerBodyHeight > 0 ?
      this.pickerBodyHeight :
      Math.max(320, this.previewViewportHeight - 120);
    this.previewLayoutState = this.previewViewModel.buildCarouselLayoutState({
      viewportWidth: this.previewViewportWidth,
      viewportHeight: this.previewViewportHeight,
      availableWidth: this.previewAvailableWidth > 0 ? this.previewAvailableWidth : this.previewViewportWidth,
      availableHeight: availableHeight
    });
  }

  private refreshPreviewWindowViewport(): void {
    this.environmentService.resolveCurrentWindowViewport()
      .then((viewport) => {
        if (viewport === undefined ||
          (viewport.width === this.previewViewportWidth && viewport.height === this.previewViewportHeight)) {
          return;
        }
        this.previewViewportWidth = viewport.width;
        this.previewViewportHeight = viewport.height;
        this.refreshPreviewLayoutState();
      })
      .catch((_error: Error) => undefined);
  }

  private updatePickerArea(area: Area): void {
    const nextHeight = this.parseAreaDimension(area.height);
    const nextWidth = this.parseAreaDimension(area.width);
    let changed = false;
    if (nextHeight !== this.pickerBodyHeight) {
      this.pickerBodyHeight = nextHeight;
      changed = true;
    }
    if (nextWidth !== this.previewAvailableWidth) {
      this.previewAvailableWidth = nextWidth;
      changed = true;
    }
    if (changed) {
      this.refreshPreviewLayoutState();
    }
  }

  private parseAreaDimension(value: Length): number {
    const parsed = Number.parseFloat(`${value}`);
    return Number.isFinite(parsed) ? Math.max(1, Math.round(parsed)) : 1;
  }

  private loadPreviewShortcuts(): void {
    sharedShortcutRepository.initialize()
      .then((): Promise<ShortcutRecord[]> => sharedShortcutRepository.refresh())
      .then((shortcuts: ShortcutRecord[]): void => {
        this.publishPreviewShortcuts(shortcuts);
      })
      .catch((_error: Error): void => {
        this.publishPreviewShortcuts(sharedShortcutRepository.listAll());
      });
  }

  private publishPreviewShortcuts(shortcuts: ShortcutRecord[]): void {
    const visibleShortcuts = this.shortcutLogicService.filterAppOwnedShortcuts(shortcuts);
    this.previewShortcuts = visibleShortcuts;
    this.previewRevision = this.previewRevision + 1;
    visibleShortcuts.forEach((shortcut: ShortcutRecord): void => {
      void sharedShortcutIconResolverService.resolveShortcutIcon(shortcut)
        .then((resolved): void => {
          const iconPath = resolved?.path ?? '';
          if (iconPath.length === 0) {
            return;
          }
          this.applyPreviewShortcutIcon(shortcut.id, iconPath);
        });
    });
  }

  private applyPreviewShortcutIcon(shortcutId: string, iconPath: string): void {
    let changed = false;
    const nextShortcuts: ShortcutRecord[] = [];
    this.previewShortcuts.forEach((shortcut: ShortcutRecord): void => {
      if (shortcut.id !== shortcutId || (shortcut.icon ?? '') === iconPath) {
        nextShortcuts.push(shortcut);
        return;
      }
      changed = true;
      const nextShortcut: ShortcutRecord = shortcut;
      nextShortcut.icon = iconPath;
      nextShortcuts.push(nextShortcut);
    });
    if (!changed) {
      return;
    }
    this.previewShortcuts = nextShortcuts;
    this.previewRevision = this.previewRevision + 1;
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
