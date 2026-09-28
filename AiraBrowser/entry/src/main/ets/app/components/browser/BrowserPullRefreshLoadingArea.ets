import { BrowserPullRefreshPresentation } from '../../../core/browser/BrowserPullRefreshModels';

const PULL_REFRESH_MIN_HEIGHT_VP: number = 48;
const PULL_REFRESH_INDICATOR_SIZE_VP: number = 24;

@Component
export struct BrowserPullRefreshLoadingArea {
  @Prop presentation: BrowserPullRefreshPresentation;
  @Prop accentColor: ResourceColor = '#0A59F7';
  @Prop surfaceColor: ResourceColor = '#FFFFFF';

  build() {
    // Width without a fixed height lets Refresh size this slot to the pull distance.
    // Do not bind that distance to shell state; doing so rebuilds the page on every sample.
    Stack({ alignContent: Alignment.Center }) {
      LoadingProgress()
        .width(PULL_REFRESH_INDICATOR_SIZE_VP)
        .height(PULL_REFRESH_INDICATOR_SIZE_VP)
        .color(this.accentColor)
        .freeze(!this.presentation.enableLoading)
    }
    .width('100%')
    .clip(true)
    .padding({ top: this.resolveTopPadding() })
    .constraintSize({ minHeight: PULL_REFRESH_MIN_HEIGHT_VP })
    .backgroundColor(this.surfaceColor)
    .hitTestBehavior(HitTestMode.None)
  }

  private resolveTopPadding(): number {
    if (!Number.isFinite(this.presentation.topPlaceHolderHeight) ||
      this.presentation.topPlaceHolderHeight <= 0) {
      return 0;
    }
    return Math.round(this.presentation.topPlaceHolderHeight);
  }
}
