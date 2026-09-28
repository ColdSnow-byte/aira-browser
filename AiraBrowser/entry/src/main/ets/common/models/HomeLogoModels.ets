/**
 * Homepage wordmark choice for the centered and minimal frames.
 *
 * `builtin` keeps the shipped wordmark, `preset-N` is shipped banner artwork, and a custom
 * asset is an image the user added. Custom assets accumulate: each one becomes a tile in the
 * picker, and the add tile always stays last.
 */
export const HOME_LOGO_BUILTIN_ID: string = 'builtin';
export const HOME_LOGO_BUILTIN_RAWFILE: string = 'home_centered_wordmark.svg';
/** Custom ids carry this prefix so they can never collide with a shipped preset id. */
export const HOME_LOGO_CUSTOM_ASSET_ID_PREFIX: string = 'custom-';

interface HomeLogoPresetAsset {
  title: string;
  rawfileName: string;
  width: number;
  height: number;
  tintable: boolean;
}

/**
 * Built-in artwork in picker order. The wordmark is a mask that follows the wallpaper tone,
 * so it stays tintable; the animated banners are full-color and must not be tinted.
 */
const HOME_LOGO_PRESET_ASSETS: HomeLogoPresetAsset[] = [
  { title: '默认', rawfileName: HOME_LOGO_BUILTIN_RAWFILE, width: 546, height: 163, tintable: true },
  { title: '父亲节', rawfileName: 'home_logo_preset_1.gif', width: 1000, height: 400, tintable: false },
  { title: '世界杯', rawfileName: 'home_logo_preset_2.gif', width: 1000, height: 400, tintable: false },
  { title: '德甲', rawfileName: 'home_logo_preset_3.gif', width: 1000, height: 400, tintable: false }
];

export interface HomeLogoPreset {
  id: string;
  title: string;
  rawfileName: string;
  intrinsicWidth: number;
  intrinsicHeight: number;
  tintable: boolean;
}

/**
 * Where a custom logo comes from. The gallery only holds bitmaps, so an SVG or a file
 * outside the gallery has to come through the file picker.
 */
export type HomeLogoPickSource = 'photos' | 'files';

export interface HomeLogoCustomAsset {
  id: string;
  uri: string;
  /** Shown under the tile, so the user recognizes the file they picked. */
  fileName: string;
  width: number;
  height: number;
}

export interface HomeLogoSelection {
  id: string;
  customAssets: HomeLogoCustomAsset[];
}

export interface HomeLogoDisplaySource {
  rawfileName: string;
  fileUri: string;
  intrinsicWidth: number;
  intrinsicHeight: number;
  tintable: boolean;
}

export function listHomeLogoPresets(): HomeLogoPreset[] {
  const presets: HomeLogoPreset[] = [];
  for (let index = 0; index < HOME_LOGO_PRESET_ASSETS.length; index += 1) {
    const asset = HOME_LOGO_PRESET_ASSETS[index];
    presets.push({
      id: index === 0 ? HOME_LOGO_BUILTIN_ID : `preset-${index}`,
      title: asset.title,
      rawfileName: asset.rawfileName,
      intrinsicWidth: asset.width,
      intrinsicHeight: asset.height,
      tintable: asset.tintable
    });
  }
  return presets;
}

export function findHomeLogoPreset(id: string): HomeLogoPreset | undefined {
  const presets = listHomeLogoPresets();
  for (let index = 0; index < presets.length; index += 1) {
    if (presets[index].id === id) {
      return presets[index];
    }
  }
  return undefined;
}

export function buildHomeLogoCustomAssetId(nowMs: number): string {
  return `${HOME_LOGO_CUSTOM_ASSET_ID_PREFIX}${Math.max(0, Math.floor(nowMs))}`;
}

/** Last path segment of a uri, without its query or fragment. */
export function readHomeLogoFileNameFromUri(uri: string): string {
  const trimmed = uri.trim();
  if (trimmed.length === 0) {
    return '';
  }
  const withoutQuery = trimmed.split('?')[0].split('#')[0];
  const slash = withoutQuery.lastIndexOf('/');
  const fileName = slash >= 0 ? withoutQuery.substring(slash + 1) : withoutQuery;
  return fileName.trim();
}

