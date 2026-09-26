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
 * The intro is one sequence. It is finished only when the user enters the browser,
 * by skipping or by leaving the last step. A kill, crash, or shutdown before that
 * starts again at the first page. An install that already finished the welcome
 * still opens the browser.
 */
export function resolveInitialOnboardingDestination(
  _featureIntroCompleted: boolean,
  startupWelcomeCompleted: boolean
): InitialOnboardingDestination {
  if (startupWelcomeCompleted) {
    return 'browser';
  }
  return 'feature_intro';
}

export function resolveFeatureIntroExitDestination(
  startupWelcomeCompleted: boolean
): FeatureIntroExitDestination {
  return startupWelcomeCompleted ? 'browser' : 'startup_welcome';
}
