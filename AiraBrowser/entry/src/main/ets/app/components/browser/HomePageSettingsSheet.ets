import { display } from '@kit.ArkUI';
import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';
import { desktopDialogTierSpec } from '../../../core/browser/BrowserDialogPresentationTokens';
import {
  BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { WallpaperMode } from '../../../common/models/WallpaperModels';
import { WallpaperSettingsCoordinator } from '../../../core/wallpaper/WallpaperSettingsCoordinator';
import { WallpaperSettingsViewState } from '../../../core/wallpaper/WallpaperSettingsViewModel';
import { sharedWallpaperRepository } from '../../bootstrap/BrowserAppRuntime';
import { HomeNativeSettingsContent } from '../settings/HomeNativeSettingsContent';
import { WallpaperSettingsContent } from '../wallpaper/WallpaperSettingsScreen';
import {
  BROWSER_FEATURE_SHEET_HEADER_BUTTON_SIZE,
  BROWSER_FEATURE_SHEET_HEADER_ICON_SIZE,
  BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING,
  BROWSER_SHEET_MODAL_HEADER_BUTTON_TOP,
  BrowserBottomSheetSurface,
  BrowserSheetIconButton
} from './BrowserModalBottomSheet';
import { BrowserLargeScreenModalHeader } from './BrowserLargeScreenModalHeader';
import { BrowserPhoneSettingsSheetHeader } from './BrowserPhoneSettingsSheetHeader';
import { CENTERED_DIALOG_SYSTEM_HUG_DEFINITE_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';

export type HomePageSettingsLayoutMode = 'phone' | 'large_screen';
type HomePageSettingsSheetPage = 'main' | 'wallpaper';
const HOME_PAGE_SHEET_POP_GUARD_MS: number = 450;
const HOME_SETTINGS_HEADER_ALLOWANCE_VP: number = 72;
const HOME_SETTINGS_PHONE_CHROME_VP: number = 96;
const HOME_SETTINGS_DIALOG_EDGE_VP: number = 48;
const HOME_SETTINGS_SCROLL_MIN_HEIGHT_VP: number = 280;

function readWindowHeightVp(): number {
  try {
    const metrics = display.getDefaultDisplaySync();
    if (!Number.isFinite(metrics.height) || metrics.height <= 0 ||
      !Number.isFinite(metrics.densityPixels) || metrics.densityPixels <= 0) {
      return 0;
    }
    return metrics.height / metrics.densityPixels;
  } catch (_error) {
    return 0;
  }
}

/** Scroll cap so a short settings page hugs its rows, while wallpaper can still scroll. */
export function resolveHomeSettingsScrollMaxHeightVp(layoutMode: HomePageSettingsLayoutMode): number {
  const windowHeight = readWindowHeightVp();
  if (layoutMode === 'large_screen') {
    const dialogCap = desktopDialogTierSpec('m').maxHeightVp;
    const usable = windowHeight > 0 ?
      Math.min(dialogCap, windowHeight - HOME_SETTINGS_DIALOG_EDGE_VP) : dialogCap;
    return Math.max(HOME_SETTINGS_SCROLL_MIN_HEIGHT_VP, usable - HOME_SETTINGS_HEADER_ALLOWANCE_VP);
  }
  const usable = windowHeight > 0 ? windowHeight - HOME_SETTINGS_PHONE_CHROME_VP : 640;
  return Math.max(HOME_SETTINGS_SCROLL_MIN_HEIGHT_VP, usable - HOME_SETTINGS_HEADER_ALLOWANCE_VP);
}

export function resolveHomeSettingsDialogMaxHeightVp(): number {
  return resolveHomeSettingsScrollMaxHeightVp('large_screen') + HOME_SETTINGS_HEADER_ALLOWANCE_VP;
}

/**
 * The system sheet and the large-screen dialog both receive back before the
 * page inside them. This lets that outer dismiss pop the wallpaper page first.
 */
class HomePageSettingsSheetNavigation {
  private consumeBack: (() => boolean) | undefined = undefined;

  bind(consumeBack: () => boolean): void {
    this.consumeBack = consumeBack;
  }

  unbind(consumeBack: () => boolean): void {
    if (this.consumeBack === consumeBack) {
      this.consumeBack = undefined;
    }
  }

  tryConsumeBack(): boolean {
    if (this.consumeBack === undefined) {
      return false;
    }
    return this.consumeBack();
  }
}

export const homePageSettingsSheetNavigation: HomePageSettingsSheetNavigation =
  new HomePageSettingsSheetNavigation();

@Component
export struct HomePageSettingsSheet {
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @Prop privateModeVisible: boolean = false;
  onWallpaperChanged: () => void = () => {};
  onClose: () => void = () => {};

  build() {
    BrowserBottomSheetSurface({
      fullHeight: false,
      horizontalPadding: 0,
      topPadding: 0,
      bottomPadding: 0,
      surfaceColor: this.storedPageBackgroundColor
    }) {
      HomePageSettingsContent({
        privateModeVisible: this.privateModeVisible,
        layoutMode: 'phone',
        onWallpaperChanged: this.onWallpaperChanged,
        onClose: this.onClose
      })
    }
  }
}

@CustomDialog
export struct HomePageSettingsDialog {
  controller?: CustomDialogController;
  @Link privateModeVisible: boolean;
  onWallpaperChanged: () => void = () => {};
  onClose: () => void = () => {};

  build() {
    Column() {
      HomePageSettingsContent({
        privateModeVisible: this.privateModeVisible,
        layoutMode: 'large_screen',
        onWallpaperChanged: this.onWallpaperChanged,
        onClose: this.onClose
      })
    }
    .width('100%')
    .attributeModifier(CENTERED_DIALOG_SYSTEM_HUG_DEFINITE_SURFACE_MODIFIER)
    .constraintSize({ maxHeight: resolveHomeSettingsDialogMaxHeightVp() })
  }
}

@Component
export struct HomePageSettingsContent {
  private wallpaperCoordinator: WallpaperSettingsCoordinator =
    new WallpaperSettingsCoordinator(sharedWallpaperRepository);
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY) private storedFloatingSurfaceColor: string = '#FFFFFF';
  @Prop privateModeVisible: boolean = false;
  @Prop layoutMode: HomePageSettingsLayoutMode = 'phone';
  onWallpaperChanged: () => void = () => {};
  onClose: () => void = () => {};
  @State private wallpaperState: WallpaperSettingsViewState = this.wallpaperCoordinator.getCurrentState();
  @State private sheetPage: HomePageSettingsSheetPage = 'main';
  @State private contentMaxHeightVp: number = HOME_SETTINGS_SCROLL_MIN_HEIGHT_VP;
  @State private settingsBodyHeightVp: number = 0;
  private mainSheetScroller: Scroller = new Scroller();
  private wallpaperSheetScroller: Scroller = new Scroller();
  private sheetNavigationPopGuardUntilMs: number = 0;
  private readonly consumeSheetBack: () => boolean = (): boolean => this.popSheetNavigation();

  aboutToAppear(): void {
    this.contentMaxHeightVp = resolveHomeSettingsScrollMaxHeightVp(this.layoutMode);
    this.refreshWallpaperState();
    homePageSettingsSheetNavigation.bind(this.consumeSheetBack);
  }

  aboutToDisappear(): void {
    homePageSettingsSheetNavigation.unbind(this.consumeSheetBack);
    this.resetSheetNavigation();
  }

  build() {
    if (this.layoutMode === 'large_screen') {
      this.buildLargeScreenPage()
    } else {
      this.buildPhonePage()
    }
  }

  @Builder
  private buildLargeScreenPage() {
    Column({ space: 0 }) {
      BrowserLargeScreenModalHeader({
        title: this.sheetPage === 'wallpaper' ? '壁纸设置' : '主页设置',
        dialogMode: true,
        showBackButton: this.sheetPage === 'wallpaper',
        onBack: (): void => {
          this.popSheetNavigation();
        },
        onClose: this.onClose
      })

      this.buildHuggingScroll(10, 32)
    }
    .width('100%')
    .backgroundColor(this.resolveSheetNavigationBackground())
    .clip(true)
  }

  @Builder
  private buildPhonePage() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 0 }) {
        this.buildPhoneHeader()
        this.buildHuggingScroll(4, BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING)
      }
      .width('100%')
      .padding({ top: 8 })

      this.buildPhoneCloseButton()
    }
    .width('100%')
    .backgroundColor(this.resolveSheetNavigationBackground())
  }

  @Builder
  private buildPhoneCloseButton() {
    BrowserSheetIconButton({
      icon: $r('sys.symbol.xmark'),
      iconSize: BROWSER_FEATURE_SHEET_HEADER_ICON_SIZE,
      buttonSize: BROWSER_FEATURE_SHEET_HEADER_BUTTON_SIZE,
      accessibilityLabel: '关闭主页设置',
      immersiveMaterialEnabled: true,
      onAction: (): void => {
        this.onClose();
      }
    })
    .margin({ top: BROWSER_SHEET_MODAL_HEADER_BUTTON_TOP, right: 16 })
    .zIndex(3)
  }

  @Builder
  private buildHuggingScroll(topPadding: number, bottomPadding: number) {
    Scroll(this.resolveSheetScroller(this.sheetPage)) {
      Column({ space: 16 }) {
        this.buildSettingsBody(this.sheetPage)
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: topPadding,
        bottom: bottomPadding
      })
      .alignItems(HorizontalAlign.Start)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.updateSettingsBodyHeight(newArea.height);
      })
    }
    .width('100%')
    .height(this.resolveHuggingScrollHeight())
    .constraintSize({ maxHeight: this.contentMaxHeightVp })
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
    .clip(this.layoutMode === 'large_screen')
  }

  @Builder
  private buildPhoneHeader() {
    BrowserPhoneSettingsSheetHeader({
      title: this.sheetPage === 'wallpaper' ? '壁纸设置' : '主页设置',
      showBackButton: this.sheetPage === 'wallpaper',
      backAccessibilityText: '返回主页设置',
      onBack: (): void => {
        this.popSheetNavigation();
      }
    })
  }

  @Builder
  private buildSettingsBody(page: HomePageSettingsSheetPage) {
    if (page === 'wallpaper') {
      WallpaperSettingsContent({
        state: this.wallpaperState,
        onModeSelect: (mode: WallpaperMode) => {
          this.applyWallpaperMode(mode);
        },
        onBingRetry: () => {
          this.retryBingPreview();
        }
      })
    } else {
      HomeNativeSettingsContent({
        isEnabled: true,
        iconAppearanceEnabled: !this.privateModeVisible,
        wallpaperLabel: this.wallpaperState.modeTitle,
        dialogPresentation: this.layoutMode === 'large_screen',
        onOpenWallpaperSettings: () => {
          this.openWallpaperSettings();
        }
      })
    }
  }

  private resolveSheetScroller(page: HomePageSettingsSheetPage): Scroller {
    return page === 'wallpaper' ? this.wallpaperSheetScroller : this.mainSheetScroller;
  }

  private resolveSheetNavigationBackground(): ResourceColor {
    return this.layoutMode === 'large_screen' ?
      this.storedFloatingSurfaceColor : this.storedPageBackgroundColor;
  }

  private openWallpaperSettings(): void {
    this.refreshWallpaperState();
    if (this.sheetPage === 'wallpaper') {
      return;
    }
    this.settingsBodyHeightVp = 0;
    this.sheetPage = 'wallpaper';
  }

  private popSheetNavigation(): boolean {
    const now = Date.now();
    if (now < this.sheetNavigationPopGuardUntilMs) {
      return true;
    }
    if (this.sheetPage !== 'wallpaper') {
      return false;
    }
    this.sheetNavigationPopGuardUntilMs = now + HOME_PAGE_SHEET_POP_GUARD_MS;
    this.settingsBodyHeightVp = 0;
    this.sheetPage = 'main';
    return true;
  }

  private resetSheetNavigation(): void {
    this.sheetNavigationPopGuardUntilMs = 0;
    this.settingsBodyHeightVp = 0;
    this.sheetPage = 'main';
  }

  private updateSettingsBodyHeight(height: Length): void {
    const parsed = Number.parseFloat(`${height}`);
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return;
    }
    const next = Math.ceil(parsed);
    if (next !== this.settingsBodyHeightVp) {
      this.settingsBodyHeightVp = next;
    }
  }

  private resolveHuggingScrollHeight(): Length {
    if (this.settingsBodyHeightVp <= 0) {
      return '';
    }
    return Math.min(this.settingsBodyHeightVp, this.contentMaxHeightVp);
  }

  private refreshWallpaperState(): void {
    this.wallpaperCoordinator.loadState((state: WallpaperSettingsViewState) => {
      this.wallpaperState = state;
    })
      .catch((_error: Error) => {
        this.wallpaperState = this.wallpaperCoordinator.getCurrentState();
      });
  }

  private applyWallpaperMode(mode: WallpaperMode): void {
    this.wallpaperCoordinator.selectMode(mode, (state: WallpaperSettingsViewState) => {
      this.wallpaperState = state;
    })
      .then((state: WallpaperSettingsViewState) => {
        this.wallpaperState = state;
        this.onWallpaperChanged();
      })
      .catch((error: Error) => {
        this.refreshWallpaperState();
        this.showToast(error.message.length > 0 ? error.message : '选择壁纸失败，请稍后重试。');
      });
  }

  private retryBingPreview(): void {
    this.wallpaperCoordinator.retryBingPreview((state: WallpaperSettingsViewState) => {
      this.wallpaperState = state;
    })
      .then((state: WallpaperSettingsViewState) => {
        this.wallpaperState = state;
        this.onWallpaperChanged();
      })
      .catch((_error: Error) => {
        this.wallpaperState = this.wallpaperCoordinator.getCurrentState();
      });
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1800
      });
    } catch (_error) {
    }
  }
}
