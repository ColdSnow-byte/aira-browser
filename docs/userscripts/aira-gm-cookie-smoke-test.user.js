// ==UserScript==
// @name         Aira GM_cookie 验证
// @namespace    https://github.com/mason173/aira-browser
// @version      1.0.0
// @description  验证 Aira 用户脚本引擎的 GM_cookie 读写能力：能否读到 document.cookie 看不到的 HttpOnly 站点 Cookie
// @author       Aira
// @match        *://*/*
// @grant        GM_cookie
// @grant        GM_setClipboard
// @run-at       document-end
// @noframes
// ==/UserScript==

// 这个脚本只做验证，不改页面行为。唯一会写的数据是名为 aira_gm_cookie_probe 的探针 Cookie，
// 写完立刻删掉；不会碰站点自己的 Cookie。
(function () {
  'use strict';

  var PROBE_NAME = 'aira_gm_cookie_probe';
  var PANEL_ID = 'aira-gm-cookie-test-panel';
  var lines = [];

  function readCookieNamesFromDocument() {
    var raw = String(document.cookie || '');
    if (raw.length === 0) {
      return [];
    }
    var names = [];
    raw.split(';').forEach(function (item) {
      var separator = item.indexOf('=');
      if (separator <= 0) {
        return;
      }
      var name = item.slice(0, separator).trim();
      if (name.length > 0 && names.indexOf(name) < 0) {
        names.push(name);
      }
    });
    return names;
  }

  function listCookies(details) {
    return new Promise(function (resolve) {
      if (typeof GM_cookie === 'undefined' || !GM_cookie || typeof GM_cookie.list !== 'function') {
        resolve({ ok: false, error: 'GM_cookie 不存在：脚本头部缺少 // @grant GM_cookie，或引擎未加载本次改动的构建', cookies: [] });
        return;
      }
      var settled = false;
      var settle = function (ok, cookies, error) {
        if (settled) {
          return;
        }
        settled = true;
        resolve({ ok: ok, cookies: cookies || [], error: error || '' });
      };
      try {
        var maybePromise = GM_cookie.list(details, function (cookies, error) {
          if (error) {
            settle(false, [], String(error));
            return;
          }
          settle(true, cookies, '');
        });
        if (maybePromise && typeof maybePromise.then === 'function') {
          maybePromise.then(function (cookies) {
            settle(true, cookies, '');
          }).catch(function (error) {
            settle(false, [], String((error && (error.message || error)) || error));
          });
        }
      } catch (error) {
        settle(false, [], String((error && (error.message || error)) || error));
      }
    });
  }

  function callCookieOperation(operation, details) {
    return new Promise(function (resolve) {
      try {
        var promise = GM_cookie[operation](details, function (error) {
          if (error) {
            resolve(String(error));
            return;
          }
          resolve('');
        });
        if (promise && typeof promise.then === 'function') {
          promise.then(function () {
            resolve('');
          }).catch(function (error) {
            resolve(String((error && (error.message || error)) || error));
          });
        }
      } catch (error) {
        resolve(String((error && (error.message || error)) || error));
      }
    });
  }

  function report(title, value) {
    lines.push(title + '：' + value);
  }

  function render(status) {
    var output = document.getElementById(PANEL_ID + '-output');
    var statusLine = document.getElementById(PANEL_ID + '-status');
    if (output) {
      output.textContent = lines.join('\n');
    }
    if (statusLine) {
      statusLine.textContent = status || '';
    }
  }

  function runReadTest() {
    lines = [];
    var documentNames = readCookieNamesFromDocument();
    report('是否有 GM_cookie', typeof GM_cookie !== 'undefined' && GM_cookie && typeof GM_cookie.list === 'function' ? '有' : '没有');
    report('页面', location.href);
    report('document.cookie 条数', String(documentNames.length) + (documentNames.length > 0 ? '（' + documentNames.join(', ') + '）' : ''));

    return listCookies({ url: location.href }).then(function (byUrl) {
      if (!byUrl.ok) {
        report('GM_cookie.list 结果', '失败：' + byUrl.error);
        report('结论', 'GM_cookie 未生效');
        render(byUrl.error);
        console.log('[AiraGM_cookieTest] failed', byUrl.error);
        return;
      }
      var httpOnlyNames = [];
      byUrl.cookies.forEach(function (cookie) {
        if (cookie && cookie.httpOnly === true && httpOnlyNames.indexOf(cookie.name) < 0) {
          httpOnlyNames.push(cookie.name);
        }
      });
      var invisible = byUrl.cookies.filter(function (cookie) {
        return cookie && documentNames.indexOf(cookie.name) < 0;
      }).map(function (cookie) {
        return cookie.name;
      });
      report('GM_cookie.list({url}) 条数', String(byUrl.cookies.length));
      report('其中 HttpOnly', String(httpOnlyNames.length) + (httpOnlyNames.length > 0 ? '（' + httpOnlyNames.join(', ') + '）' : ''));
      report('document.cookie 看不到的', String(invisible.length) + (invisible.length > 0 ? '（' + invisible.join(', ') + '）' : ''));
      byUrl.cookies.forEach(function (cookie) {
        report('· ' + cookie.name,
          'httpOnly=' + cookie.httpOnly + ' secure=' + cookie.secure + ' session=' + cookie.session +
          ' sameSite=' + cookie.sameSite + ' domain=' + cookie.domain + ' path=' + cookie.path +
          ' value=' + String(cookie.value).slice(0, 12) + (String(cookie.value).length > 12 ? '…' : ''));
      });
      var verdict = invisible.length > 0 ?
        'GM_cookie 已生效（读到了 document.cookie 拿不到的 Cookie）' :
        'GM_cookie 已生效（这个站点的 Cookie 恰好都不是 HttpOnly，可登录一个站点再试）';
      lines.push('');
      lines.push('结论：' + verdict);
      render('读取完成');
      console.log('[AiraGM_cookieTest] list ok', byUrl.cookies);
      return listCookies({ domain: location.hostname }).then(function (byDomain) {
        lines.push('GM_cookie.list({domain:' + location.hostname + '}) 条数：' + (byDomain.ok ? byDomain.cookies.length : '失败 ' + byDomain.error));
        render('读取完成');
      });
    });
  }

  function runWriteTest() {
    lines = [];
    var details = { url: location.href, name: PROBE_NAME, value: String(Date.now()), path: '/', session: true };
    report('写入探针', PROBE_NAME + '=' + details.value);
    return callCookieOperation('set', details).then(function (setError) {
      report('set 结果', setError.length > 0 ? '失败：' + setError : '成功');
      return listCookies({ url: location.href, name: PROBE_NAME });
    }).then(function (afterSet) {
      report('写入后读回', afterSet.ok ? String(afterSet.cookies.length) + ' 条' : '失败：' + afterSet.error);
      return callCookieOperation('delete', { url: location.href, name: PROBE_NAME });
    }).then(function (deleteError) {
      report('delete 结果', deleteError.length > 0 ? '失败：' + deleteError : '成功');
      return listCookies({ url: location.href, name: PROBE_NAME });
    }).then(function (afterDelete) {
      report('删除后读回', afterDelete.ok ? String(afterDelete.cookies.length) + ' 条（应为 0）' : '失败：' + afterDelete.error);
      lines.push('');
      lines.push('结论：写入与删除' + (afterDelete.ok && afterDelete.cookies.length === 0 ? '链路正常' : '需要检查'));
      render('自测完成');
      console.log('[AiraGM_cookieTest] write path', lines.join(' | '));
    });
  }

  function copyResult() {
    var text = lines.join('\n');
    if (typeof GM_setClipboard === 'function') {
      GM_setClipboard(text, 'text');
      render('已复制');
      return;
    }
    render('剪贴板不可用，请手动选择文本');
  }

  function buildPanel() {
    if (document.getElementById(PANEL_ID)) {
      return;
    }
    var panel = document.createElement('div');
    panel.id = PANEL_ID;
    panel.style.cssText = 'position:fixed;left:8px;right:8px;bottom:8px;z-index:2147483647;background:#16181d;' +
      'color:#e6e6e6;border:1px solid #333;border-radius:12px;font:12px/1.5 -apple-system,monospace;' +
      'box-shadow:0 10px 30px rgba(0,0,0,.5);overflow:hidden';

    var header = document.createElement('div');
    header.style.cssText = 'display:flex;align-items:center;justify-content:space-between;padding:8px 10px;background:#22252b';
    var title = document.createElement('b');
    title.textContent = '🍪 Aira GM_cookie 验证';
    var close = document.createElement('button');
    close.textContent = '关闭';
    close.style.cssText = 'background:none;border:1px solid #444;color:#bbb;border-radius:6px;padding:2px 8px';
    close.onclick = function () {
      panel.remove();
    };
    header.appendChild(title);
    header.appendChild(close);

    var body = document.createElement('div');
    body.style.cssText = 'padding:10px';
    var buttons = document.createElement('div');
    buttons.style.cssText = 'display:flex;flex-wrap:wrap;gap:6px;margin-bottom:8px';

    var actions = [
      { label: '读取本页 Cookie', run: runReadTest },
      { label: '写入/删除自测', run: runWriteTest },
      { label: '复制结果', run: function () { copyResult(); return Promise.resolve(); } }
    ];
    actions.forEach(function (action) {
      var button = document.createElement('button');
      button.textContent = action.label;
      button.style.cssText = 'background:#2f333b;color:#e6e6e6;border:1px solid #4a4f58;border-radius:8px;' +
        'padding:6px 10px;font-size:12px';
      button.onclick = function () {
        render('运行中…');
        Promise.resolve(action.run()).catch(function (error) {
          render('出错：' + error);
        });
      };
      buttons.appendChild(button);
    });

    var output = document.createElement('pre');
    output.id = PANEL_ID + '-output';
    output.style.cssText = 'margin:0;max-height:46vh;overflow:auto;background:#0d0f13;border:1px solid #2a2d33;' +
      'border-radius:8px;padding:8px;white-space:pre-wrap;word-break:break-all;font-size:11px';
    output.textContent = '点“读取本页 Cookie”开始';

    var status = document.createElement('div');
    status.id = PANEL_ID + '-status';
    status.style.cssText = 'margin-top:6px;color:#8a8f98;font-size:11px';
    status.textContent = '就绪';

    body.appendChild(buttons);
    body.appendChild(output);
    body.appendChild(status);
    panel.appendChild(header);
    panel.appendChild(body);
    document.body.appendChild(panel);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', buildPanel);
  } else {
    buildPanel();
  }
})();
