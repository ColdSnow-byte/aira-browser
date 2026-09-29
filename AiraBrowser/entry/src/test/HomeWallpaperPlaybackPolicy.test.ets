import { describe, expect, it } from '@ohos/hypium';
import {
  HomeWallpaperPlaybackInput,
  shouldPlayHomeWallpaperVideo
} from '../main/ets/services/wallpaper/HomeWallpaperPlaybackPolicy';

function settledHome(): HomeWallpaperPlaybackInput {
  return {
    pageForeground: true,
    showHomePage: true,
    showTabsSheet: false,
    revealSettled: true
  };
}

export default function homeWallpaperPlaybackPolicyTest(): void {
  describe('HomeWallpaperPlaybackPolicy', () => {
    it('plays_only_on_a_settled_foreground_homepage', 0, () => {
      expect(shouldPlayHomeWallpaperVideo(settledHome())).assertTrue();

      const covered: HomeWallpaperPlaybackInput = settledHome();
      covered.pageForeground = false;
      expect(shouldPlayHomeWallpaperVideo(covered)).assertFalse();

      const webPage: HomeWallpaperPlaybackInput = settledHome();
      webPage.showHomePage = false;
      expect(shouldPlayHomeWallpaperVideo(webPage)).assertFalse();

      const tabs: HomeWallpaperPlaybackInput = settledHome();
      tabs.showTabsSheet = true;
      expect(shouldPlayHomeWallpaperVideo(tabs)).assertFalse();

      const revealing: HomeWallpaperPlaybackInput = settledHome();
      revealing.revealSettled = false;
      expect(shouldPlayHomeWallpaperVideo(revealing)).assertFalse();
    });
  });
}
