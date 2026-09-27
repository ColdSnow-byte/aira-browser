function featureIntroPoster(slideId: string): Resource {
  if (slideId === 'ad_block') {
    return $rawfile('feature_intro_ad_block_poster.jpg');
  }
  if (slideId === 'video_takeover') {
    return $rawfile('feature_intro_video_takeover_poster.jpg');
  }
  if (slideId === 'user_scripts') {
    return $rawfile('feature_intro_user_scripts_poster.jpg');
  }
  return $rawfile('feature_intro_sync_poster.jpg');
}

/** Phone artwork starts about a quarter of the way in, so the fade stays outside it. */
const FEATURE_INTRO_CONTAINED_EDGE_FADE: number = 0.2;

function featureIntroVideo(slideId: string): Resource {
  if (slideId === 'ad_block') {
    return $rawfile('feature_intro_ad_block.mp4');
  }
  if (slideId === 'video_takeover') {
    return $rawfile('feature_intro_video_takeover.mp4');
  }
  if (slideId === 'user_scripts') {
    return $rawfile('feature_intro_user_scripts.mp4');
  }
  return $rawfile('feature_intro_sync.mp4');
}

@Component
export struct FeatureIntroSlideVideo {
  slideId: string = '';
  controller: VideoController = new VideoController();
  @Prop shown: boolean = false;
  /** Keep the whole 9:8 frame visible instead of cropping a short wide slot. */
  @Prop contain: boolean = false;
  onPrepared: () => void = (): void => undefined;
  onStart: () => void = (): void => undefined;

  build() {
    Stack() {
      Image(featureIntroPoster(this.slideId))
        .width('100%')
        .height('100%')
        .objectFit(this.contain ? ImageFit.Contain : ImageFit.Cover)
      Video({
        src: featureIntroVideo(this.slideId),
        controller: this.controller,
        previewUri: featureIntroPoster(this.slideId)
      })
        .width('100%')
        .height('100%')
        .objectFit(this.contain ? ImageFit.Contain : ImageFit.Cover)
        .muted(true)
        .controls(false)
        .loop(true)
        .autoPlay(false)
        .opacity(this.shown ? 1 : 0)
        .onPrepared((): void => {
          this.onPrepared();
        })
        .onStart((): void => {
          this.onStart();
        })

      if (this.contain) {
        Column()
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.None)
          .linearGradient({
            direction: GradientDirection.Right,
            colors: [
              [Color.Transparent, 0],
              [Color.Black, FEATURE_INTRO_CONTAINED_EDGE_FADE],
              [Color.Black, 1 - FEATURE_INTRO_CONTAINED_EDGE_FADE],
              [Color.Transparent, 1]
            ]
          })
          .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
      }
    }
    .width('100%')
    .height('100%')
    .blendMode(this.contain ? BlendMode.SRC_OVER : BlendMode.NONE, BlendApplyType.OFFSCREEN)
  }
}
