export interface HomeWallpaperPlaybackInput {
  pageForeground: boolean;
  showHomePage: boolean;
  showTabsSheet: boolean;
  revealSettled: boolean;
}

/**
 * Play only while the homepage is the stable foreground.
 * A reveal, a pushed page, or the tab overview must not start the surface:
 * creating or uncovering Video during those transitions is the flash.
 */
export function shouldPlayHomeWallpaperVideo(input: HomeWallpaperPlaybackInput): boolean {
  return input.pageForeground &&
    input.showHomePage &&
    !input.showTabsSheet &&
    input.revealSettled;
}

const HOME_WALLPAPER_PLAYBACK_TRANSITION_DELAY_MS: number = 400;

export type HomeWallpaperPlaybackCommit = (enabled: boolean) => void;

/**
 * Delays pause across the outgoing page transition.
 *
 * The push still shows this page, so the pause waits until the next page has
 * covered it. Resume is immediate: a delayed resume lets that pause land after
 * the homepage is already visible and hides the frame the user is looking at.
 */
export class HomeWallpaperPlaybackGate {
  private enabled: boolean = true;
  private suspendTimer: number = -1;

  isEnabled(): boolean {
    return this.enabled;
  }

  dispose(): void {
    this.cancelSuspend();
  }

  handlePageShow(commit: HomeWallpaperPlaybackCommit): void {
    this.cancelSuspend();
    if (this.enabled) {
      return;
    }
    this.enabled = true;
    commit(true);
  }

  handlePageHide(commit: HomeWallpaperPlaybackCommit): void {
    this.scheduleSuspend(commit);
  }

  private scheduleSuspend(commit: HomeWallpaperPlaybackCommit): void {
    this.cancelSuspend();
    this.suspendTimer = setTimeout((): void => {
      this.suspendTimer = -1;
      this.enabled = false;
      commit(false);
    }, HOME_WALLPAPER_PLAYBACK_TRANSITION_DELAY_MS);
  }

  private cancelSuspend(): void {
    if (this.suspendTimer < 0) {
      return;
    }
    clearTimeout(this.suspendTimer);
    this.suspendTimer = -1;
  }

}
