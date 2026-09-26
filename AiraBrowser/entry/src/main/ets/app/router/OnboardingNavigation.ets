import router from '@ohos.router';
import {
  FEATURE_INTRO_RESUME_SLIDES_PARAM,
  FEATURE_INTRO_RESUME_SLIDES_VALUE
} from '../../core/onboarding/FeatureIntroRoutePolicy';
import {
  BROWSER_SHELL_ROUTE,
  FEATURE_INTRO_APPEARANCE_ROUTE,
  FEATURE_INTRO_HOMEPAGE_ROUTE,
  FEATURE_INTRO_ROUTE,
  FEATURE_INTRO_SEARCH_ENGINE_ROUTE
} from './AppRoutes';

export const ONBOARDING_DISMISS_STACK_PARAM: string = 'dismissOnboardingStack';

/** router.back() re-enters onBackPress. Without this guard one tap pops every page and exits. */
let onboardingReturnInProgress: boolean = false;

export type OnboardingStep = 'slides' | 'search' | 'homepage' | 'appearance' | 'account';

function onboardingStackHasPreviousPage(): boolean {
  const length = Number(router.getLength());
  return Number.isFinite(length) && length > 1;
}

export function previousOnboardingRoute(step: OnboardingStep): string {
  if (step === 'search') {
    return FEATURE_INTRO_ROUTE;
  }
  if (step === 'homepage') {
    return FEATURE_INTRO_SEARCH_ENGINE_ROUTE;
  }
  if (step === 'appearance') {
    return FEATURE_INTRO_HOMEPAGE_ROUTE;
  }
  if (step === 'account') {
    return FEATURE_INTRO_APPEARANCE_ROUTE;
  }
  return FEATURE_INTRO_ROUTE;
}

/**
 * Move back exactly one intro step. A root page opens that step instead of
 * finishing the app, and a re-entrant back press is ignored.
 */
export function returnToPreviousOnboardingStep(step: OnboardingStep): void {
  if (step === 'slides' || onboardingReturnInProgress) {
    return;
  }
  onboardingReturnInProgress = true;
  const previousRoute = previousOnboardingRoute(step);
  if (onboardingStackHasPreviousPage()) {
    router.back();
  } else {
    const params: Record<string, string> = {};
    if (step === 'search') {
      params[FEATURE_INTRO_RESUME_SLIDES_PARAM] = FEATURE_INTRO_RESUME_SLIDES_VALUE;
    }
    router.replaceUrl({
      url: previousRoute,
      params: params
    }).catch((_error: Error): void => undefined);
  }
  setTimeout((): void => {
    onboardingReturnInProgress = false;
  }, 400);
}

/**
 * Enter the browser without clearing the stack first. Clearing first can destroy the
 * only page and exit the app before the browser page exists.
 */
export function finishOnboardingToBrowser(): void {
  router.replaceUrl({
    url: BROWSER_SHELL_ROUTE,
    params: {
      dismissOnboardingStack: '1'
    }
  }).catch((_error: Error): void => undefined);
}

export function dismissOnboardingStackIfRequested(): void {
  const params = router.getParams() as Record<string, string | undefined> | undefined;
  if (params === undefined || params.dismissOnboardingStack !== '1') {
    return;
  }
  router.clear();
}
