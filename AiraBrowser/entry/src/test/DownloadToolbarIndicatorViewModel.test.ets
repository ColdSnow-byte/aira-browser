import { describe, expect, it } from '@ohos/hypium';
import { createDownloadV2TaskEntity, DownloadV2TaskEntity } from '../main/ets/domain/downloadv2/DownloadV2TaskEntity';
import { DownloadV2Status } from '../main/ets/domain/downloadv2/DownloadV2Types';
import { hasDesktopDownloadEntryActivity } from '../main/ets/core/download/DownloadToolbarIndicatorViewModel';

const SESSION_STARTED_AT: number = 1_000_000;

function task(status: DownloadV2Status, createdAt: number): DownloadV2TaskEntity {
  return createDownloadV2TaskEntity({
    guid: `${status}-${createdAt}`,
    profileId: 'profile-main',
    privacyMode: 'regular',
    dataScope: 'profile_persistent',
    request: { url: 'https://example.com/file', method: 'GET' },
    suggestedFileName: 'file.bin',
    status: status,
    progress: { receivedBytes: 0, totalBytes: 0, speedBytesPerSecond: 0 },
    timing: { createdAt: createdAt, updatedAt: createdAt }
  });
}

export default function downloadToolbarIndicatorViewModelTest(): void {
  describe('Desktop download toolbar entry', () => {
    it('stays hidden for downloads left over from an earlier launch', 0, () => {
      expect(hasDesktopDownloadEntryActivity([
        task('completed', SESSION_STARTED_AT - 10),
        task('paused', SESSION_STARTED_AT - 5)
      ], SESSION_STARTED_AT)).assertFalse();
    });

    it('appears for a download that starts during this launch, even after it finishes', 0, () => {
      expect(hasDesktopDownloadEntryActivity([
        task('completed', SESSION_STARTED_AT + 20)
      ], SESSION_STARTED_AT)).assertTrue();
    });

    it('appears when a download is still running, including one restored with the process', 0, () => {
      expect(hasDesktopDownloadEntryActivity([
        task('running', SESSION_STARTED_AT - 50)
      ], SESSION_STARTED_AT)).assertTrue();
    });
  });
}
