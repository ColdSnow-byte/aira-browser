import { AiraSyncSettings, resolveAiraHuaweiAccountIdentity } from '../../common/models/AiraSyncModels';

/**
 * The welcome intro exists to point a brand-new install at a sync path. Once the
 * user has either signed in or configured a provider, the intro has done its job
 * and should hand off to the browser shell instead of asking again.
 */
/**
 * Personal server and WebDAV already chose a sync path on their own screens.
 * Huawei login only identifies the account, so it must not skip the content switches.
 */
export function shouldCompleteStartupWelcomeOnResume(settings: AiraSyncSettings): boolean {
  if (settings.remoteKind === 'webdav' || settings.remoteKind === 'self_hosted') {
    return true;
  }
  if (settings.webdav.endpoint.trim().length > 0) {
    return true;
  }
  const selfHosted = settings.selfHosted;
  return selfHosted !== undefined && selfHosted.instanceId.trim().length > 0;
}

export function hasStartupWelcomeIntroAccountOrSync(settings: AiraSyncSettings): boolean {
  if (resolveAiraHuaweiAccountIdentity(settings.huaweiCloud, settings.huaweiSpace).uid.trim().length > 0) {
    return true;
  }
  if (settings.remoteKind !== 'none') {
    return true;
  }
  if (settings.webdav.endpoint.trim().length > 0) {
    return true;
  }
  const selfHosted = settings.selfHosted;
  return selfHosted !== undefined && selfHosted.instanceId.trim().length > 0;
}
