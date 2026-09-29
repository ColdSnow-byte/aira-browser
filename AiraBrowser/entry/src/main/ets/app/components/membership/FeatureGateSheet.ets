import {
  createHiddenFeatureGateSnapshot,
  FeatureGateAction,
  FeatureGateRenewalBenefitState,
  FeatureGateRenewalPlanState,
  FeatureGateRenewalState,
  FeatureGateSnapshot
} from '../../../core/membership/FeatureGateCoordinator';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_PALETTE_ID_KEY,
  BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY,
  BROWSER_THEME_STORAGE_SETTINGS_ICON_FOREGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { BrowserResolvedThemeMode, BrowserThemePaletteId } from '../../../common/models/BrowserModels';
import { BrowserThemePalette } from '../../../features/theme/BrowserThemePaletteModels';
import {
  BUILT_IN_THEME_PALETTES,
  DEFAULT_BROWSER_THEME_PALETTE_ID
} from '../../../features/theme/BrowserThemePalettes';
import { BrowserThemePaletteService } from '../../../services/theme/BrowserThemePaletteService';
import { AiraIcon } from '../common/AiraIcon';
import { SettingsColoredIconBackground } from '../settings/SettingsColoredIconBackground';
import {
  BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
  BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING,
  BrowserBottomSheetSurface,
  BrowserFeatureSheetHeader,
  BrowserImmersiveSheetLayout,
  BrowserSheetActionButton,
  browserSheetHeaderBlurModifier,
  resolveBrowserSheetHeaderBlurRadius
} from '../browser/BrowserModalBottomSheet';

const FEATURE_GATE_BENEFIT_ICON_TILE_SIZE: number = 32;
const FEATURE_GATE_BENEFIT_ICON_IMAGE_SIZE: number = 16;
const FEATURE_GATE_PLAN_RADIUS: number = 16;
const FEATURE_GATE_PLAN_BORDER_WIDTH: number = 1.5;
const FEATURE_GATE_FOOTER_CLEARANCE: number = 136;

