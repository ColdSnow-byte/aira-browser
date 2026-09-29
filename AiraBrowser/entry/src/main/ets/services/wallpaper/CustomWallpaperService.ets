import { window } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';
import {
  HOME_WALLPAPER_FOREGROUND_ALGORITHM_VERSION,
  HomeWallpaperForegroundAnalysis,
  HomeWallpaperVisibleCropInput,
  WallpaperAsset,
  WallpaperRepositorySnapshot
} from '../../common/models/WallpaperModels';
import { WallpaperAssetStore } from '../../data/wallpaper/WallpaperAssetStore';
import { WallpaperRepository } from '../../data/wallpaper/WallpaperRepository';
import { HOME_IMAGE_WALLPAPER_MASK_OPACITY } from './HomeWallpaperAnalysisPolicy';
import { WallpaperForegroundToneService } from './WallpaperForegroundToneService';

const CUSTOM_WALLPAPER_ASSET_ID: string = 'custom-home';
const CUSTOM_WALLPAPER_MAX_BYTES: number = 30 * 1024 * 1024;
const CUSTOM_VIDEO_WALLPAPER_MAX_BYTES: number = 100 * 1024 * 1024;
const CUSTOM_VIDEO_POSTER_LONG_EDGE: number = 720;
const CUSTOM_VIDEO_UNSAMPLED_SIGNATURE: string = 'video-unsampled';
const CUSTOM_WALLPAPER_CLEANUP_DELAY_MS: number = 5000;
const FALLBACK_VIEWPORT_WIDTH: number = 1080;
const FALLBACK_VIEWPORT_HEIGHT: number = 1920;

interface CustomWallpaperSourceAnalysis {
  foreground: HomeWallpaperForegroundAnalysis;
  fileName: string;
  width: number;
  height: number;
  posterBytes: ArrayBuffer;
}

export class CustomWallpaperService {
  private repository: WallpaperRepository;
  private assetStore: WallpaperAssetStore;
  private foregroundToneService: WallpaperForegroundToneService;

  constructor(
    repository: WallpaperRepository,
    assetStore: WallpaperAssetStore = new WallpaperAssetStore(),
    foregroundToneService: WallpaperForegroundToneService = new WallpaperForegroundToneService()
  ) {
    this.repository = repository;
    this.assetStore = assetStore;
    this.foregroundToneService = foregroundToneService;
  }

  async selectAndApply(nowMs: number = Date.now()): Promise<WallpaperRepositorySnapshot | undefined> {
    const sourceUri = await this.selectImageUri();
    if (sourceUri === undefined) {
      return undefined;
    }
    const cropInput = await this.resolveCurrentCropInput();
    return await this.importAndApply(sourceUri, cropInput, nowMs);
  }

  async selectVideoAndApply(nowMs: number = Date.now()): Promise<WallpaperRepositorySnapshot | undefined> {
    const sourceUri = await this.selectVideoUri();
    if (sourceUri === undefined) {
      return undefined;
    }
    const cropInput = await this.resolveCurrentCropInput();
    return await this.importVideoAndApply(sourceUri, cropInput, nowMs);
  }

  async refreshAnalysisIfNeeded(
    snapshot: WallpaperRepositorySnapshot,
    cropInput: HomeWallpaperVisibleCropInput,
    nowMs: number = Date.now()
  ): Promise<void> {
    if (snapshot.settings.mode !== 'custom') {
      return;
    }
    const asset = this.findCustomAsset(snapshot);
    if (asset === undefined || this.hasUsableForegroundAnalysis(asset, cropInput)) {
      return;
    }
    try {
      if (asset.mediaType === 'video') {
        await this.refreshVideoAnalysis(asset, cropInput, nowMs);
        return;
      }
      const analysis = await this.analyzeSourceUri(
        asset.originalPath,
        cropInput,
        asset.contentSignature
      );
      const refreshedAsset = this.buildRefreshedAsset(asset, analysis, nowMs);
      await this.repository.commitCustomAppearance(refreshedAsset, nowMs);
    } catch (_error) {
    }
  }

