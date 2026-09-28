/**
 * Which visible search host should own the next presentation.
 * A hidden chrome is not a successful target: split style with the bars covered
 * stays unavailable instead of falling through to the suppressed floating panel.
 */
export type BrowserSearchInvocationHostKind = 'large_screen' | 'split' | 'floating' | 'unavailable';

export interface BrowserSearchInvocationHostInput {
  largeScreenShellActive: boolean;
  splitToolbarChromeActive: boolean;
  /** Centered-home search overlay is already opening, even if the bars are not painted. */
  splitSearchOverlayPrepared: boolean;
  legacyFloatingToolbarSuppressed: boolean;
}

export function resolveBrowserSearchInvocationHost(
  input: BrowserSearchInvocationHostInput
): BrowserSearchInvocationHostKind {
  if (input.largeScreenShellActive) {
    return 'large_screen';
  }
  if (input.splitToolbarChromeActive || input.splitSearchOverlayPrepared) {
    return 'split';
  }
  if (input.legacyFloatingToolbarSuppressed) {
    return 'unavailable';
  }
  return 'floating';
}

/**
 * A close animation may finish after a newer search has opened. Only the close
 * that is still current, and that was not reopened, may reset shared state.
 */
export function shouldCompleteSearchClose(
  closeGeneration: number,
  callbackGeneration: number,
  searchReopened: boolean
): boolean {
  return closeGeneration > 0 &&
    callbackGeneration === closeGeneration &&
    !searchReopened;
}
