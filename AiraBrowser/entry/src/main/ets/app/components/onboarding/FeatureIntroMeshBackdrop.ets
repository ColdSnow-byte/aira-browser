const FEATURE_INTRO_MESH_REVEAL_DELAY_MS: number = 120;

/**
 * Wide intro slides keep a 9:8 phone video in the middle. This fills the
 * empty side bands with the same mesh gradient that sits inside that video.
 * The still frame stays up until playback has a picture, so the surface does
 * not flash black when the slides open.
 */
@Component
export struct FeatureIntroMeshBackdrop {
  @Prop topInsetVp: number = 0;
  @Prop heightVp: number = 0;
  @Prop @Watch('syncPlayback') playing: boolean = false;
  @State private shown: boolean = false;
  private readonly controller: VideoController = new VideoController();
  private ready: boolean = false;
  private revealTimer: number = -1;

  aboutToDisappear(): void {
    this.clearRevealTimer();
    this.controller.stop();
  }

  build() {
    Stack() {
      Image($rawfile('feature_intro_mesh_gradient_poster.jpg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Video({
        src: $rawfile('feature_intro_mesh_gradient.mp4'),
        controller: this.controller,
        previewUri: $rawfile('feature_intro_mesh_gradient_poster.jpg')
      })
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .backgroundColor(Color.Transparent)
        .muted(true)
        .controls(false)
        .loop(true)
        .autoPlay(false)
        .opacity(this.shown ? 1 : 0)
        .onPrepared((): void => {
          this.ready = true;
          this.syncPlayback();
        })
        .onStart((): void => {
          this.scheduleShown();
        })
    }
    .width('100%')
    .height(this.topInsetVp + this.heightVp)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  private syncPlayback(): void {
    if (!this.ready) {
      return;
    }
    if (this.playing) {
      this.controller.start();
      return;
    }
    this.controller.pause();
  }

  private scheduleShown(): void {
    if (this.shown || this.revealTimer >= 0) {
      return;
    }
    this.revealTimer = setTimeout((): void => {
      this.revealTimer = -1;
      if (this.playing) {
        this.shown = true;
      }
    }, FEATURE_INTRO_MESH_REVEAL_DELAY_MS);
  }

  private clearRevealTimer(): void {
    if (this.revealTimer >= 0) {
      clearTimeout(this.revealTimer);
      this.revealTimer = -1;
    }
  }
}
