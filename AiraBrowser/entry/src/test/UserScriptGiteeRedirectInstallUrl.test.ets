import { describe, expect, it } from '@ohos/hypium';
import { UserScriptGiteeRedirectInstallUrl } from
  '../main/ets/services/userscripts/UserScriptGiteeRedirectInstallUrl';

const REDIRECT_PREFIX: string = 'https://gitee.com/link?target=';
const ENCODED_SCRIPT: string =
  'https%3A%2F%2Fupdate.greasyfork.org%2Fscripts%2F483475.user.js';
const TARGET_SCRIPT: string = 'https://update.greasyfork.org/scripts/483475.user.js';

export default function userScriptGiteeRedirectInstallUrlTest(): void {
  describe('Gitee external link redirect userscript install URL', () => {
    it('decodes the wrapped target of a Gitee external link', 0, () => {
      const urls = new UserScriptGiteeRedirectInstallUrl().resolveSourceUrls(REDIRECT_PREFIX + ENCODED_SCRIPT);

      expect(urls.length).assertEqual(1);
      expect(urls[0]).assertEqual(TARGET_SCRIPT);
    });

    it('keeps a doubly encoded script path and its query intact', 0, () => {
      const wrapped = `https://gitee.com/link?target=${encodeURIComponent(
        'https://fastly.jsdelivr.net/gh/WhiteSevs/TamperMonkeyScript/scripts-vite/' +
        '%E3%80%90%E7%A7%BB%E5%8A%A8%E7%AB%AF%E3%80%91%E7%99%BE%E5%BA%A6%E7%B3%BB%E4%BC%98%E5%8C%96/dist/' +
        '%E3%80%90%E7%A7%BB%E5%8A%A8%E7%AB%AF%E3%80%91%E7%99%BE%E5%BA%A6%E7%B3%BB%E4%BC%98%E5%8C%96.user.js'
      )}`;
      const urls = new UserScriptGiteeRedirectInstallUrl().resolveSourceUrls(wrapped);

      expect(urls.length).assertEqual(1);
      expect(urls[0]).assertEqual(
        'https://fastly.jsdelivr.net/gh/WhiteSevs/TamperMonkeyScript/scripts-vite/' +
        '%E3%80%90%E7%A7%BB%E5%8A%A8%E7%AB%AF%E3%80%91%E7%99%BE%E5%BA%A6%E7%B3%BB%E4%BC%98%E5%8C%96/dist/' +
        '%E3%80%90%E7%A7%BB%E5%8A%A8%E7%AB%AF%E3%80%91%E7%99%BE%E5%BA%A6%E7%B3%BB%E4%BC%98%E5%8C%96.user.js'
      );
    });

    it('accepts the trailing slash and the www host of the same endpoint', 0, () => {
      const resolver = new UserScriptGiteeRedirectInstallUrl();

      expect(resolver.resolveSourceUrls(
        `https://gitee.com/link/?target=${ENCODED_SCRIPT}`
      )[0]).assertEqual(TARGET_SCRIPT);
      expect(resolver.resolveSourceUrls(
        `https://www.gitee.com/link?target=${ENCODED_SCRIPT}`
      )[0]).assertEqual(TARGET_SCRIPT);
    });

    it('leaves a Gitee external link that is not an installable script alone', 0, () => {
      const resolver = new UserScriptGiteeRedirectInstallUrl();
      const articleTarget = 'https%3A%2F%2Ffishjar.github.io%2Fkiss-translator%2Foptions.html';

      expect(resolver.resolveSourceUrls(`https://gitee.com/link?target=${articleTarget}`).length)
        .assertEqual(0);
      expect(resolver.resolveSourceUrls('https://gitee.com/daybreak166/ViaBrowserCollection').length)
        .assertEqual(0);
      expect(resolver.resolveSourceUrls('https://gitee.com/link').length).assertEqual(0);
      expect(resolver.resolveSourceUrls(TARGET_SCRIPT).length).assertEqual(0);
      expect(resolver.resolveSourceUrls('https://example.com/link?target=' + ENCODED_SCRIPT).length)
        .assertEqual(0);
    });

    it('does not let a hostile target reach another origin', 0, () => {
      const resolver = new UserScriptGiteeRedirectInstallUrl();

      expect(resolver.resolveSourceUrls('javascript:alert(1)').length).assertEqual(0);
      expect(resolver.resolveSourceUrls('https://gitee.com/link?target=not%20a%20url').length)
        .assertEqual(0);
      expect(resolver.resolveSourceUrls('https://gitee.com/link?target=%E0%A4%A').length)
        .assertEqual(0);
      expect(resolver.resolveSourceUrls('https://evil.com/link?target=' + ENCODED_SCRIPT).length)
        .assertEqual(0);
      expect(resolver.resolveSourceUrls('https://gitee.com@evil.com/link?target=' + ENCODED_SCRIPT).length)
        .assertEqual(0);
    });

    it('unwraps a repeated wrapper within its depth budget', 0, () => {
      const resolver = new UserScriptGiteeRedirectInstallUrl();
      const doubleWrapped = REDIRECT_PREFIX + encodeURIComponent(REDIRECT_PREFIX + ENCODED_SCRIPT);

      expect(resolver.resolveSourceUrls(doubleWrapped)[0]).assertEqual(TARGET_SCRIPT);
    });

    it('resolves to nothing rather than another interstitial past the depth budget', 0, () => {
      const resolver = new UserScriptGiteeRedirectInstallUrl();
      let url = REDIRECT_PREFIX + ENCODED_SCRIPT;
      for (let depth = 0; depth < 4; depth++) {
        url = REDIRECT_PREFIX + encodeURIComponent(url);
      }

      const urls = resolver.resolveSourceUrls(url);

      expect(urls.length).assertEqual(0);
    });
  });
}
