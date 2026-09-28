import { webview } from '@kit.ArkWeb';
import { RawUserScriptNativeBridgePayload } from '../../features/userscripts/UserScriptNativeBridgeModels';

const COOKIE_LIST_RESULT_LIMIT: number = 512;
const COOKIE_DELETE_EXPIRY: string = 'Thu, 01 Jan 1970 00:00:00 GMT';

/**
 * Tampermonkey and ScriptCat compatible `GM_cookie` cookie details.
 * Only the fields both engines document are read; everything else is ignored.
 */
export interface UserScriptCookieDetails {
  url?: string;
  domain?: string;
  path?: string;
  name?: string;
  value?: string;
  secure?: boolean;
  httpOnly?: boolean;
  session?: boolean;
  hostOnly?: boolean;
  expirationDate?: number | string;
  maxAge?: number | string;
  sameSite?: string;
}

/** One cookie as the page script sees it (`GM_cookie.list` result item). */
export interface UserScriptCookieRecord {
  name: string;
  value: string;
  domain: string;
  hostOnly: boolean;
  path: string;
  secure: boolean;
  httpOnly: boolean;
  session: boolean;
  expirationDate?: number;
  sameSite: string;
  storeId: string;
}

export interface UserScriptCookieTarget {
  url: string;
  host: string;
  path: string;
  scheme: string;
}

export class UserScriptNativeCookieService {
  readDetails(payload: RawUserScriptNativeBridgePayload): UserScriptCookieDetails {
    const rawJson = String(payload.cookieJson ?? '').trim();
    if (rawJson.length <= 0) {
      return {};
    }
    try {
      const parsed = JSON.parse(rawJson) as UserScriptCookieDetails;
      return parsed === null || parsed === undefined ? {} : parsed;
    } catch (_error) {
      return {};
    }
  }

  /**
   * `GM_cookie.list` only ever reads; `set` and `delete` may overwrite the cookie the
   * script names, so callers keep the two request kinds on separate grants.
   */
  async listCookies(
    details: UserScriptCookieDetails,
    currentUrl: string,
    incognito: boolean
  ): Promise<UserScriptCookieRecord[]> {
    const target = this.resolveCookieTarget(details, currentUrl);
    if (target === undefined) {
      return [];
    }
    let cookies: webview.WebHttpCookie[] = [];
    try {
      cookies = await webview.WebCookieManager.fetchAllCookies(incognito);
    } catch (_error) {
      return [];
    }
    return this.selectCookies(cookies, details, target, this.usesRequestContext(details));
  }

  /**
   * A script that names a URL, or names nothing and leans on its own page, asks the same
   * question the browser asks when it sends a request: same host, same path, and no Secure
   * cookie over http. A script that names only a domain asks a storage question instead, so
   * the scheme and the page's path must not narrow the answer.
   */
  usesRequestContext(details: UserScriptCookieDetails): boolean {
    return this.readText(details.url).length > 0 || this.readText(details.domain).length <= 0;
  }

  /**
   * A script may name the URL it means; otherwise the cookie is looked up through the
   * domain it gives, and finally through the page the script is running on.
   */
  resolveCookieTarget(details: UserScriptCookieDetails, currentUrl: string): UserScriptCookieTarget | undefined {
    const rawUrl = this.readText(details.url);
    const candidates: string[] = [];
    if (rawUrl.length > 0) {
      candidates.push(rawUrl);
    }
    const domain = this.readText(details.domain).replace(/^\./, '');
    if (domain.length > 0) {
      const path = this.readText(details.path);
      candidates.push(`${details.secure === true ? 'https' : 'http'}://${domain}${path.length > 0 ? path : '/'}`);
    }
    const pageUrl = currentUrl.trim();
    if (pageUrl.length > 0) {
      candidates.push(pageUrl);
    }
    for (let index = 0; index < candidates.length; index += 1) {
      const target = this.parseTarget(candidates[index]);
      if (target !== undefined) {
        return target;
      }
    }
    return undefined;
  }

  selectCookies(
    cookies: webview.WebHttpCookie[],
    details: UserScriptCookieDetails,
    target: UserScriptCookieTarget,
    applyRequestContext: boolean = true
  ): UserScriptCookieRecord[] {
    const requestedName = this.readText(details.name).toLowerCase();
    const requestedDomain = this.normalizeDomain(this.readText(details.domain));
    const requestedPath = this.readText(details.path);
    const records: UserScriptCookieRecord[] = [];
    for (let index = 0; index < cookies.length && records.length < COOKIE_LIST_RESULT_LIMIT; index += 1) {
      const record = this.toRecord(cookies[index]);
      if (record === undefined) {
        continue;
      }
      if (!this.matchesTarget(record, target, applyRequestContext)) {
        continue;
      }
      if (requestedName.length > 0 && record.name.toLowerCase() !== requestedName) {
        continue;
      }
      if (requestedDomain.length > 0 &&
        !this.matchesDomain(record.domain, requestedDomain, requestedDomain)) {
        continue;
      }
      if (requestedPath.length > 0 && record.path !== requestedPath) {
        continue;
      }
      records.push(record);
    }
    return records;
  }

