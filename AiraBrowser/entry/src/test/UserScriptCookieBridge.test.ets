import { describe, expect, it } from '@ohos/hypium';
import { webview } from '@kit.ArkWeb';
import {
  InstalledUserScriptState,
  UserScriptGrant
} from '../main/ets/features/userscripts/UserScriptMetadataModels';
import { UserScriptCapabilityContractService } from
  '../main/ets/services/userscripts/UserScriptCapabilityContractService';
import {
  UserScriptCookieDetails,
  UserScriptCookieRecord,
  UserScriptCookieTarget,
  UserScriptNativeCookieService
} from '../main/ets/services/userscripts/UserScriptNativeCookieService';

const SCRIPT_ID: string = 'cookie-test-script';

function buildScript(grants: UserScriptGrant[], source: string = '// no metadata'): InstalledUserScriptState {
  return {
    id: SCRIPT_ID,
    name: 'Cookie test',
    namespace: '',
    version: '1.0.0',
    description: '',
    iconUrl: '',
    source: source,
    sourceUrl: 'https://example.com/cookie.user.js',
    updateUrl: '',
    downloadUrl: '',
    enabled: true,
    matches: ['*://*/*'],
    includes: [],
    excludeMatches: [],
    excludes: [],
    grants: grants,
    requireUrls: [],
    requireSources: [],
    resources: [],
    connectRules: [],
    noframes: false,
    runAt: 'document-end',
    installSource: 'url',
    createdAt: 0,
    updatedAt: 1,
    lastCheckedAt: 0
  };
}

function buildStoredCookie(
  name: string,
  value: string,
  domain: string,
  path: string,
  isSecure: boolean,
  isHttpOnly: boolean,
  isSessionCookie: boolean,
  samesitePolicy: number,
  expiresDate: string = ''
): webview.WebHttpCookie {
  return {
    name: name,
    value: value,
    domain: domain,
    path: path,
    isSecure: isSecure,
    isHttpOnly: isHttpOnly,
    isSessionCookie: isSessionCookie,
    samesitePolicy: samesitePolicy,
    expiresDate: expiresDate
  };
}

function resolveTarget(
  service: UserScriptNativeCookieService,
  details: UserScriptCookieDetails,
  pageUrl: string
): UserScriptCookieTarget {
  const target = service.resolveCookieTarget(details, pageUrl);
  if (target === undefined) {
    throw new Error('cookie-target-unresolved');
  }
  return target;
}

function buildCookieRecord(overrides: UserScriptCookieRecord): UserScriptCookieRecord {
  return {
    name: overrides.name,
    value: overrides.value,
    domain: overrides.domain,
    hostOnly: overrides.hostOnly,
    path: overrides.path,
    secure: overrides.secure,
    httpOnly: overrides.httpOnly,
    session: overrides.session,
    expirationDate: overrides.expirationDate,
    sameSite: overrides.sameSite,
    storeId: overrides.storeId
  };
}

