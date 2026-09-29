import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_ON_ACCENT_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { BrowserSheetActionButton } from '../browser/BrowserModalBottomSheet';
import {
  CENTERED_DIALOG_CORNER_RADIUS_VP,
  CENTERED_DIALOG_HORIZONTAL_MARGIN_VP,
  CENTERED_DIALOG_MAX_WIDTH_VP,
  resolveCenteredDialogSurfaceColor
} from '../common/CenteredDialogSurface';

const OFFER_ART_ASPECT_RATIO: number = 1125 / 500;
const OFFER_MARK_FONT_SIZE: number = 64;
const OFFER_MARK_UNIT_FONT_SIZE: number = 20;

/**
 * The 15-day claim dialog's frame, with the National Day art and a one-time
 * lifetime purchase instead of a free grant.
 */
@CustomDialog
export struct AiraProNationalDayOfferDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_ON_ACCENT_KEY) private storedOnAccentColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  controller?: CustomDialogController;
  onPurchase: () => void = () => {};

  build() {
    Column() {
      Image($r('app.media.national_day_offer_card'))
        .width('100%')
        .aspectRatio(OFFER_ART_ASPECT_RATIO)
        .objectFit(ImageFit.Cover)
        .draggable(false)

      Column({ space: 16 }) {
        Column({ space: 0 }) {
          this.buildOfferMark()

          Text('国庆特惠长期会员')
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.storedSecondaryTextColor)
            .textAlign(TextAlign.Center)
            .margin({ top: 2 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Text('原价¥68.8，10月7日前')
          .width('100%')
          .fontSize(13)
          .lineHeight(18)
          .fontColor(this.storedSecondaryTextColor)
          .textAlign(TextAlign.Center)
          .maxLines(2)

        Column({ space: 8 }) {
          BrowserSheetActionButton({
            label: '¥48 立即购买长期会员',
            emphasis: 'primary',
            stacked: true,
            accentColor: this.storedAccentColor,
            textColor: this.storedOnAccentColor,
            buttonHeight: 44,
            fontSize: 15,
            onAction: () => {
              this.onPurchase();
            }
          })

          BrowserSheetActionButton({
            label: '稍后',
            emphasis: 'ghost',
            stacked: true,
            buttonHeight: 44,
            fontSize: 15,
            onAction: () => {
              this.controller?.close();
            }
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: 16,
        bottom: 16
      })
    }
    .width(`calc(100% - ${CENTERED_DIALOG_HORIZONTAL_MARGIN_VP * 2}vp)`)
    .constraintSize({ maxWidth: CENTERED_DIALOG_MAX_WIDTH_VP })
    .backgroundColor(resolveCenteredDialogSurfaceColor())
    .borderRadius(CENTERED_DIALOG_CORNER_RADIUS_VP)
    .clip(true)
  }

  @Builder
  private buildOfferMark() {
    Row() {
      Text('7')
        .fontSize(OFFER_MARK_FONT_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .lineHeight(OFFER_MARK_FONT_SIZE)

      Text('折')
        .fontSize(OFFER_MARK_UNIT_FONT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedPrimaryTextColor)
        .margin({ left: 2, bottom: 10 })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Bottom)
  }
}
