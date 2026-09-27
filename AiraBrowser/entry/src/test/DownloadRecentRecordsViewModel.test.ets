import { describe, expect, it } from '@ohos/hypium';
import { createDownloadV2TaskEntity, DownloadV2TaskEntity } from '../main/ets/domain/downloadv2/DownloadV2TaskEntity';
import { DownloadV2Status } from '../main/ets/domain/downloadv2/DownloadV2Types';
import {
  DOWNLOAD_RECENT_ACTIVE_ROW_HEIGHT_VP,
  DOWNLOAD_RECENT_FOOTER_HEIGHT_VP,
  DOWNLOAD_RECENT_HEADER_HEIGHT_VP,
  DOWNLOAD_RECENT_IDLE_ROW_HEIGHT_VP,
  DOWNLOAD_RECENT_POPUP_MAX_ROWS,
  DownloadRecentRecordsViewModel
} from '../main/ets/core/download/DownloadRecentRecordsViewModel';

const NOW: number = Date.UTC(2026, 8, 27, 12, 0, 0);
const HOUR_MS: number = 60 * 60 * 1000;

function task(
  guid: string,
  status: DownloadV2Status,
  fileName: string,
  updatedAt: number,
  receivedBytes: number = 0,
  totalBytes: number = 0,
  completedAt: number = 0
): DownloadV2TaskEntity {
  return createDownloadV2TaskEntity({
    guid: guid,
    profileId: 'profile-main',
    privacyMode: 'regular',
    dataScope: 'profile_persistent',
    request: { url: `https://example.com/${guid}`, method: 'GET' },
    suggestedFileName: fileName,
    status: status,
    progress: {
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
      speedBytesPerSecond: 0
    },
    timing: {
      createdAt: updatedAt,
      updatedAt: updatedAt,
      completedAt: completedAt > 0 ? completedAt : undefined
    }
  });
}

export default function downloadRecentRecordsViewModelTest(): void {
  const viewModel = new DownloadRecentRecordsViewModel();

  describe('Download recent records popup', () => {
    it('keeps a canceled download in place, struck through, and drops removed ones', 0, () => {
      const layout = viewModel.resolve([
        task('old', 'completed', 'old.zip', NOW - 5 * HOUR_MS, 100, 100, NOW - 5 * HOUR_MS),
        task('removed', 'removed', 'gone.zip', NOW),
        task('canceled', 'canceled', 'stopped.zip', NOW, 10, 10),
        task('fresh', 'paused', 'fresh.apk', NOW - HOUR_MS, 20 * 1024 * 1024, 100 * 1024 * 1024)
      ], {
        viewportHeightVp: 900,
        reservedTopVp: 80,
        now: NOW
      });
      expect(layout.records.length).assertEqual(3);
      expect(layout.records[0].guid).assertEqual('canceled');
      expect(layout.records[0].fileName).assertEqual('stopped.zip');
      expect(layout.records[0].subtitle).assertEqual('已取消');
      expect(layout.records[0].struckThrough).assertTrue();
      expect(layout.records[0].showProgress).assertFalse();
      expect(layout.records[0].canOpenFile).assertFalse();
      expect(layout.records[0].leadingHoverAction).assertEqual('');
      expect(layout.records[0].trailingHoverAction).assertEqual('');
      expect(layout.records[1].guid).assertEqual('fresh');
      expect(layout.records[1].struckThrough).assertFalse();
      expect(layout.records[1].subtitle).assertEqual('20/100 MB · 已暂停');
      expect(layout.records[1].showProgress).assertTrue();
      expect(layout.records[1].leadingHoverAction).assertEqual('resume');
      expect(layout.records[1].trailingHoverAction).assertEqual('cancel');
      expect(layout.records[2].canOpenFile).assertTrue();
      expect(layout.records[2].leadingHoverAction).assertEqual('open_location');
      expect(layout.records[2].trailingHoverAction).assertEqual('open_file');
      expect(layout.records[2].subtitle.indexOf('·') >= 0).assertTrue();
    });

    it('hugs the rows on screen and never offers more than six', 0, () => {
      const tasks: DownloadV2TaskEntity[] = [];
      for (let index = 0; index < 8; index++) {
        tasks.push(task(
          `done-${index}`,
          'completed',
          `file-${index}.zip`,
          NOW - index * HOUR_MS,
          1024,
          1024,
          NOW - index * HOUR_MS
        ));
      }
      const tall = viewModel.resolve(tasks, { viewportHeightVp: 1200, reservedTopVp: 40, now: NOW });
      expect(tall.records.length).assertEqual(DOWNLOAD_RECENT_POPUP_MAX_ROWS);
      expect(tall.heightVp).assertEqual(
        DOWNLOAD_RECENT_HEADER_HEIGHT_VP + DOWNLOAD_RECENT_FOOTER_HEIGHT_VP +
        DOWNLOAD_RECENT_IDLE_ROW_HEIGHT_VP * DOWNLOAD_RECENT_POPUP_MAX_ROWS
      );

      const short = viewModel.resolve(tasks, { viewportHeightVp: 400, reservedTopVp: 80, now: NOW });
      expect(short.records.length < DOWNLOAD_RECENT_POPUP_MAX_ROWS).assertTrue();
      expect(short.records.length >= 1).assertTrue();
      expect(short.heightVp).assertEqual(
        DOWNLOAD_RECENT_HEADER_HEIGHT_VP + DOWNLOAD_RECENT_FOOTER_HEIGHT_VP +
        DOWNLOAD_RECENT_IDLE_ROW_HEIGHT_VP * short.records.length
      );

      const few = viewModel.resolve(tasks.slice(0, 2), { viewportHeightVp: 1200, reservedTopVp: 40, now: NOW });
      expect(few.records.length).assertEqual(2);
      expect(few.heightVp < tall.heightVp).assertTrue();
    });

    it('gives an in-progress row the taller progress height', 0, () => {
      const layout = viewModel.resolve([
        task('run', 'running', 'video.mp4', NOW, 0, 0)
      ], { viewportHeightVp: 900, reservedTopVp: 80, now: NOW });
      expect(layout.records.length).assertEqual(1);
      expect(layout.records[0].showProgress).assertTrue();
      expect(layout.records[0].progressKnown).assertFalse();
      expect(layout.records[0].subtitle).assertEqual('正在下载');
      expect(layout.records[0].leadingHoverAction).assertEqual('pause');
      expect(layout.records[0].trailingHoverAction).assertEqual('cancel');
      expect(viewModel.rowHeight('running')).assertEqual(DOWNLOAD_RECENT_ACTIVE_ROW_HEIGHT_VP);
      expect(layout.heightVp).assertEqual(
        DOWNLOAD_RECENT_HEADER_HEIGHT_VP + DOWNLOAD_RECENT_FOOTER_HEIGHT_VP +
        DOWNLOAD_RECENT_ACTIVE_ROW_HEIGHT_VP
      );
    });
  });
}