export default function userScriptCookieBridgeTest(): void {
  describe('UserScript GM_cookie capability', () => {
    it('normalizes the Tampermonkey cookie grant', 0, () => {
      const contract = new UserScriptCapabilityContractService();

      expect(contract.normalizeGrant('GM_cookie')).assertEqual('GM_cookie');
      expect(contract.normalizeGrant('GM.cookie')).assertEqual('GM_cookie');
      expect(contract.normalizeGrant('GM_cookie.list')).assertEqual('GM_cookie');
      expect(contract.normalizeGrant('GM_cookie.set')).assertEqual('GM_cookieSet');
      expect(contract.normalizeGrant('GM_cookie.delete')).assertEqual('GM_cookieDelete');
    });

    it('lets one GM_cookie grant cover list, set, and delete', 0, () => {
      const contract = new UserScriptCapabilityContractService();
      const script = buildScript(['GM_cookie']);

      expect(contract.hasGrant(script, 'GM_cookie')).assertTrue();
      expect(contract.hasGrant(script, 'GM_cookieSet')).assertTrue();
      expect(contract.hasGrant(script, 'GM_cookieDelete')).assertTrue();
    });

    it('reads a source-declared grant that the metadata pass did not normalize', 0, () => {
      const contract = new UserScriptCapabilityContractService();
      const script = buildScript(['none'], '// ==UserScript==\n// @grant GM_cookie\n// ==/UserScript==\n');

      expect(contract.hasGrant(script, 'GM_cookie')).assertTrue();
      expect(contract.hasGrant(script, 'GM_cookieDelete')).assertTrue();
    });

    it('keeps cookie access out of a script that never asked for it', 0, () => {
      const contract = new UserScriptCapabilityContractService();
      const script = buildScript(['GM_getValue']);

      expect(contract.hasGrant(script, 'GM_cookie')).assertFalse();
      expect(contract.hasGrant(script, 'GM_cookieSet')).assertFalse();
      expect(contract.hasGrant(script, 'GM_cookieDelete')).assertFalse();
    });

    it('routes each cookie operation to its own native executor', 0, () => {
      const contract = new UserScriptCapabilityContractService();
      const listRoute = contract.resolveNativeRoute('cookieList', 'GM_cookie');
      const setRoute = contract.resolveNativeRoute('cookieSet', 'GM_cookieSet');
      const deleteRoute = contract.resolveNativeRoute('cookieDelete', 'GM_cookieDelete');

      expect(listRoute === undefined).assertFalse();
      expect(listRoute?.executor).assertEqual('cookie_list');
      expect(setRoute?.executor).assertEqual('cookie_set');
      expect(deleteRoute?.executor).assertEqual('cookie_delete');
      expect(contract.resolveNativeRoute('cookieList', 'GM_cookieSet')).assertUndefined();
    });

    it('publishes cookie flags and routes into the injected runtime manifest', 0, () => {
      const contract = new UserScriptCapabilityContractService();
      const manifest = contract.buildRuntimeManifest(buildScript(['GM_cookie']));

      expect(manifest.grantFlagsLiteral.indexOf('cookieList:true')).assertLarger(0);
      expect(manifest.grantFlagsLiteral.indexOf('cookieSet:true')).assertLarger(0);
      expect(manifest.grantFlagsLiteral.indexOf('cookieDelete:true')).assertLarger(0);
      expect(manifest.nativeRoutesLiteral.indexOf('"cookieList"')).assertLarger(0);
      expect(manifest.nativeRoutesLiteral.indexOf('cookie_delete')).assertLarger(0);
    });

    it('lists cookie permissions in plain language for the management screen', 0, () => {
      const contract = new UserScriptCapabilityContractService();
      const summary = contract.summarizeGrants(['GM_cookie']);

      expect(summary.indexOf('读取网站 Cookie')).assertLarger(0);
      expect(summary.indexOf('修改网站 Cookie')).assertLarger(0);
      expect(summary.indexOf('删除网站 Cookie')).assertLarger(0);
    });
  });

  describe('UserScript cookie bridge payloads', () => {
    it('reads cookie details from the bridge payload and survives broken JSON', 0, () => {
      const service = new UserScriptNativeCookieService();

      expect(service.readDetails({ cookieJson: '{"name":"a","value":"1"}' }).name).assertEqual('a');
      expect(service.readDetails({ cookieJson: '{oops' }).name).assertUndefined();
      expect(service.readDetails({}).name).assertUndefined();
    });

    it('resolves the query target from the script URL, the domain, or the page', 0, () => {
      const service = new UserScriptNativeCookieService();
      const fromUrl = service.resolveCookieTarget({ url: 'https://linux.do/t/topic/1' }, 'https://other.test/');
      const fromDomain = service.resolveCookieTarget({ domain: '.linux.do', secure: true }, '');
      const fromPage = service.resolveCookieTarget({}, 'https://linux.do/t/topic/1');

      expect(fromUrl?.host).assertEqual('linux.do');
      expect(fromUrl?.path).assertEqual('/t/topic/1');
      expect(fromDomain?.scheme).assertEqual('https');
      expect(fromDomain?.host).assertEqual('linux.do');
      expect(fromPage?.host).assertEqual('linux.do');
      expect(service.resolveCookieTarget({}, '')).assertUndefined();
    });

    it('returns the login cookies a page script cannot read itself', 0, () => {
      const service = new UserScriptNativeCookieService();
      const target = resolveTarget(service, { url: 'https://linux.do/t/topic/1/2' }, '');
      const cookies: webview.WebHttpCookie[] = [
        buildStoredCookie('_t', 'session-value', '.linux.do', '/', true, true, true,
          webview.WebHttpCookieSameSitePolicy.LAX),
        buildStoredCookie('g_state', 'state', '.linux.do', '/', true, false, false,
          webview.WebHttpCookieSameSitePolicy.NONE, 'Wed, 01 Oct 2025 00:00:00 GMT'),
        buildStoredCookie('admin', 'other', '.example.com', '/', true, false, true,
          webview.WebHttpCookieSameSitePolicy.LAX)
      ];

      const records = service.selectCookies(cookies, {}, target);

      expect(records.length).assertEqual(2);
      expect(records[0].name).assertEqual('_t');
      expect(records[0].httpOnly).assertTrue();
      expect(records[0].session).assertTrue();
      expect(records[0].sameSite).assertEqual('lax');
      expect(records[0].hostOnly).assertFalse();
      expect(records[1].name).assertEqual('g_state');
      expect(records[1].session).assertFalse();
      expect(records[1].expirationDate).assertEqual(1759276800);
      expect(records[1].sameSite).assertEqual('no_restriction');
    });

    it('filters a list request by name, domain, and path', 0, () => {
      const service = new UserScriptNativeCookieService();
      const target = resolveTarget(service, { url: 'https://linux.do/t/topic/1' }, '');
      const cookies: webview.WebHttpCookie[] = [
        buildStoredCookie('_t', 'a', '.linux.do', '/', true, true, true,
          webview.WebHttpCookieSameSitePolicy.LAX),
        buildStoredCookie('_forum_session', 'b', '.linux.do', '/t', true, true, true,
          webview.WebHttpCookieSameSitePolicy.LAX),
        buildStoredCookie('_t', 'c', '.linux.do', '/t', true, true, true,
          webview.WebHttpCookieSameSitePolicy.LAX)
      ];

      const all = service.selectCookies(cookies, {}, target);
      const byName = service.selectCookies(cookies, { name: '_t' }, target);
      const byPath = service.selectCookies(cookies, { path: '/t' }, target);
      const byForeignDomain = service.selectCookies(cookies, { domain: 'example.com' }, target);
      const byNameAndPath = service.selectCookies(cookies, { name: '_t', path: '/t' }, target);

      expect(all.length).assertEqual(3);
      expect(byName.length).assertEqual(2);
      expect(byPath.length).assertEqual(2);
      expect(byForeignDomain.length).assertEqual(0);
      expect(byNameAndPath.length).assertEqual(1);
      expect(byNameAndPath[0].value).assertEqual('c');
    });

    it('answers a domain-only query with the site Secure cookies too', 0, () => {
      const service = new UserScriptNativeCookieService();
      const details: UserScriptCookieDetails = { domain: 'linux.do' };
      const target = resolveTarget(service, details, 'https://linux.do/t/topic/1');
      const cookies: webview.WebHttpCookie[] = [
        buildStoredCookie('_t', 'a', '.linux.do', '/', true, true, true,
          webview.WebHttpCookieSameSitePolicy.LAX),
        buildStoredCookie('_forum_session', 'b', '.linux.do', '/t', true, true, true,
          webview.WebHttpCookieSameSitePolicy.LAX)
      ];

      const domainScoped = service.selectCookies(cookies, details, target, service.usesRequestContext(details));
      const pageScoped = service.selectCookies(
        cookies,
        {},
        resolveTarget(service, {}, 'http://linux.do/t/other'),
        service.usesRequestContext({})
      );

      expect(service.usesRequestContext(details)).assertFalse();
      expect(service.usesRequestContext({ url: 'https://linux.do/' })).assertTrue();
      expect(domainScoped.length).assertEqual(2);
      expect(pageScoped.length).assertEqual(0);
    });

    it('leaves a cookie of another host alone', 0, () => {
      const service = new UserScriptNativeCookieService();
      const target = resolveTarget(service, { url: 'https://linux.do/t/topic/1' }, '');
      const cookies: webview.WebHttpCookie[] = [
        buildStoredCookie('shared', 'a', '.example.com', '/', true, false, true,
          webview.WebHttpCookieSameSitePolicy.LAX),
        buildStoredCookie('shared', 'b', '.do', '/', true, false, true,
          webview.WebHttpCookieSameSitePolicy.LAX)
      ];

      expect(service.selectCookies(cookies, {}, target).length).assertEqual(0);
    });
  });

  describe('UserScript cookie delete and set', () => {
    it('deletes every stored variant of the named cookie', 0, () => {
      const service = new UserScriptNativeCookieService();
      const target = resolveTarget(service, { url: 'https://linux.do/t/topic/1' }, '');
      const cookies: webview.WebHttpCookie[] = [
        buildStoredCookie('_t', 'a', '.linux.do', '/', true, true, true,
          webview.WebHttpCookieSameSitePolicy.LAX),
        buildStoredCookie('_t', 'b', '.linux.do', '/t', true, false, true,
          webview.WebHttpCookieSameSitePolicy.LAX),
        buildStoredCookie('keep', 'c', '.linux.do', '/', true, false, true,
          webview.WebHttpCookieSameSitePolicy.LAX)
      ];

      const matches = service.selectCookiesForDelete(cookies, { name: '_t' }, target);

      expect(matches.length).assertEqual(2);
      expect(matches[0].path).assertEqual('/');
      expect(matches[1].path).assertEqual('/t');
    });

    it('expires the stored cookie with its own flags so an HttpOnly cookie can go', 0, () => {
      const service = new UserScriptNativeCookieService();
      const cookie = buildCookieRecord({
        name: '_t',
        value: 'a',
        domain: '.linux.do',
        hostOnly: false,
        path: '/',
        secure: true,
        httpOnly: true,
        session: true,
        sameSite: 'lax',
        storeId: '0'
      });
      const value = service.buildDeleteCookieValue('_t', cookie);

      expect(value.indexOf('_t=;')).assertEqual(0);
      expect(value.indexOf('Expires=Thu, 01 Jan 1970 00:00:00 GMT')).assertLarger(0);
      expect(value.indexOf('Domain=.linux.do')).assertLarger(0);
      expect(value.indexOf('Path=/')).assertLarger(0);
      expect(value.indexOf('Secure')).assertLarger(0);
      expect(value.indexOf('HttpOnly')).assertLarger(0);
      expect(value.indexOf('SameSite=Lax')).assertLarger(0);
    });

    it('writes the documented Set-Cookie attributes', 0, () => {
      const service = new UserScriptNativeCookieService();
      const value = service.buildSetCookieValue('token', 'abc', {
        domain: 'linux.do',
        path: '/',
        secure: true,
        httpOnly: true,
        expirationDate: 1767225600,
        sameSite: 'strict'
      });

      expect(value.indexOf('token=abc')).assertEqual(0);
      expect(value.indexOf('Domain=linux.do')).assertLarger(0);
      expect(value.indexOf('Path=/')).assertLarger(0);
      expect(value.indexOf('Expires=Thu, 01 Jan 2026 00:00:00 GMT')).assertLarger(0);
      expect(value.indexOf('Secure')).assertLarger(0);
      expect(value.indexOf('HttpOnly')).assertLarger(0);
      expect(value.indexOf('SameSite=Strict')).assertLarger(0);
    });

    it('keeps a host-only cookie host-only', 0, () => {
      const service = new UserScriptNativeCookieService();
      const value = service.buildSetCookieValue('a', '1', {
        domain: 'linux.do',
        hostOnly: true
      });

      expect(value.indexOf('Domain=')).assertEqual(-1);
      expect(value.indexOf('Path=/')).assertLarger(0);
    });

    it('leaves a session cookie without an expiry and honours Max-Age', 0, () => {
      const service = new UserScriptNativeCookieService();
      const sessionValue = service.buildSetCookieValue('a', '1', {
        session: true,
        expirationDate: 1767225600
      });
      const maxAgeValue = service.buildSetCookieValue('a', '1', { maxAge: 60 });

      expect(sessionValue.indexOf('Expires=')).assertEqual(-1);
      expect(sessionValue.indexOf('Max-Age=')).assertEqual(-1);
      expect(maxAgeValue.indexOf('Max-Age=60')).assertLarger(0);
    });

    it('drops an unknown sameSite instead of writing a broken attribute', 0, () => {
      const service = new UserScriptNativeCookieService();

      expect(service.buildSetCookieValue('a', '1', { sameSite: 'whatever' }).indexOf('SameSite=')).assertEqual(-1);
      expect(service.buildSetCookieValue('a', '1', { sameSite: 'no_restriction' })
        .indexOf('SameSite=None')).assertLarger(0);
    });
  });

  describe('UserScript cookie dispatch', () => {
    it('carries the cookie list back into the page callback', 0, () => {
      const service = new UserScriptNativeCookieService();
      const script = service.buildDispatchScript(
        'request-1',
        true,
        '',
        service.serializeRecords([buildCookieRecord({
          name: '_t',
          value: 'a',
          domain: '.linux.do',
          hostOnly: false,
          path: '/',
          secure: true,
          httpOnly: true,
          session: true,
          sameSite: 'lax',
          storeId: '0'
        })])
      );

      expect(script.indexOf('window.__airaUserScriptCookieDispatch')).assertLarger(0);
      expect(script.indexOf('"id":"request-1"')).assertLarger(0);
      expect(script.indexOf('"success":true')).assertLarger(0);
      expect(script.indexOf('httpOnly')).assertLarger(0);
    });

    it('reports a failed request as a script-visible error', 0, () => {
      const service = new UserScriptNativeCookieService();
      const script = service.buildDispatchScript('request-2', false, 'grant-denied');

      expect(script.indexOf('"success":false')).assertLarger(0);
      expect(script.indexOf('grant-denied')).assertLarger(0);
    });
  });
}