  /**
   * A delete cannot rely on the script to repeat the stored attributes: an HttpOnly cookie
   * is only replaced when the written value carries the same flags, so the stored cookies
   * are looked up first and each match is expired with its own domain, path, and flags.
   */
  async deleteCookies(
    details: UserScriptCookieDetails,
    currentUrl: string,
    incognito: boolean
  ): Promise<number> {
    const name = this.readText(details.name);
    if (name.length <= 0) {
      return 0;
    }
    const target = this.resolveCookieTarget(details, currentUrl);
    if (target === undefined) {
      return 0;
    }
    let cookies: webview.WebHttpCookie[] = [];
    try {
      cookies = await webview.WebCookieManager.fetchAllCookies(incognito);
    } catch (_error) {
      return 0;
    }
    const matches = this.selectCookiesForDelete(cookies, details, target);
    let deletedCount = 0;
    matches.forEach((cookie: UserScriptCookieRecord) => {
      const url = this.buildCookieUrl(cookie);
      if (url.length <= 0) {
        return;
      }
      if (this.applyCookieValue(url, this.buildDeleteCookieValue(name, cookie), incognito)) {
        deletedCount += 1;
      }
    });
    if (deletedCount > 0) {
      this.persistCookies();
    }
    return deletedCount;
  }

  /**
   * A delete matches on name and host only: the script does not know the stored path or
   * flags, and the cookie it wants gone may live on a path other than the page's own.
   */
  selectCookiesForDelete(
    cookies: webview.WebHttpCookie[],
    details: UserScriptCookieDetails,
    target: UserScriptCookieTarget
  ): UserScriptCookieRecord[] {
    const requestedName = this.readText(details.name).toLowerCase();
    if (requestedName.length <= 0) {
      return [];
    }
    const requestedDomain = this.normalizeDomain(this.readText(details.domain));
    const requestedPath = this.readText(details.path);
    const records: UserScriptCookieRecord[] = [];
    for (let index = 0; index < cookies.length; index += 1) {
      const record = this.toRecord(cookies[index]);
      if (record === undefined || record.name.toLowerCase() !== requestedName) {
        continue;
      }
      const hostMatches = requestedDomain.length > 0 ?
        this.domainsEqual(record.domain, requestedDomain) :
        this.matchesDomain(record.domain, target.host, target.host);
      if (!hostMatches) {
        continue;
      }
      if (requestedPath.length > 0 && record.path !== requestedPath) {
        continue;
      }
      records.push(record);
    }
    return records;
  }

  async setCookie(
    details: UserScriptCookieDetails,
    currentUrl: string,
    incognito: boolean
  ): Promise<boolean> {
    const name = this.readText(details.name);
    if (name.length <= 0) {
      return false;
    }
    const target = this.resolveCookieTarget(details, currentUrl);
    if (target === undefined) {
      return false;
    }
    const value = this.buildSetCookieValue(name, this.readText(details.value, false), details);
    if (!this.applyCookieValue(target.url, value, incognito)) {
      return false;
    }
    this.persistCookies();
    return true;
  }

  buildDispatchScript(
    requestId: string,
    success: boolean,
    message: string = '',
    cookiesJson: string = '[]'
  ): string {
    const eventLiteral = JSON.stringify({
      id: requestId,
      success: success,
      error: message,
      cookiesJson: cookiesJson
    });
    return `
;(function airaUserScriptCookieDispatch() {
  if (typeof window.__airaUserScriptCookieDispatch === 'function') {
    window.__airaUserScriptCookieDispatch(${eventLiteral});
  }
})();
`;
  }

  serializeRecords(records: UserScriptCookieRecord[]): string {
    try {
      return JSON.stringify(records);
    } catch (_error) {
      return '[]';
    }
  }

