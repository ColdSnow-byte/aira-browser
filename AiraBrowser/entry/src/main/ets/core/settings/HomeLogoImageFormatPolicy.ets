/**
 * Which image formats a custom homepage logo may use.
 *
 * The gallery picker only exposes media-library bitmaps, so SVG never reaches it. The
 * file picker carries these suffixes instead. Raster files are recognized by magic bytes
 * and decoded for their size; SVG is vector, so its size comes from the markup.
 *
 * GIF stays animated: the Image component plays a GIF on its own, so nothing here has to
 * special-case it beyond accepting the format.
 */
export type HomeLogoAssetKind = 'raster' | 'vector';

export interface HomeLogoImageSize {
  width: number;
  height: number;
}

export const HOME_LOGO_RASTER_EXTENSIONS: string[] = [
  'png', 'jpg', 'gif', 'webp', 'bmp', 'heic', 'avif', 'ico', 'tiff'
];
export const HOME_LOGO_VECTOR_EXTENSIONS: string[] = ['svg'];
export const HOME_LOGO_SUPPORTED_EXTENSIONS: string[] = HOME_LOGO_RASTER_EXTENSIONS
  .concat(HOME_LOGO_VECTOR_EXTENSIONS);

/** Picker label plus the suffixes it accepts, in the `描述|后缀` shape the API expects. */
export const HOME_LOGO_FILE_PICKER_FILTER: string =
  '图片|.png,.jpg,.jpeg,.gif,.webp,.bmp,.svg,.heic,.heif,.avif,.ico,.tif,.tiff';

/** Shown under the upload row so the user knows GIF and SVG are allowed. */
export const HOME_LOGO_SUPPORTED_FORMATS_TEXT: string =
  '支持 PNG、JPG、GIF、WebP、BMP、SVG、HEIC、AVIF 等格式';

const HOME_LOGO_IMAGE_HEAD_BYTES: number = 64 * 1024;

/** Enough markup to find the root tag without carrying a whole file in memory. */
export function homeLogoImageHeadBytes(): number {
  return HOME_LOGO_IMAGE_HEAD_BYTES;
}

/** Lowercases, drops any query or fragment, and folds the short aliases together. */
export function normalizeHomeLogoExtension(uriOrName: string): string {
  const normalized = (uriOrName ?? '').trim().toLowerCase().split('?')[0].split('#')[0];
  const dot = normalized.lastIndexOf('.');
  if (dot < 0 || dot >= normalized.length - 1) {
    return '';
  }
  const extension = normalized.substring(dot + 1);
  if (!/^[a-z0-9]+$/.test(extension)) {
    return '';
  }
  if (extension === 'jpeg') {
    return 'jpg';
  }
  if (extension === 'tif') {
    return 'tiff';
  }
  if (extension === 'heif') {
    return 'heic';
  }
  return extension;
}

export function isSupportedHomeLogoExtension(extension: string): boolean {
  return HOME_LOGO_SUPPORTED_EXTENSIONS.indexOf(extension) >= 0;
}

export function resolveHomeLogoAssetKind(extension: string): HomeLogoAssetKind {
  return HOME_LOGO_VECTOR_EXTENSIONS.indexOf(extension) >= 0 ? 'vector' : 'raster';
}

/** The file name carries the format so the Image component renders SVG as SVG. */
export function resolveHomeLogoExtensionForFormat(format: string): string {
  if (format === 'jpeg') {
    return 'jpg';
  }
  if (format === '') {
    return '';
  }
  return format;
}

/**
 * Detect a bitmap from its signature. `heic`/`avif` share the ISO-BMFF `ftyp` box and are
 * told apart by brand, which is what the decoder needs to pick a path.
 */
