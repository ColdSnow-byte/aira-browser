export interface FeatureIntroLayoutInput {
  windowWidthVp: number;
  windowHeightVp: number;
  topInsetVp: number;
  bottomInsetVp: number;
}

export interface FeatureIntroLayout {
  videoHeightVp: number;
  /** 0 keeps the phone full-bleed slot. A positive width is a centered 9:8 frame. */
  videoWidthVp: number;
  contentMaxWidthVp: number;
  horizontalPaddingVp: number;
  bottomPaddingVp: number;
}

export const FEATURE_INTRO_VIDEO_ASPECT_WIDTH: number = 9;
export const FEATURE_INTRO_VIDEO_ASPECT_HEIGHT: number = 8;
export const FEATURE_INTRO_CONTENT_MAX_WIDTH_VP: number = 430;
export const FEATURE_INTRO_HORIZONTAL_PADDING_VP: number = 24;
export const FEATURE_INTRO_CONTENT_RESERVE_VP: number = 236;
export const FEATURE_INTRO_MIN_VIDEO_HEIGHT_VP: number = 96;
export const FEATURE_INTRO_CONTAINED_MIN_WIDTH_VP: number = 600;
export const FEATURE_INTRO_BOTTOM_PADDING_VP: number = 24;


/**
 * The intro videos are 9:8. A phone keeps a full-bleed slot of that shape and
 * only shrinks it on a short window. A wide window no longer stops at a short
 * band: a portrait tablet grows to the real frame, and a landscape tablet or
 * PC window centers the largest 9:8 frame that still leaves the title and button.
 */
export function resolveFeatureIntroLayout(input: FeatureIntroLayoutInput): FeatureIntroLayout {
  const width = positive(input.windowWidthVp);
  const height = positive(input.windowHeightVp);
  const topInset = positive(input.topInsetVp);
  const bottomInset = positive(input.bottomInsetVp);
  const available = Math.max(0, height - topInset - bottomInset);
  const room = Math.max(0, available - FEATURE_INTRO_CONTENT_RESERVE_VP);
  const preferred = width * FEATURE_INTRO_VIDEO_ASPECT_HEIGHT / FEATURE_INTRO_VIDEO_ASPECT_WIDTH;
  const fittedHeight = Math.min(preferred, room);
  const videoHeight = room >= FEATURE_INTRO_MIN_VIDEO_HEIGHT_VP
    ? Math.max(FEATURE_INTRO_MIN_VIDEO_HEIGHT_VP, fittedHeight)
    : fittedHeight;
  const roundedHeight = Math.round(videoHeight);
  const contain = width >= FEATURE_INTRO_CONTAINED_MIN_WIDTH_VP && preferred > room && roundedHeight > 0;
  const videoWidth = contain
    ? roundedHeight * FEATURE_INTRO_VIDEO_ASPECT_WIDTH / FEATURE_INTRO_VIDEO_ASPECT_HEIGHT
    : 0;
  return {
    videoHeightVp: roundedHeight,
    videoWidthVp: Math.round(videoWidth),
    contentMaxWidthVp: FEATURE_INTRO_CONTENT_MAX_WIDTH_VP,
    horizontalPaddingVp: FEATURE_INTRO_HORIZONTAL_PADDING_VP,
    bottomPaddingVp: Math.max(FEATURE_INTRO_BOTTOM_PADDING_VP, Math.round(bottomInset))
  };
}

function positive(value: number): number {
  return Number.isFinite(value) && value > 0 ? value : 0;
}