  buildSetCookieValue(
    name: string,
    value: string,
    details: UserScriptCookieDetails
  ): string {
    const parts: string[] = [`${name}=${value}`];
    const domain = this.readText(details.domain);
    // A host-only cookie stays bound to the URL host: repeating Domain would widen it to
    // the whole domain, which is not what the script asked for.
    if (domain.length > 0 && details.hostOnly !== true) {
      parts.push(`Domain=${domain}`);
    }
    const path = this.readText(details.path);
    parts.push(`Path=${path.length > 0 ? path : '/'}`);
    if (details.session !== true) {
      const expires = this.resolveExpires(details);
      if (expires.length > 0) {
        parts.push(`Expires=${expires}`);
      }
      const maxAge = this.readText(details.maxAge);
      if (maxAge.length > 0) {
        parts.push(`Max-Age=${maxAge}`);
      }
    }
    if (details.secure === true) {
      parts.push('Secure');
    }
    if (details.httpOnly === true) {
      parts.push('HttpOnly');
    }
    const sameSite = this.resolveSameSiteLabel(this.readText(details.sameSite));
    if (sameSite.length > 0) {
      parts.push(`SameSite=${sameSite}`);
    }
    return parts.join('; ');
  }

  buildDeleteCookieValue(name: string, cookie: UserScriptCookieRecord): string {
    const parts: string[] = [`${name}=`, `Expires=${COOKIE_DELETE_EXPIRY}`];
    if (cookie.domain.length > 0) {
      parts.push(`Domain=${cookie.domain}`);
    }
    parts.push(`Path=${cookie.path.length > 0 ? cookie.path : '/'}`);
    if (cookie.secure) {
      parts.push('Secure');
    }
    if (cookie.httpOnly) {
      parts.push('HttpOnly');
    }
    const sameSite = this.resolveSameSiteLabel(cookie.sameSite);
    if (sameSite.length > 0) {
      parts.push(`SameSite=${sameSite}`);
    }
    return parts.join('; ');
  }

  private applyCookieValue(url: string, value: string, incognito: boolean): boolean {
    try {
      webview.WebCookieManager.configCookieSync(url, value, incognito, true);
      return true;
    } catch (_error) {
      return false;
    }
  }

  private persistCookies(): void {
    try {
      webview.WebCookieManager.saveCookieSync();
    } catch (_error) {
    }
  }

  private resolveExpires(details: UserScriptCookieDetails): string {
    const raw = details.expirationDate;
    if (raw === undefined || raw === null) {
      return '';
    }
    if (typeof raw === 'string') {
      const trimmed = raw.trim();
      if (trimmed.length <= 0) {
        return '';
      }
      const numeric = Number(trimmed);
      return Number.isFinite(numeric) ? this.formatEpochSeconds(numeric) : trimmed;
    }
    return Number.isFinite(raw) ? this.formatEpochSeconds(raw) : '';
  }

  private formatEpochSeconds(seconds: number): string {
    if (!Number.isFinite(seconds) || seconds <= 0) {
      return '';
    }
    try {
      return new Date(Math.round(seconds * 1000)).toUTCString();
    } catch (_error) {
      return '';
    }
  }

  private parseTarget(url: string): UserScriptCookieTarget | undefined {
    const trimmed = this.readText(url);
    const schemeSeparator = trimmed.indexOf('://');
    if (schemeSeparator <= 0) {
      return undefined;
    }
    const scheme = trimmed.slice(0, schemeSeparator).toLowerCase();
    if (scheme !== 'http' && scheme !== 'https') {
      return undefined;
    }
    const authorityAndPath = trimmed.slice(schemeSeparator + 3);
    const authorityEnd = this.resolveAuthorityEnd(authorityAndPath);
    const authority = authorityEnd < 0 ? authorityAndPath : authorityAndPath.slice(0, authorityEnd);
    const remainder = authorityEnd < 0 ? '' : authorityAndPath.slice(authorityEnd);
    const hostWithPort = authority.slice(authority.lastIndexOf('@') + 1);
    const portSeparator = hostWithPort.indexOf(':');
    const host = (portSeparator < 0 ? hostWithPort : hostWithPort.slice(0, portSeparator)).toLowerCase();
    if (host.length <= 0) {
      return undefined;
    }
    const queryOrFragmentStart = this.resolveQueryOrFragmentStart(remainder);
    const rawPath = queryOrFragmentStart < 0 ? remainder : remainder.slice(0, queryOrFragmentStart);
    return {
      url: trimmed,
      host: host,
      path: rawPath.length > 0 ? rawPath : '/',
      scheme: scheme
    };
  }

  private resolveAuthorityEnd(authorityAndPath: string): number {
    const slashIndex = authorityAndPath.indexOf('/');
    const queryIndex = authorityAndPath.indexOf('?');
    const fragmentIndex = authorityAndPath.indexOf('#');
    let end = -1;
    const candidates: number[] = [slashIndex, queryIndex, fragmentIndex];
    for (let index = 0; index < candidates.length; index += 1) {
      const candidate = candidates[index];
      if (candidate >= 0 && (end < 0 || candidate < end)) {
        end = candidate;
      }
    }
    return end;
  }