  private async selectImageUri(): Promise<string | undefined> {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const picker = new photoAccessHelper.PhotoViewPicker();
    const result = await picker.select(options);
    return result.photoUris.length > 0 ? result.photoUris[0] : undefined;
  }

  private async selectVideoUri(): Promise<string | undefined> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
      options.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      return result.photoUris.length > 0 ? result.photoUris[0] : undefined;
    } catch (_error) {
      return undefined;
    }
  }

  private async importVideoAndApply(
    sourceUri: string,
    cropInput: HomeWallpaperVisibleCropInput,
    nowMs: number
  ): Promise<WallpaperRepositorySnapshot> {
    const stat = await fileIo.stat(sourceUri);
    if (stat.isDirectory() || stat.size <= 0) {
      throw new Error('这个视频不可用。');
    }
    if (stat.size > CUSTOM_VIDEO_WALLPAPER_MAX_BYTES) {
      throw new Error('视频超过 100 MB，请换一个短一些的再试。');
    }
    const analysis = await this.analyzeVideoUri(
      sourceUri,
      cropInput,
      this.buildContentSignature(stat.size, nowMs)
    );
    let storedAsset: WallpaperAsset | undefined = undefined;
    let committed = false;
    try {
      storedAsset = await this.assetStore.saveImportedVideo(
        sourceUri,
        analysis.fileName,
        CUSTOM_WALLPAPER_ASSET_ID,
        analysis.width,
        analysis.height,
        analysis.foreground,
        analysis.posterBytes,
        nowMs
      );
      const snapshot = await this.repository.commitCustomAppearance(storedAsset, nowMs);
      committed = true;
      this.scheduleObsoleteImageCleanup(storedAsset);
      return snapshot;
    } catch (error) {
      if (error instanceof Error && error.message.length > 0) {
        throw error;
      }
      throw new Error('无法保存这个视频，请换一个再试。');
    } finally {
      if (!committed && storedAsset !== undefined) {
        await this.assetStore.discardStoredImage(storedAsset).catch((_error: Error) => {});
      }
    }
  }

  private async refreshVideoAnalysis(
    asset: WallpaperAsset,
    cropInput: HomeWallpaperVisibleCropInput,
    nowMs: number
  ): Promise<void> {
    const analysis = await this.analyzeVideoUri(asset.originalPath, cropInput, asset.contentSignature);
    const settled = analysis.foreground.sampleSignature.trim().length > 0 ?
      analysis :
      this.buildUnsampledVideoAnalysis(
        asset.contentSignature,
        this.fileNameFromUri(asset.originalPath),
        CUSTOM_VIDEO_UNSAMPLED_SIGNATURE,
        cropInput
      );
    const thumbPath = settled.posterBytes.byteLength > 0 ?
      await this.assetStore.writeImportedPoster(asset.id, asset.contentSignature, settled.posterBytes) :
      asset.thumbPath;
    const refreshedAsset = this.buildRefreshedAsset(asset, settled, nowMs);
    refreshedAsset.thumbPath = thumbPath.length > 0 ? thumbPath : asset.thumbPath;
    await this.repository.commitCustomAppearance(refreshedAsset, nowMs);
  }

  private async importAndApply(
    sourceUri: string,
    cropInput: HomeWallpaperVisibleCropInput,
    nowMs: number
  ): Promise<WallpaperRepositorySnapshot> {
    const stat = await fileIo.stat(sourceUri);
    if (stat.isDirectory() || stat.size <= 0) {
      throw new Error('这张壁纸图片不可用。');
    }
    if (stat.size > CUSTOM_WALLPAPER_MAX_BYTES) {
      throw new Error('壁纸图片超过 30 MB，请换一张再试。');
    }
    const analysis = await this.analyzeSourceUri(
      sourceUri,
      cropInput,
      this.buildContentSignature(stat.size, nowMs)
    );
    let storedAsset: WallpaperAsset | undefined = undefined;
    let committed = false;
    try {
      storedAsset = await this.assetStore.saveImportedImage(
        sourceUri,
        analysis.fileName,
        CUSTOM_WALLPAPER_ASSET_ID,
        analysis.width,
        analysis.height,
        analysis.foreground,
        nowMs
      );
      const snapshot = await this.repository.commitCustomAppearance(storedAsset, nowMs);
      committed = true;
      this.scheduleObsoleteImageCleanup(storedAsset);
      return snapshot;
    } finally {
      if (!committed && storedAsset !== undefined) {
        await this.assetStore.discardStoredImage(storedAsset).catch((_error: Error) => {});
      }
    }
  }

  private async analyzeSourceUri(
    sourceUri: string,
    cropInput: HomeWallpaperVisibleCropInput,
    contentSignature: string
  ): Promise<CustomWallpaperSourceAnalysis> {
    let sourceFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let sample: image.PixelMap | undefined = undefined;
    try {
      sourceFile = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(sourceFile.fd);
      const imageInfo = await imageSource.getImageInfo();
      const width = Math.max(1, Math.floor(imageInfo.size.width));
      const height = Math.max(1, Math.floor(imageInfo.size.height));
      sample = await this.foregroundToneService.createVisibleCropSample(imageSource, cropInput);
      const foreground = await this.foregroundToneService.resolveToneFromPixelMap(
        sample,
        cropInput,
        contentSignature
      );
      return {
        foreground: foreground,
        fileName: sourceFile.name,
        width: width,
        height: height,
        posterBytes: new ArrayBuffer(0)
      };
    } catch (error) {
      if (error instanceof Error && error.message.length > 0) {
        throw error;
      }
      throw new Error('无法读取这张壁纸，请换一张再试。');
    } finally {
      if (sample !== undefined) {
        await sample.release().catch((_error: Error) => {});
      }
      if (imageSource !== undefined) {
        await imageSource.release().catch((_error: Error) => {});
      }
      if (sourceFile !== undefined) {
        await fileIo.close(sourceFile).catch((_error: Error) => {});
      }
    }
  }

  private async analyzeVideoUri(
    sourceUri: string,
    cropInput: HomeWallpaperVisibleCropInput,
    contentSignature: string
  ): Promise<CustomWallpaperSourceAnalysis> {
    const fileName = this.fileNameFromUri(sourceUri);
    let frame: image.PixelMap | undefined = undefined;
    let posterSource: image.ImageSource | undefined = undefined;
    let sample: image.PixelMap | undefined = undefined;
    try {
      const orientation = await this.readVideoOrientation(sourceUri);
      frame = await this.fetchVideoFrame(sourceUri);
      if (frame === undefined) {
        return this.buildUnsampledVideoAnalysis(contentSignature, fileName, '', cropInput);
      }
      if (orientation === 90 || orientation === 180 || orientation === 270) {
        await frame.rotate(orientation);
      }
      const frameInfo = await frame.getImageInfo();
      const posterBytes = await this.packVideoPoster(frame);
      posterSource = image.createImageSource(posterBytes);
      sample = await this.foregroundToneService.createVisibleCropSample(posterSource, cropInput);
      const foreground = await this.foregroundToneService.resolveToneFromPixelMap(
        sample,
        cropInput,
        contentSignature
      );
      return {
        foreground: foreground,
        fileName: fileName,
        width: Math.max(1, Math.floor(frameInfo.size.width)),
        height: Math.max(1, Math.floor(frameInfo.size.height)),
        posterBytes: posterBytes
      };
    } catch (_error) {
      return this.buildUnsampledVideoAnalysis(contentSignature, fileName, '', cropInput);
    } finally {
      if (sample !== undefined) {
        await sample.release().catch((_error: Error) => {});
      }
      if (posterSource !== undefined) {
        await posterSource.release().catch((_error: Error) => {});
      }
      if (frame !== undefined) {
        await frame.release().catch((_error: Error) => {});
      }
    }
  }

  private buildUnsampledVideoAnalysis(
    contentSignature: string,
    fileName: string,
    sampleSignature: string,
    cropInput: HomeWallpaperVisibleCropInput
  ): CustomWallpaperSourceAnalysis {
    const cropSignature = this.foregroundToneService.buildCropSignature(cropInput);
    return {
      foreground: {
        foregroundTone: 'lightText',
        contentSignature: contentSignature,
        cropSignature: cropSignature,
        sampleSignature: sampleSignature,
        algorithmVersion: HOME_WALLPAPER_FOREGROUND_ALGORITHM_VERSION
      },
      fileName: fileName,
      width: 1,
      height: 1,
      posterBytes: new ArrayBuffer(0)
    };
  }

  private async readVideoOrientation(sourceUri: string): Promise<number> {
    let sourceFile: fileIo.File | undefined = undefined;
    let extractor: media.AVMetadataExtractor | undefined = undefined;
    try {
      sourceFile = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      const stat = await fileIo.stat(sourceUri);
      extractor = await media.createAVMetadataExtractor();
      extractor.fdSrc = { fd: sourceFile.fd, offset: 0, length: stat.size };
      const metadata = await extractor.fetchMetadata();
      const orientation = Number(metadata.videoOrientation ?? '0');
      return Number.isFinite(orientation) ? orientation : 0;
    } catch (_error) {
      return 0;
    } finally {
      if (extractor !== undefined) {
        await extractor.release().catch((_error: Error) => {});
      }
      if (sourceFile !== undefined) {
        await fileIo.close(sourceFile).catch((_error: Error) => {});
      }
    }
  }

  private async fetchVideoFrame(sourceUri: string): Promise<image.PixelMap | undefined> {
    let sourceFile: fileIo.File | undefined = undefined;
    let generator: media.AVImageGenerator | undefined = undefined;
    try {
      sourceFile = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      const stat = await fileIo.stat(sourceUri);
      generator = await media.createAVImageGenerator();
      generator.fdSrc = { fd: sourceFile.fd, offset: 0, length: stat.size };
      return await generator.fetchFrameByTime(
        0,
        media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC,
        await this.resolveVideoPosterParams(sourceUri)
      );
    } catch (_error) {
      return undefined;
    } finally {
      if (generator !== undefined) {
        await generator.release().catch((_error: Error) => {});
      }
      if (sourceFile !== undefined) {
        await fileIo.close(sourceFile).catch((_error: Error) => {});
      }
    }
  }

  private async resolveVideoPosterParams(sourceUri: string): Promise<media.PixelMapParams> {
    let sourceFile: fileIo.File | undefined = undefined;
    let extractor: media.AVMetadataExtractor | undefined = undefined;
    try {
      sourceFile = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      const stat = await fileIo.stat(sourceUri);
      extractor = await media.createAVMetadataExtractor();
      extractor.fdSrc = { fd: sourceFile.fd, offset: 0, length: stat.size };
      const metadata = await extractor.fetchMetadata();
      const width = Number(metadata.videoWidth ?? '0');
      const height = Number(metadata.videoHeight ?? '0');
      if (!Number.isFinite(width) || !Number.isFinite(height) || width < 2 || height < 2) {
        return {};
      }
      const longEdge = Math.max(width, height);
      const scale = longEdge > CUSTOM_VIDEO_POSTER_LONG_EDGE ? CUSTOM_VIDEO_POSTER_LONG_EDGE / longEdge : 1;
      return {
        width: this.evenPosterEdge(width * scale),
        height: this.evenPosterEdge(height * scale)
      };
    } catch (_error) {
      return {};
    } finally {
      if (extractor !== undefined) {
        await extractor.release().catch((_error: Error) => {});
      }
      if (sourceFile !== undefined) {
        await fileIo.close(sourceFile).catch((_error: Error) => {});
      }
    }
  }

  private evenPosterEdge(value: number): number {
    const rounded = Math.max(2, Math.floor(value));
    return rounded % 2 === 0 ? rounded : rounded - 1;
  }

  private async packVideoPoster(frame: image.PixelMap): Promise<ArrayBuffer> {
    const packer = image.createImagePacker();
    try {
      return await packer.packToData(frame, { format: 'image/jpeg', quality: 80 });
    } finally {
      try {
        await packer.release();
      } catch (_error) {
      }
    }
  }

  private fileNameFromUri(sourceUri: string): string {
    const normalized = sourceUri.trim().split('?')[0].split('#')[0];
    const slash = Math.max(normalized.lastIndexOf('/'), normalized.lastIndexOf('\\'));
    const name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    return name.length > 0 ? name : 'wallpaper.mp4';
  }

  private buildRefreshedAsset(
    asset: WallpaperAsset,
    analysis: CustomWallpaperSourceAnalysis,
    nowMs: number
  ): WallpaperAsset {
    return {
      id: asset.id,
      source: asset.source,
      mediaType: asset.mediaType,
      originalPath: asset.originalPath,
      displayPath: asset.displayPath,
      thumbPath: asset.thumbPath,
      contentSignature: asset.contentSignature,
      foregroundTone: analysis.foreground.foregroundTone,
      foregroundToneContentSignature: analysis.foreground.contentSignature,
      foregroundToneCropSignature: analysis.foreground.cropSignature,
      foregroundToneSampleSignature: analysis.foreground.sampleSignature,
      foregroundToneAlgorithmVersion: analysis.foreground.algorithmVersion,
      appearanceLight: asset.appearanceLight,
      appearanceDark: asset.appearanceDark,
      width: analysis.width,
      height: analysis.height,
      mimeType: asset.mimeType,
      byteSize: asset.byteSize,
      title: asset.title,
      attribution: asset.attribution,
      createdAt: asset.createdAt,
      updatedAt: nowMs,
      isFavorite: asset.isFavorite
    };
  }

  private hasUsableForegroundAnalysis(
    asset: WallpaperAsset,
    cropInput: HomeWallpaperVisibleCropInput
  ): boolean {
    return asset.foregroundToneAlgorithmVersion === HOME_WALLPAPER_FOREGROUND_ALGORITHM_VERSION &&
      asset.contentSignature.trim().length > 0 &&
      asset.foregroundToneContentSignature === asset.contentSignature &&
      asset.foregroundToneCropSignature === this.foregroundToneService.buildCropSignature(cropInput) &&
      asset.foregroundToneSampleSignature.trim().length > 0;
  }

  private findCustomAsset(snapshot: WallpaperRepositorySnapshot): WallpaperAsset | undefined {
    const selectedId = snapshot.settings.customWallpaperId.trim();
    const selected = snapshot.assets.find((asset: WallpaperAsset) => {
      return asset.source === 'custom' && asset.id === selectedId;
    });
    if (selected !== undefined) {
      return selected;
    }
    return snapshot.assets.find((asset: WallpaperAsset) => asset.source === 'custom');
  }

  private async resolveCurrentCropInput(): Promise<HomeWallpaperVisibleCropInput> {
    try {
      const mainWindow = await window.getLastWindow(AppRuntimeContext.getUIAbilityContext());
      const properties = mainWindow.getWindowProperties();
      const drawableWidth = this.normalizeViewportEdge(properties.drawableRect.width);
      const drawableHeight = this.normalizeViewportEdge(properties.drawableRect.height);
      const windowWidth = this.normalizeViewportEdge(properties.windowRect.width);
      const windowHeight = this.normalizeViewportEdge(properties.windowRect.height);
      return {
        viewportWidth: drawableWidth > 1 ? drawableWidth : windowWidth,
        viewportHeight: drawableHeight > 1 ? drawableHeight : windowHeight,
        maskOpacity: HOME_IMAGE_WALLPAPER_MASK_OPACITY
      };
    } catch (_error) {
      return {
        viewportWidth: FALLBACK_VIEWPORT_WIDTH,
        viewportHeight: FALLBACK_VIEWPORT_HEIGHT,
        maskOpacity: HOME_IMAGE_WALLPAPER_MASK_OPACITY
      };
    }
  }

  private normalizeViewportEdge(value: number): number {
    return Number.isFinite(value) && value > 0 ? Math.floor(value) : 1;
  }

  private buildContentSignature(byteSize: number, nowMs: number): string {
    return `custom-${Math.max(0, Math.floor(nowMs))}-${Math.max(0, Math.floor(byteSize))}`;
  }

  private scheduleObsoleteImageCleanup(activeAsset: WallpaperAsset): void {
    setTimeout(() => {
      void this.assetStore.pruneObsoleteImportedImages(activeAsset).catch((_error: Error) => {});
    }, CUSTOM_WALLPAPER_CLEANUP_DELAY_MS);
  }
}