/** Drops entries a picker could never show: a missing id, or no file behind it. */
export function normalizeHomeLogoCustomAssets(
  value: HomeLogoCustomAsset[] | undefined
): HomeLogoCustomAsset[] {
  const assets: HomeLogoCustomAsset[] = [];
  if (value === undefined) {
    return assets;
  }
  for (let index = 0; index < value.length; index += 1) {
    const asset: HomeLogoCustomAsset | undefined = value[index];
    if (asset === undefined) {
      continue;
    }
    const id = typeof asset.id === 'string' ? asset.id.trim() : '';
    const uri = typeof asset.uri === 'string' ? asset.uri.trim() : '';
    if (id.length === 0 || uri.length === 0) {
      continue;
    }
    const storedName = typeof asset.fileName === 'string' ? asset.fileName.trim() : '';
    assets.push({
      id: id,
      uri: uri,
      fileName: storedName.length > 0 ? storedName : readHomeLogoFileNameFromUri(uri),
      width: normalizeHomeLogoDimension(asset.width),
      height: normalizeHomeLogoDimension(asset.height)
    });
  }
  return assets;
}

export function findHomeLogoCustomAsset(
  assets: HomeLogoCustomAsset[],
  id: string
): HomeLogoCustomAsset | undefined {
  for (let index = 0; index < assets.length; index += 1) {
    if (assets[index].id === id) {
      return assets[index];
    }
  }
  return undefined;
}

export function normalizeHomeLogoId(value: string | undefined, assets: HomeLogoCustomAsset[]): string {
  const candidate = value ?? '';
  if (findHomeLogoPreset(candidate) !== undefined) {
    return candidate;
  }
  if (findHomeLogoCustomAsset(assets, candidate) !== undefined) {
    return candidate;
  }
  return HOME_LOGO_BUILTIN_ID;
}

export function normalizeHomeLogoSelection(selection: HomeLogoSelection | undefined): HomeLogoSelection {
  const customAssets = normalizeHomeLogoCustomAssets(selection?.customAssets);
  return {
    id: normalizeHomeLogoId(selection?.id, customAssets),
    customAssets: customAssets
  };
}

export function resolveHomeLogoDisplaySource(selection: HomeLogoSelection | undefined): HomeLogoDisplaySource {
  const normalized = normalizeHomeLogoSelection(selection);
  const preset = findHomeLogoPreset(normalized.id);
  if (preset !== undefined) {
    return {
      rawfileName: preset.rawfileName,
      fileUri: '',
      intrinsicWidth: preset.intrinsicWidth,
      intrinsicHeight: preset.intrinsicHeight,
      tintable: preset.tintable
    };
  }
  const asset = findHomeLogoCustomAsset(normalized.customAssets, normalized.id);
  if (asset !== undefined) {
    return {
      rawfileName: '',
      fileUri: asset.uri,
      intrinsicWidth: asset.width,
      intrinsicHeight: asset.height,
      tintable: false
    };
  }
  const fallback = builtinHomeLogoPreset();
  return {
    rawfileName: fallback.rawfileName,
    fileUri: '',
    intrinsicWidth: fallback.intrinsicWidth,
    intrinsicHeight: fallback.intrinsicHeight,
    tintable: fallback.tintable
  };
}

export function resolveHomeLogoRowLabel(selection: HomeLogoSelection | undefined): string {
  const normalized = normalizeHomeLogoSelection(selection);
  const preset = findHomeLogoPreset(normalized.id);
  if (preset !== undefined) {
    return preset.title;
  }
  return findHomeLogoCustomAsset(normalized.customAssets, normalized.id) !== undefined ?
    '自定义' : builtinHomeLogoPreset().title;
}

function builtinHomeLogoPreset(): HomeLogoPreset {
  return listHomeLogoPresets()[0];
}

function normalizeHomeLogoDimension(value: number | undefined): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    return 0;
  }
  return value;
}