  private resolveQueryOrFragmentStart(remainder: string): number {
    const queryIndex = remainder.indexOf('?');
    const fragmentIndex = remainder.indexOf('#');
    if (queryIndex < 0) {
      return fragmentIndex;
    }
    if (fragmentIndex < 0) {
      return queryIndex;
    }
    return Math.min(queryIndex, fragmentIndex);
  }

  private toRecord(cookie: webview.WebHttpCookie): UserScriptCookieRecord | undefined {
    const name = String(cookie.name ?? '').trim();
    const domain = String(cookie.domain ?? '').trim();
    if (name.length <= 0 || domain.length <= 0) {
      return undefined;
    }
    const expiresDate = String(cookie.expiresDate ?? '').trim();
    const session = cookie.isSessionCookie === true;
    const record: UserScriptCookieRecord = {
      name: name,
      value: String(cookie.value ?? ''),
      domain: domain,
      hostOnly: !domain.startsWith('.'),
      path: String(cookie.path ?? '').trim().length > 0 ? String(cookie.path ?? '').trim() : '/',
      secure: cookie.isSecure === true,
      httpOnly: cookie.isHttpOnly === true,
      session: session,
      sameSite: this.resolveSameSiteName(cookie.samesitePolicy),
      storeId: '0'
    };
    if (!session && expiresDate.length > 0) {
      const epochMs = Date.parse(expiresDate);
      if (Number.isFinite(epochMs)) {
        record.expirationDate = Math.round(epochMs / 1000);
      }
    }
    return record;
  }

  private matchesTarget(
    cookie: UserScriptCookieRecord,
    target: UserScriptCookieTarget,
    applyRequestContext: boolean = true
  ): boolean {
    if (!this.matchesDomain(cookie.domain, target.host, target.host)) {
      return false;
    }
    if (!applyRequestContext) {
      return true;
    }
    if (cookie.secure && target.scheme !== 'https') {
      return false;
    }
    return this.matchesPath(cookie.path, target.path);
  }

  private matchesDomain(cookieDomain: string, host: string, fallbackHost: string): boolean {
    const domain = this.normalizeDomain(cookieDomain);
    const candidate = host.trim().toLowerCase().length > 0 ? host.trim().toLowerCase() : fallbackHost;
    if (domain.length <= 0 || candidate.length <= 0) {
      return false;
    }
    return candidate === domain || candidate.endsWith(`.${domain}`);
  }

  private matchesPath(cookiePath: string, requestPath: string): boolean {
    const path = cookiePath.length > 0 ? cookiePath : '/';
    const request = requestPath.length > 0 ? requestPath : '/';
    if (path === '/') {
      return true;
    }
    if (request === path) {
      return true;
    }
    if (!request.startsWith(path)) {
      return false;
    }
    return path.endsWith('/') || request.charAt(path.length) === '/';
  }

  private normalizeDomain(value: string): string {
    return value.trim().toLowerCase().replace(/^\./, '');
  }

  private domainsEqual(left: string, right: string): boolean {
    return this.normalizeDomain(left) === this.normalizeDomain(right);
  }

  private buildCookieUrl(cookie: UserScriptCookieRecord): string {
    const host = cookie.domain.replace(/^\./, '');
    if (host.length <= 0) {
      return '';
    }
    const scheme = cookie.secure ? 'https://' : 'http://';
    const path = cookie.path.startsWith('/') ? cookie.path : `/${cookie.path}`;
    return `${scheme}${host}${path}`;
  }

  private readText(value: string | number | undefined, trim: boolean = true): string {
    const text = value === undefined || value === null ? '' : String(value);
    return trim ? text.trim() : text;
  }

  private resolveSameSiteName(policy: number): string {
    if (policy === webview.WebHttpCookieSameSitePolicy.NONE) {
      return 'no_restriction';
    }
    if (policy === webview.WebHttpCookieSameSitePolicy.LAX) {
      return 'lax';
    }
    if (policy === webview.WebHttpCookieSameSitePolicy.STRICT) {
      return 'strict';
    }
    return 'unspecified';
  }

  private resolveSameSiteLabel(value: string): string {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'no_restriction' || normalized === 'none' || normalized === 'no-restriction') {
      return 'None';
    }
    if (normalized === 'lax') {
      return 'Lax';
    }
    if (normalized === 'strict') {
      return 'Strict';
    }
    return '';
  }
}
