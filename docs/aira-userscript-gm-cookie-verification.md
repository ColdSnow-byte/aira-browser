# 验证用户脚本的 GM_cookie 能力

`GM_cookie` 让脚本读到网页脚本层（`document.cookie`）永远拿不到的 HttpOnly Cookie，也就是站点的登录态。
能力契约、原生路由和授权文案见 `UserScriptCapabilityContractService`、`UserScriptNativeCookieService`。

## 前提

1. 设备上装的是带本次改动的构建：`./scripts/build-aira-browser.sh`（用本机 debug 签名装到真机/模拟器）。
   只跑 `SKIP_INSTALL=1` 得到的 unsigned HAP 装不上，验证不了。
2. 在目标站点**已登录**。HttpOnly 的登录态 Cookie 只有登录后才存在。
3. 脚本头部必须声明 `// @grant GM_cookie`。篡改猴里也是同一个授权名，脚本没声明就没有这个能力。

## 安装验证脚本

用 `docs/userscripts/aira-gm-cookie-smoke-test.user.js`。

- 设置 → 用户脚本 → 操作菜单 → **编辑或粘贴源码**，粘贴整个文件内容保存；或
- 把文件放成可访问的地址后走 **从 URL 添加**；服务器上已有该文件时最省事。

该脚本只做验证：唯一写入的是名为 `aira_gm_cookie_probe` 的探针 Cookie，写完立即删除。

## 期望结果

点「读取本页 Cookie」：

- `是否有 GM_cookie：有`
- `GM_cookie.list({url}) 条数` 明显多于 `document.cookie 条数`
- `document.cookie 看不到的` 列出 `_t`、`_forum_session` 之类的登录态 Cookie 名
- `其中 HttpOnly` 至少 1 条

点「写入/删除自测」：set 成功 → 写入后读回 1 条 → delete 成功 → 删除后读回 0 条。

## 排查

| 现象 | 原因 |
| --- | --- |
| `GM_cookie 不存在` 或 `Missing userscript grant: GM_cookie.list` | 脚本没声明 `@grant GM_cookie`。抓包类工具常常省略，需要在「编辑或粘贴源码」里补上这一行重新安装。 |
| 条数还是不多、没有 HttpOnly | 站点没登录，或装的是旧构建。 |
| 脚本管理里授权摘要没有「读取网站 Cookie（含登录态）」 | 能力没有进引擎，装的确实是旧构建。 |
| 私密标签里读不到常规标签的 Cookie | 预期行为：私密标签使用 ArkWeb 的 incognito Cookie 库，脚本不会跨边界看到常规库的数据。 |
