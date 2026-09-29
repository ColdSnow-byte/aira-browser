export type CloudFeatureEntryView = 'login' | 'sync-method' | 'personal-server';

export function shouldAutoSelectAiraCloud(options: {
  airaCloudAvailable: boolean;
  loggedIn: boolean;
  selectedSource: string | null;
  loginJustCompleted: boolean;
}): boolean {
  if (!options.airaCloudAvailable || !options.loggedIn) return false;
  if (options.loginJustCompleted) return true;
  return !options.selectedSource;
}

export function resolveCloudFeatureEntryView(options: {
  hasAiraDesktopSession: boolean;
  airaCloudAvailable: boolean;
}): CloudFeatureEntryView {
  if (options.hasAiraDesktopSession) return 'sync-method';
  return options.airaCloudAvailable ? 'login' : 'personal-server';
}
