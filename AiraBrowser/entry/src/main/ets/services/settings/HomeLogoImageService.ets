import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { util } from '@kit.ArkTS';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';
import { HomeLogoPickSource, readHomeLogoFileNameFromUri } from '../../common/models/HomeLogoModels';
import {
  detectHomeLogoImageFormat,
  homeLogoImageHeadBytes,
  HOME_LOGO_FILE_PICKER_FILTER,
  HOME_LOGO_SUPPORTED_FORMATS_TEXT,
  HomeLogoImageSize,
  isHomeLogoSvgText,
  isSupportedHomeLogoExtension,
  normalizeHomeLogoExtension,
  resolveHomeLogoAssetKind,
  resolveHomeLogoExtensionForFormat,
  resolveHomeLogoSvgSize
} from '../../core/settings/HomeLogoImageFormatPolicy';

const HOME_LOGO_DIR_NAME: string = 'home-logo';
const HOME_LOGO_FILE_PREFIX: string = 'logo-';
const HOME_LOGO_MAX_BYTES: number = 20 * 1024 * 1024;

export interface HomeLogoImportedImage {
  uri: string;
  /** The name the user's file carries, shown under the tile. */
  fileName: string;
  width: number;
  height: number;
}

interface HomeLogoImageAnalysis {
  extension: string;
  width: number;
  height: number;
}

export class HomeLogoImageService {
  private textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  /**
   * Picks from the gallery or the file manager and stores a copy. Returns undefined when
   * the picker was dismissed.
   */
  async pickAndSave(source: HomeLogoPickSource): Promise<HomeLogoImportedImage | undefined> {
    try {
      const sourceUri = source === 'files' ? await this.selectFileUri() : await this.selectPhotoUri();
      if (sourceUri === undefined) {
        return undefined;
      }
      return await this.saveImage(sourceUri);
    } catch (error) {
      if (this.isPickerCancel(error)) {
        return undefined;
      }
      throw new Error(this.stringifyError(error));
    }
  }

  private async selectPhotoUri(): Promise<string | undefined> {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const pickerInstance = new photoAccessHelper.PhotoViewPicker();
    const result = await pickerInstance.select(options);
    return result.photoUris.length > 0 ? result.photoUris[0] : undefined;
  }

  /** Carries the image suffixes so SVG and GIF files are selectable, not just gallery bitmaps. */
  private async selectFileUri(): Promise<string | undefined> {
    const documentPicker = new picker.DocumentViewPicker(AppRuntimeContext.getUIAbilityContext());
    const uris: Array<string> = await documentPicker.select({
      maxSelectNumber: 1,
      fileSuffixFilters: [HOME_LOGO_FILE_PICKER_FILTER]
    });
    return uris.length > 0 ? uris[0] : undefined;
  }

  private async saveImage(sourceUri: string): Promise<HomeLogoImportedImage> {
    const normalizedSourceUri = sourceUri.trim();
    if (normalizedSourceUri.length === 0) {
      throw new Error('未选择图片。');
    }
    const directory = this.getLogoDir();
    await this.ensureDirectory(directory);
    const fileName = await this.resolveSourceFileName(normalizedSourceUri);
    const targetBasePath = `${directory}/${HOME_LOGO_FILE_PREFIX}${Date.now()}`;
    const tempPath = `${targetBasePath}.tmp`;
    await this.deleteIfExists(tempPath);
    await fileIo.copy(normalizedSourceUri, fileUri.getUriFromPath(tempPath));
    try {
      const analysis = await this.analyzeImage(tempPath, normalizedSourceUri);
      const targetPath = `${targetBasePath}.${analysis.extension}`;
      await this.moveFile(tempPath, targetPath);
      return {
        uri: fileUri.getUriFromPath(targetPath),
        fileName: fileName,
        width: analysis.width,
        height: analysis.height
      };
    } catch (error) {
      await this.deleteIfExists(tempPath);
      throw new Error(this.stringifyError(error));
    }
  }

  /**
   * SVG has no pixel size, so it is measured from its markup; a bitmap is recognized by
   * signature and decoded for its size. Either way a decodable file is accepted even when
   * the size cannot be read, and the display falls back to a square.
   */
  /**
   * The name the file actually carries, which a picker uri does not always spell out.
   * Falls back to the uri's last segment when the source cannot be opened.
   */
  private async resolveSourceFileName(sourceUri: string): Promise<string> {
    let sourceFile: fileIo.File | undefined = undefined;
    try {
      sourceFile = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      const name = sourceFile.name.trim();
      if (name.length > 0) {
        return name;
      }
    } catch (_error) {
    } finally {
      if (sourceFile !== undefined) {
        await fileIo.close(sourceFile).catch((_closeError: Error) => {});
      }
    }
    return readHomeLogoFileNameFromUri(sourceUri);
  }