@Component
export struct FeatureGateSheet {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY) private storedControlBackgroundColor: string = '#EEF2F7';
  @StorageProp(BROWSER_THEME_STORAGE_PALETTE_ID_KEY) private storedPaletteId: string = DEFAULT_BROWSER_THEME_PALETTE_ID;
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) private storedResolvedThemeMode: string = 'light';
  @StorageProp(BROWSER_THEME_STORAGE_SETTINGS_ICON_FOREGROUND_KEY) private storedSettingsIconForeground: string = '#FFFFFF';
  @Prop state: FeatureGateSnapshot = createHiddenFeatureGateSnapshot();
  @Prop layoutMode: 'phone' | 'large_screen' = 'phone';
  onAction: (action: FeatureGateAction) => void = (_action: FeatureGateAction) => {};
  onSelectPlan: (planId: string) => void = (_planId: string) => {};
  @State private sheetHeaderBlurRadius: number = 0;
  @State private sheetScrollOffset: number = 0;
  private readonly paletteService: BrowserThemePaletteService = new BrowserThemePaletteService();
  private readonly sheetBlurScroller: Scroller = new Scroller();

  build() {
    BrowserBottomSheetSurface({
      fullHeight: this.layoutMode === 'phone',
      presentation: this.layoutMode === 'large_screen' ? 'flat_content' : 'bottom_sheet',
      horizontalPadding: 0,
      topPadding: 0,
      bottomPadding: 0
    }) {
      if (this.layoutMode === 'phone') {
        this.buildImmersivePhoneLayout()
      } else {
        this.buildLargeScreenLayout()
      }
    }
  }

  @Builder
  private buildImmersivePhoneLayout() {
    BrowserImmersiveSheetLayout({
      footerVisible: true,
      footerBottomPadding: BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING,
      closeVisible: true,
      closeAccessibilityLabel: '关闭',
      onClose: (): void => {
        this.onAction('dismiss');
      },
      scrollContent: (): void => {
        this.buildPhoneScrollContent()
      },
      header: (): void => {
        this.buildPhoneHeader()
      },
      footer: (): void => {
        this.buildActions()
      }
    })
  }

  @Builder
  private buildPhoneHeader() {
    BrowserFeatureSheetHeader({
      title: this.state.title,
      titleColor: this.storedPrimaryTextColor
    })
  }

  @Builder
  private buildPhoneScrollContent() {
    Scroll(this.sheetBlurScroller) {
      Column({ space: 16 }) {
        this.buildMessage()

        if (this.state.renewal !== undefined) {
          this.buildRenewalContent(this.state.renewal)
        }
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({
        left: 16,
        right: 16,
        top: BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
        bottom: FEATURE_GATE_FOOTER_CLEARANCE
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .clip(false)
    .align(Alignment.Top)
    .attributeModifier(browserSheetHeaderBlurModifier(this.sheetHeaderBlurRadius))
    .onAppear((): void => {
      this.resetSheetHeaderBlur();
    })
    .onDidScroll((_xOffset: number, _yOffset: number): void => {
      this.noteSheetScrollOffset(this.sheetBlurScroller.currentOffset().yOffset);
    })
  }

  @Builder
  private buildLargeScreenLayout() {
    Column({ space: 16 }) {
      this.buildPhoneHeader()
      this.buildMessage()

      if (this.state.renewal !== undefined) {
        this.buildRenewalContent(this.state.renewal)
      }

      this.buildActions()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  private buildMessage() {
    Text(this.state.message)
      .width('100%')
      .fontSize(15)
      .lineHeight(22)
      .fontColor(this.storedSecondaryTextColor)
      .textAlign(TextAlign.Start)
  }

  @Builder
  private buildRenewalContent(renewal: FeatureGateRenewalState) {
    Column({ space: 16 }) {
      Column({ space: 2 }) {
        ForEach(renewal.benefits, (benefit: FeatureGateRenewalBenefitState, index: number) => {
          this.buildBenefitRow(benefit, index)
        }, (benefit: FeatureGateRenewalBenefitState) => benefit.id)
      }
      .width('100%')

      Column({ space: 10 }) {
        ForEach(renewal.plans, (plan: FeatureGateRenewalPlanState) => {
          this.buildPlanOption(plan, renewal.selectedPlanId === plan.id)
        }, (plan: FeatureGateRenewalPlanState) => plan.id)
      }
      .width('100%')

      Text(renewal.agreementText)
        .width('100%')
        .fontSize(12)
        .lineHeight(17)
        .fontColor(this.storedSecondaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  @Builder
  private buildActions() {
    Column({ space: 8 }) {
      BrowserSheetActionButton({
        label: this.state.primaryActionTitle,
        emphasis: 'primary',
        stacked: true,
        accentColor: this.storedAccentColor,
        onAction: (): void => {
          this.onAction(this.state.primaryAction);
        }
      })

      BrowserSheetActionButton({
        label: this.state.secondaryActionTitle,
        emphasis: 'ghost',
        stacked: true,
        onAction: (): void => {
          this.onAction(this.state.secondaryAction);
        }
      })
    }
    .width('100%')
  }

  private noteSheetScrollOffset(offset: number): void {
    if (!Number.isFinite(offset)) {
      return;
    }
    const next = Math.max(0, offset);
    if (next === this.sheetScrollOffset) {
      return;
    }
    this.sheetScrollOffset = next;
    this.sheetHeaderBlurRadius = resolveBrowserSheetHeaderBlurRadius(next);
  }

  private resetSheetHeaderBlur(): void {
    this.sheetScrollOffset = 0;
    this.sheetHeaderBlurRadius = 0;
  }

  @Builder
  private buildBenefitRow(benefit: FeatureGateRenewalBenefitState, index: number) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        SettingsColoredIconBackground({
          color: this.resolveBenefitIconBackground(index),
          iconSize: FEATURE_GATE_BENEFIT_ICON_TILE_SIZE
        })

        AiraIcon({
          airaIconId: benefit.iconId,
          iconSize: FEATURE_GATE_BENEFIT_ICON_IMAGE_SIZE,
          iconColor: this.storedSettingsIconForeground
        })
      }
      .width(FEATURE_GATE_BENEFIT_ICON_TILE_SIZE)
      .height(FEATURE_GATE_BENEFIT_ICON_TILE_SIZE)

      Text(benefit.title)
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedPrimaryTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  /**
   * Same price card language as the membership page: the selected plan is the
   * accent border, not a checkmark. Long-term sits first and starts selected.
   */
  @Builder
  private buildPlanOption(plan: FeatureGateRenewalPlanState, selected: boolean) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(plan.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedSecondaryTextColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text() {
          Span(plan.amountText)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.storedPrimaryTextColor)

          if (plan.periodText.length > 0) {
            Span(plan.periodText.startsWith('/') ? plan.periodText : ` ${plan.periodText}`)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.storedSecondaryTextColor)
          }
        }
        .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (plan.discountBadgeText.length > 0 || plan.originalPriceText.length > 0) {
        Column({ space: 4 }) {
          if (plan.discountBadgeText.length > 0) {
            Text(plan.discountBadgeText)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.storedAccentColor)
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor(this.storedControlBackgroundColor)
              .borderRadius(7)
              .maxLines(1)
          }
          if (plan.originalPriceText.length > 0) {
            Text(plan.originalPriceText)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.storedSecondaryTextColor)
              .decoration({
                type: TextDecorationType.LineThrough,
                color: this.storedSecondaryTextColor
              })
              .maxLines(1)
          }
        }
        .alignItems(HorizontalAlign.End)
      } else if (plan.badgeText.length > 0) {
        Text(plan.badgeText)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedAccentColor)
          .maxLines(1)
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(FEATURE_GATE_PLAN_RADIUS)
    .backgroundColor(this.storedControlBackgroundColor)
    .border({
      width: FEATURE_GATE_PLAN_BORDER_WIDTH,
      color: selected ? this.storedAccentColor : this.storedDividerColor
    })
    .onClick(() => {
      this.onSelectPlan(plan.id);
    })
  }

  private resolveBenefitIconBackground(index: number): string {
    const mode: BrowserResolvedThemeMode = this.storedResolvedThemeMode === 'dark' ? 'dark' : 'light';
    const backgrounds = this.paletteService.resolveTokens(this.resolvePaletteId(), mode).settingsIconBackgrounds;
    const colors: string[] = [
      backgrounds.sync,
      backgrounds.crossDeviceLink,
      backgrounds.bookmarks,
      backgrounds.history,
      backgrounds.siteSettings,
      backgrounds.experiments
    ];
    return colors[index % colors.length];
  }

  private resolvePaletteId(): BrowserThemePaletteId {
    const match = BUILT_IN_THEME_PALETTES.find((palette: BrowserThemePalette): boolean => {
      return palette.id === this.storedPaletteId;
    });
    if (match === undefined) {
      return DEFAULT_BROWSER_THEME_PALETTE_ID;
    }
    return match.id;
  }
}
