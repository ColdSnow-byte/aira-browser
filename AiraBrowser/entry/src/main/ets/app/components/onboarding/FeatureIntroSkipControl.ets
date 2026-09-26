import { showCenteredAlertDialog } from '../common/CenteredDialogSurface';
import { FeatureIntroViewModel } from '../../../core/onboarding/FeatureIntroViewModel';
import { BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY } from '../../../core/theme/BrowserThemeStorageKeys';

@Component
export struct FeatureIntroSkipControl {
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @Prop label: string = '跳过';
  @Prop leadingLabel: string = '';
  @Prop topInsetVp: number = 0;
  @Prop skipEnabled: boolean = true;
  @Prop skipOpacity: number = 1;
  onConfirm: () => void = (): void => undefined;
  onLeading: () => void = (): void => undefined;

  build() {
    Row() {
      if (this.leadingLabel.length > 0) {
        Text(this.leadingLabel)
          .fontSize(14)
          .fontWeight(FontWeight.Regular)
          .fontColor(this.storedPrimaryTextColor)
          .padding({ left: 20, right: 16, top: 8, bottom: 8 })
          .opacity(this.skipEnabled ? 1 : 0.58)
          .onClick((): void => {
            if (this.skipEnabled) {
              this.onLeading();
            }
          })
      }

      Blank()
        .layoutWeight(1)

      Text(this.label)
        .fontSize(14)
        .fontWeight(FontWeight.Regular)
        .fontColor(this.storedPrimaryTextColor)
        .padding({ left: 16, right: 20, top: 8, bottom: 8 })
        .opacity(this.skipEnabled ? 1 : 0.58)
        .onClick((): void => {
          this.confirmSkip();
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .hitTestBehavior(HitTestMode.None)
    .margin({ top: this.topInsetVp + 4 })
    .opacity(this.skipOpacity)
  }

  private confirmSkip(): void {
    if (!this.skipEnabled) {
      return;
    }
    const viewModel = new FeatureIntroViewModel();
    showCenteredAlertDialog({
      title: viewModel.skipConfirmTitle(),
      message: viewModel.skipConfirmMessage(),
      autoCancel: true,
      primaryButton: {
        value: viewModel.skipConfirmCancelLabel(),
        action: (): void => undefined
      },
      secondaryButton: {
        value: viewModel.skipConfirmEnterLabel(),
        action: (): void => {
          this.onConfirm();
        }
      }
    });
  }
}