  private async analyzeImage(path: string, sourceUri: string): Promise<HomeLogoImageAnalysis> {
    const stat = await fileIo.stat(path);
    if (stat.isDirectory() || stat.size <= 0) {
      throw new Error('这张图片不可用。');
    }
    if (stat.size > HOME_LOGO_MAX_BYTES) {
      throw new Error('图片超过 20 MB，请换一张再试。');
    }
    const bytes = await this.readHeadBytes(path);
    const text = this.decodeHead(bytes);
    if (isHomeLogoSvgText(text)) {
      const svgSize = resolveHomeLogoSvgSize(text);
      if (svgSize.width > 0 && svgSize.height > 0) {
        return { extension: 'svg', width: svgSize.width, height: svgSize.height };
      }
      const rasterSize = await this.tryReadDecodedSize(path);
      return { extension: 'svg', width: rasterSize.width, height: rasterSize.height };
    }
    const decodedSize = await this.tryReadDecodedSize(path);
    const detectedFormat = detectHomeLogoImageFormat(bytes);
    if (detectedFormat === '' && (decodedSize.width <= 0 || decodedSize.height <= 0)) {
      throw new Error(`这个文件不是受支持的图片格式，请选择 ${HOME_LOGO_SUPPORTED_FORMATS_TEXT}。`);
    }
    return {
      extension: this.resolveStoredExtension(sourceUri, detectedFormat),
      width: decodedSize.width,
      height: decodedSize.height
    };
  }

  private resolveStoredExtension(sourceUri: string, detectedFormat: string): string {
    const sourceExtension = normalizeHomeLogoExtension(sourceUri);
    if (isSupportedHomeLogoExtension(sourceExtension) &&
      resolveHomeLogoAssetKind(sourceExtension) === 'raster') {
      return sourceExtension;
    }
    const fromFormat = resolveHomeLogoExtensionForFormat(detectedFormat);
    return fromFormat.length > 0 ? fromFormat : 'png';
  }

  private async readHeadBytes(path: string): Promise<Uint8Array> {
    const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    try {
      const buffer = new ArrayBuffer(homeLogoImageHeadBytes());
      const readLength = await fileIo.read(file.fd, buffer);
      return readLength > 0 ? new Uint8Array(buffer.slice(0, readLength)) : new Uint8Array(0);
    } finally {
      await fileIo.close(file).catch((_closeError: Error) => {});
    }
  }

  private decodeHead(bytes: Uint8Array): string {
    if (bytes.length === 0) {
      return '';
    }
    try {
      return this.textDecoder.decodeToString(bytes);
    } catch (_error) {
      return '';
    }
  }

  /** Failure here is not fatal: the format signature decides, and the size falls back. */
  private async tryReadDecodedSize(path: string): Promise<HomeLogoImageSize> {
    let sourceFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    try {
      sourceFile = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(sourceFile.fd);
      const imageInfo = await imageSource.getImageInfo();
      const width = Math.floor(imageInfo.size.width);
      const height = Math.floor(imageInfo.size.height);
      if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
        return { width: 0, height: 0 };
      }
      return { width: width, height: height };
    } catch (_error) {
      return { width: 0, height: 0 };
    } finally {
      if (imageSource !== undefined) {
        await imageSource.release().catch((_releaseError: Error) => {});
      }
      if (sourceFile !== undefined) {
        await fileIo.close(sourceFile).catch((_closeError: Error) => {});
      }
    }
  }

  /**
   * Custom logos accumulate, so one import never disturbs another. The coordinator calls this
   * only for an asset it just dropped, which leaves no tile behind to read the file.
   */
  async removeStoredImage(uri: string): Promise<void> {
    const path = this.resolveStoredPath(uri);
    if (path.length === 0) {
      return;
    }
    await this.deleteIfExists(path);
  }

  /**
   * Only a file we named ourselves, inside our own directory. The name carries no separator,
   * so a uri cannot walk out of the logo directory.
   */
  private resolveStoredPath(uri: string): string {
    const trimmed = uri.trim();
    const slash = trimmed.lastIndexOf('/');
    if (slash < 0) {
      return '';
    }
    const fileName = trimmed.substring(slash + 1);
    if (!fileName.startsWith(HOME_LOGO_FILE_PREFIX)) {
      return '';
    }
    return `${this.getLogoDir()}/${fileName}`;
  }

  private async moveFile(sourcePath: string, targetPath: string): Promise<void> {
    try {
      await fileIo.rename(sourcePath, targetPath);
    } catch (_renameError) {
      await fileIo.copyFile(sourcePath, targetPath);
      await fileIo.unlink(sourcePath);
    }
  }

  private async ensureDirectory(path: string): Promise<void> {
    if (await this.exists(path)) {
      return;
    }
    await fileIo.mkdir(path, true);
  }

  private async deleteIfExists(path: string): Promise<void> {
    try {
      if (await fileIo.access(path)) {
        await fileIo.unlink(path);
      }
    } catch (_error) {
    }
  }

  private async exists(path: string): Promise<boolean> {
    try {
      return await fileIo.access(path);
    } catch (_error) {
      return false;
    }
  }

  private getLogoDir(): string {
    return `${AppRuntimeContext.getApplicationContext().filesDir}/${HOME_LOGO_DIR_NAME}`;
  }

  private isPickerCancel(error: Object | undefined): boolean {
    const message = this.stringifyError(error).toLowerCase();
    return message.indexOf('cancel') >= 0 || message.indexOf('canceled') >= 0 ||
      message.indexOf('取消') >= 0;
  }

  private stringifyError(error: Object | undefined): string {
    if (error instanceof Error && error.message.length > 0) {
      return error.message;
    }
    return '上传 Logo 失败，请稍后重试。';
  }
}
