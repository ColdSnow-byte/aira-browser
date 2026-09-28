import { UserScriptInstallSourceAdapter } from './UserScriptInstallSourceAdapter';

const GITEE_HOST: string = 'gitee.com';
const GITEE_ALTERNATE_HOST: string = 'www.gitee.com';
const GITEE_REDIRECT_PATH: string = '/link';
const GITEE_REDIRECT_TARGET_PARAM: string = 'target';
const MAX_REDIRECT_DEPTH: number = 3;

/**
 * Gitee rewrites every external link in a rendered Markdown page into its own
 * redirect endpoint, `https://gitee.com/link?target=<encoded>`, and that endpoint answers with an
 * HTML interstitial ("即将跳转到外部网站") instead of a redirect. A `.user.js` behind it therefore
 * arrives as a 1 KB HTML page, so the install fails with a missing `// ==UserScript==` header.
 *
 * Gitee owns that whole endpoint rather than a handful of links, so the decoded `target` replaces
 * the install URL whenever it is itself an installable script URL. Anything else — an article link,
 * a repository page — resolves to nothing and keeps its ordinary navigation.
 */
export class UserScriptGiteeRedirectInstallUrl implements UserScriptInstallSourceAdapter {
  resolveSourceUrls(url: string): string[] {
    let candidate = url.trim();
    let sawRedirect = false;
    // A Gitee page can be mirrored, so the wrapper may repeat. Bounded so a crafted link
    // cannot spin the resolver.
    for (let depth = 0; depth < MAX_REDIRECT_DEPTH; depth++) {
      if (!this.isGiteeRedirectUrl(candidate)) {
        break;
      }
      const target = this.readTarget(candidate);
      if (target.length === 0) {
        return [];
      }
      sawRedirect = true;
      candidate = target;
    }
    // Only a link that really was a Gitee redirect is this adapter's business; an ordinary
    // `.user.js` URL must keep resolving through the adapters that own it. Stopping at the depth
    // limit leaves another redirect, which is still the interstitial, so it resolves to nothing.
    if (!sawRedirect || this.isGiteeRedirectUrl(candidate) || !this.isHttpUrl(candidate) ||
      !this.looksLikeUserScriptUrl(candidate)) {
      return [];
    }
    return [candidate];
  }

  private isGiteeRedirectUrl(url: string): boolean {
    return this.isHttpUrl(url) && this.isGiteeHost(this.readHostname(url)) &&
      this.readPathname(url) === GITEE_REDIRECT_PATH;
  }

  private readTarget(url: string): string {
    const encoded = this.readQueryParam(url, GITEE_REDIRECT_TARGET_PARAM);
    if (encoded.length === 0) {
      return '';
    }
    try {
      return decodeURIComponent(encoded).trim();
    } catch (_error) {
      return '';
    }
  }

  private looksLikeUserScriptUrl(target: string): boolean {
    return /\.user\.js(?:[?#]|$)/i.test(target);
  }

  private readQueryParam(url: string, key: string): string {
    const hashIndex = url.indexOf('#');
    const beforeHash = hashIndex >= 0 ? url.substring(0, hashIndex) : url;
    const queryIndex = beforeHash.indexOf('?');
    if (queryIndex < 0) {
      return '';
    }
    const parts = beforeHash.substring(queryIndex + 1).split('&');
    for (let index = 0; index < parts.length; index++) {
      const part = parts[index];
      const separator = part.indexOf('=');
      const rawKey = separator < 0 ? part : part.substring(0, separator);
      if (rawKey !== key) {
        continue;
      }
      return separator < 0 ? '' : part.substring(separator + 1);
    }
    return '';
  }

  private readHostname(url: string): string {
    const authority = this.readAuthority(url);
    const at = authority.lastIndexOf('@');
    const host = at >= 0 ? authority.substring(at + 1) : authority;
    const colon = host.indexOf(':');
    return (colon >= 0 ? host.substring(0, colon) : host).toLowerCase();
  }

  private readAuthority(url: string): string {
    const schemeIndex = url.indexOf('://');
    if (schemeIndex < 0) {
      return '';
    }
    const rest = url.substring(schemeIndex + 3);
    return rest.substring(0, this.readAuthorityEnd(rest));
  }

  private readAuthorityEnd(rest: string): number {
    let end = rest.length;
    const hashIndex = rest.indexOf('#');
    if (hashIndex >= 0 && hashIndex < end) {
      end = hashIndex;
    }
    const slash = rest.indexOf('/');
    if (slash >= 0 && slash < end) {
      end = slash;
    }
    const question = rest.indexOf('?');
    if (question >= 0 && question < end) {
      end = question;
    }
    return end;
  }

  private readPathname(url: string): string {
    const schemeIndex = url.indexOf('://');
    if (schemeIndex < 0) {
      return '';
    }
    const rest = url.substring(schemeIndex + 3);
    const slash = rest.indexOf('/');
    if (slash < 0) {
      return '';
    }
    const pathAndQuery = rest.substring(slash);
    const question = pathAndQuery.indexOf('?');
    const path = question >= 0 ? pathAndQuery.substring(0, question) : pathAndQuery;
    // A trailing slash is the same endpoint, so it must not change the decision.
    return path.replace(/\/+$/, '');
  }

  private isGiteeHost(hostname: string): boolean {
    return hostname === GITEE_HOST || hostname === GITEE_ALTERNATE_HOST;
  }

  private isHttpUrl(url: string): boolean {
    const normalized = url.toLowerCase();
    return normalized.startsWith('http://') || normalized.startsWith('https://');
  }
}