export function detectHomeLogoImageFormat(bytes: Uint8Array): string {
  if (bytes.length >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) {
    return 'png';
  }
  if (bytes.length >= 3 && bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) {
    return 'jpeg';
  }
  if (bytes.length >= 6 &&
    bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x38) {
    return 'gif';
  }
  if (bytes.length >= 2 && bytes[0] === 0x42 && bytes[1] === 0x4D) {
    return 'bmp';
  }
  if (bytes.length >= 12 &&
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) {
    return 'webp';
  }
  if (bytes.length >= 12 &&
    bytes[4] === 0x66 && bytes[5] === 0x74 && bytes[6] === 0x79 && bytes[7] === 0x70) {
    return detectIsoBmffBrand(bytes);
  }
  if (bytes.length >= 4 &&
    bytes[0] === 0x00 && bytes[1] === 0x00 && bytes[2] === 0x01 && bytes[3] === 0x00) {
    return 'ico';
  }
  if (bytes.length >= 4 &&
    ((bytes[0] === 0x49 && bytes[1] === 0x49 && bytes[2] === 0x2A && bytes[3] === 0x00) ||
      (bytes[0] === 0x4D && bytes[1] === 0x4D && bytes[2] === 0x00 && bytes[3] === 0x2A))) {
    return 'tiff';
  }
  return '';
}

function detectIsoBmffBrand(bytes: Uint8Array): string {
  const brand = String.fromCharCode(bytes[8], bytes[9], bytes[10], bytes[11]).toLowerCase();
  if (brand === 'avif' || brand === 'avis') {
    return 'avif';
  }
  if (brand === 'heic' || brand === 'heix' || brand === 'hevc' || brand === 'hevx' ||
    brand === 'heim' || brand === 'heis' || brand === 'mif1' || brand === 'msf1') {
    return 'heic';
  }
  return '';
}

export function isHomeLogoSvgText(text: string): boolean {
  return text.slice(0, HOME_LOGO_IMAGE_HEAD_BYTES).toLowerCase().indexOf('<svg') >= 0;
}

/**
 * Intrinsic size for an SVG. Width and height attributes win; otherwise the viewBox.
 * A percentage or a missing value yields zero, and the caller falls back.
 */
export function resolveHomeLogoSvgSize(text: string): HomeLogoImageSize {
  const head = text.slice(0, HOME_LOGO_IMAGE_HEAD_BYTES);
  const start = head.toLowerCase().indexOf('<svg');
  if (start < 0) {
    return { width: 0, height: 0 };
  }
  const end = head.indexOf('>', start);
  const tag = end > start ? head.substring(start, end + 1) : head.substring(start);
  const width = parseSvgLength(readSvgAttribute(tag, 'width'));
  const height = parseSvgLength(readSvgAttribute(tag, 'height'));
  if (width > 0 && height > 0) {
    return { width: width, height: height };
  }
  const viewBox = parseSvgViewBox(readSvgAttribute(tag, 'viewBox'));
  if (viewBox.width > 0 && viewBox.height > 0) {
    return viewBox;
  }
  return { width: 0, height: 0 };
}

/** Requires a leading whitespace so `stroke-width` cannot answer for `width`. */
function readSvgAttribute(tag: string, name: string): string {
  const pattern = new RegExp('[\\s]' + name + '\\s*=\\s*["\']([^"\']*)["\']', 'i');
  const match = tag.match(pattern);
  return match !== null && match.length > 1 ? match[1] : '';
}

function parseSvgLength(value: string): number {
  const trimmed = value.trim().toLowerCase();
  if (trimmed.length === 0 || trimmed.indexOf('%') >= 0) {
    return 0;
  }
  const match = trimmed.match(/^[0-9]*\.?[0-9]+/);
  if (match === null || match.length === 0) {
    return 0;
  }
  const parsed = Number.parseFloat(match[0]);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

function parseSvgViewBox(value: string): HomeLogoImageSize {
  if (value.trim().length === 0) {
    return { width: 0, height: 0 };
  }
  const parts = value.trim().replace(/,/g, ' ').split(/\s+/);
  const numbers: number[] = [];
  for (let index = 0; index < parts.length; index += 1) {
    const parsed = Number.parseFloat(parts[index]);
    if (Number.isFinite(parsed)) {
      numbers.push(parsed);
    }
  }
  if (numbers.length < 4 || numbers[2] <= 0 || numbers[3] <= 0) {
    return { width: 0, height: 0 };
  }
  return { width: numbers[2], height: numbers[3] };
}
