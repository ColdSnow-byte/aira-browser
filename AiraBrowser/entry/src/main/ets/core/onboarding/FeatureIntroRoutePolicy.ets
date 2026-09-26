export type InitialOnboardingDestination = 'feature_intro' | 'startup_welcome' | 'browser';
export type FeatureIntroExitDestination = 'startup_welcome' | 'browser';

export const FEATURE_INTRO_RESUME_SLIDES_PARAM: string = 'resumeSlides';
export const FEATURE_INTRO_RESUME_SLIDES_VALUE: string = '1';

export interface FeatureIntroResumeRouteParams {
  resumeSlides: string;
}

export function shouldResumeFeatureIntroSlides(value: string | undefined): boolean {
  return value === FEATURE_INTRO_RESUME_SLIDES_VALUE;
}

/**
 * The feature intro is only for a brand-new install that has not finished the
 * sync welcome. An existing install that already passed that welcome goes
 * straight to the browser, even if this intro version was added later.
 */
export function resolveInitialOnboardingDestination(
  featureIntroCompleted: boolean,
  startupWelcomeCompleted: boolean
): InitialOnboardingDestination {
  if (startupWelcomeCompleted) {
    return 'browser';
  }
  if (!featureIntroCompleted) {
    return 'feature_intro';
  }
  return 'startup_welcome';
}

export function resolveFeatureIntroExitDestination(
  startupWelcomeCompleted: boolean
): FeatureIntroExitDestination {
  return startupWelcomeCompleted ? 'browser' : 'startup_welcome';
}
