# 历史记录页 Tab 切换与编辑菜单审查及优化建议

审查基线：`main`，HEAD `ba9634b`，以本次工作区源码为准。本文是只读代码审查结果与后续实施建议，未修改业务代码。

## 1. 结论与证据边界

**“站点有内容，但编辑置灰”存在明确的状态判定错误。** 手机历史页以时间线 `rawVisits.length > 0` 决定菜单是否可用，但站点列表来自独立的聚合查询。两份数据可以合法地出现“一份为空、另一份非空”，菜单却没有区分当前模式。

**切换迟滞有明确的重复工作和状态切换问题，但尚不能断言主要耗时来自哪一层。** 每次真正切换模式都会走首屏加载；站点没有查询结果缓存，时间线返回时重新加工展示数据；条件渲染切换列表分支。站点首屏还缺少 loading/error 表达，等待过程可能显示局部旧数据或空态，放大“点了没反应”的感受。

优先建议：先修正菜单能力判定、两种数据互相覆盖和异步请求竞态，再实现按模式保留快照、增量更新，最后根据采样决定是否优化 SQL 或引入后台计算。

本轮进行了源码调用链核查、独立审查交叉验证及华为官方文档核对。没有运行设备、模拟器、界面录制、性能采样、构建或自动化测试；没有读取用户历史数据库。文中的“复现路径”是代码推导出的待执行验证步骤，不代表已在设备上复现。所有耗时目标均为建议验收目标，不是当前实测值。

严重性定义：P2 为影响正常操作或特定时序下展示正确性的问题；优化顺序另行给出。本次没有足够证据认定 P0/P1。

## 2. 实际调用链与现有优化

### 2.1 手机入口

```text
HistoryManagerHeader / SegmentedTabs
  → HdsTabs.onChange
  → HistoryManagerScreen.switchViewMode
  → 更新 viewMode、退出选择、清除钻取状态
  → loadCurrentModeFirstPage
      ├─ timeline → Controller.loadTimelineFirstPage
      │    ├─ 无搜索：非空 repository 缓存优先，否则查询 preview
      │    └─ 有搜索：查询搜索首屏
      │         → applyLoadedVisits → applyHistoryViewState
      │         → 更新两份 datasource、标记、图标调度、滚动到顶部
      └─ sites → loadSiteFirstPage
           → HistoryFeature → RdbHistoryRepository
           → BrowserDatabase.listHistorySiteAggregates
           → applyLoadedSites → 替换站点 datasource
```

参考：[Screen](../AiraBrowser/entry/src/main/ets/app/components/history/HistoryManagerScreen.ets) 第 813–984、2129–2140 行；[Controller](../AiraBrowser/entry/src/main/ets/features/history/HistoryManagerScreenController.ets) 第 93–153 行；[SegmentedTabs](../AiraBrowser/entry/src/main/ets/app/components/common/SegmentedTabs.ets) 第 45–78、110–119 行。

### 2.2 手机与大屏区别

| 项目 | 手机历史管理页 | 大屏历史工作区 |
| --- | --- | --- |
| 模式切换入口 | 顶部时间线/站点分段控件 | 工作区侧栏 |
| 首屏/增量大小 | 40 | 100 |
| 无搜索时间线首屏 | 优先读 repository 非空缓存 | 切换时重新查询数据库首屏 |
| 站点首屏 | 每次调用聚合查询 | 每次调用聚合查询 |
| 两个模式快照 | 混用部分展示状态，未独立保存完整分页快照 | 单一 snapshot；加载一种模式后清空另一种原始数据 |
| 列表渲染 | 两种列表均为 `LazyForEach` | 时间线为 `LazyForEach`；站点为 `ForEach` |
| 图标目标 | 可见范围及缓冲区，90ms 延后调度 | 每次应用 snapshot 遍历当前模式全部已加载目标，已有已解析跳过机制 |

大屏同一浏览器标签页重新激活时可能复用 coordinator；这不等于时间线/站点之间切换命中模式缓存。

参考：[大屏 Workspace](../AiraBrowser/entry/src/main/ets/app/components/history/HistoryLargeScreenWorkspace.ets) 第 409–483 行；[SessionCoordinator](../AiraBrowser/entry/src/main/ets/core/history/HistoryWorkspaceSessionCoordinator.ets) 第 153–165、373–445 行。

### 2.3 已有机制应保留

- 手机时间线和站点已经按页读取、懒加载列表；站点缓存 8 行，行组件已有 `@Reusable`。
- 手机图标按可见范围读取并延迟 90ms 调度，不需要改成所有历史图标预加载。
- 时间线 Controller 已有 request sequence、分页 loading 门禁、删除事务与待处理查询机制。
- 站点请求已有 sequence 和 query 校验，能够挡住多数不同代请求的迟到结果。
- 数据库已有访问时间、`(host, last_visit_at DESC)` 等索引。
- URL 补齐按当前结果中的 URL ID 分批读取，每批 400；正常首屏不是先加载全部 URL 表。

因此，不建议把“加 LazyForEach”“所有计算都塞进 taskpool”当作本轮通用解决方案。

## 3. 确认的手机端功能问题

### F1 · P2：编辑、站点清理、导出共用错误的数据存在性条件

**位置**：[HistoryManagerScreen.ets](../AiraBrowser/entry/src/main/ets/app/components/history/HistoryManagerScreen.ets) 第 401–449、863–885、927–940、1168–1192、2095–2106 行。

菜单构建逻辑：

```typescript
const hasVisits = this.rawVisits.length > 0;
// 编辑 enabled: hasVisits
// 按站点清理 enabled: hasVisits
// 导出历史 enabled: hasVisits && !this.isTransferBusy
```

`rawVisits` 由时间线查询更新；`applyLoadedSites()` 只更新 `sites` 和站点 datasource，不回填 `rawVisits`。这不是单纯“加载慢导致临时禁用”，而是条件本身选错了数据来源。

**无需请求乱序的验证路径：**

1. 准备非空历史，进入历史页并等待初始加载结束。
2. 切到站点页，确认有站点。
3. 点击搜索，不输入内容，直接关闭搜索。
4. `enterSearchMode()` 清空 `rawVisits`、`sites` 和 Controller 时间线状态；`exitSearchMode()` 恢复 sites 模式并只重载站点。
5. 站点加载完成后，`sites.length > 0`，但 `rawVisits.length === 0`，编辑仍禁用。

快速进入站点并取消初始时间线请求，也可能形成同样状态，但无需依赖这一竞态来证明问题。

**影响扩大点：**“按站点清理”函数内部还有 `controller.hasLoadedTimelineVisits()` 门禁。只改菜单 enabled，清理入口仍可能点击后无动作。“导出历史”的能力范围也不应取决于当前已加载的时间线页。

**建议：**

| 操作 | 建议的能力判定 |
| --- | --- |
| 编辑 | 当前模式的可选实体非空，并满足当前管理边界和操作状态：timeline 看展示 visits，sites 看 sites |
| 按站点清理 | 按站点操作能力及数据存在状态；不要求时间线曾加载。可允许进入加载中的站点页，加载成功后进入选择 |
| 导出历史 | 保留全量导出的既有语义，依据全域存在性状态或允许进入导出后处理空结果；不依据某个 Tab 的局部页数 |
| 搜索 | 不依赖当前页是否已读到数据 |

可将菜单能力派生集中到 `features/history` 的状态/策略 owner，页面只呈现结果。不要通过偷偷再加载时间线来“补齐”菜单条件。

**验收：**上述搜索退出路径下编辑可用；站点存在而 timeline 数组为空时能够编辑；空站点页不可进入无对象选择；清理的 enabled 与执行门禁一致；真实全空历史的禁用语义明确。

### F2 · P2：入场延迟任务可能覆盖用户刚切换的站点结果

**位置**：[Screen](../AiraBrowser/entry/src/main/ets/app/components/history/HistoryManagerScreen.ets) 第 283–287、829–858、879–885、2129–2140 行；[DeferredEnterWork](../AiraBrowser/entry/src/main/ets/common/utils/DeferredEnterWork.ets) 第 1–19 行。

入场任务默认延迟 **280ms**，回调固定调用 `loadVisitsProgressively()`。主动切换并未取消这个任务。该方法会递增 `siteReloadSequence` 并加载时间线，时间线回调再通过 `applyHistoryViewState()` 改写站点数据。

**条件性验证路径：**

1. 打开页面，在入场任务执行前点击站点。
2. 站点查询开始。
3. 入场定时器触发时间线加载，使站点请求序号失效。
4. 若站点先返回，稍后的时间线发布会覆盖聚合结果；若站点后返回，结果会被序号校验丢弃。
5. 仍处于 sites 模式，却可能只显示时间线首批记录派生出的站点。

**建议：**主动导航/查询时取消尚未执行的入场任务；入场任务执行时根据当前导航状态决定加载目标；跨模式数据发布同时校验 session、query、mode 和 generation；两个模式只写自己的数据。

280ms 是首次入场调度延迟，不能称为“每次 Tab 切换都固定延迟 280ms”。不建议为了消除竞态直接删除所有入场延后策略，需兼顾页面进入动画。

### F3 · P2：删除站点可能让其他未删除站点从界面消失

**位置**：[Screen](../AiraBrowser/entry/src/main/ets/app/components/history/HistoryManagerScreen.ets) 第 1297–1313、1531–1570、1635–1670、879–885 行。

删除站点时先尝试移除对应的时间线本地记录。当删除目标与当前已加载时间线有交集、收集到的 `removingSourceIds` 非空时，`removeVisitsFromLocalState()` 会调用 `applyHistoryViewState()`，以剩余 `rawVisits` 同时重建时间线和整个 `sites`；然后才从 sites 中移除目标 host。此时完整站点聚合结果已被局部时间线样本替换。若 ID 数组为空，该方法直接返回，不发生此处描述的覆盖。

**验证数据与步骤：**

1. 最近 40 条访问全部属于站点 A，更早访问属于 B、C。
2. 初始时间线只读到 A；切到站点后聚合查询显示 A、B、C。
3. 删除 A。时间线原始数组变空，重建站点结果也变空。
4. B、C 从当前界面消失。成功删除的完成逻辑不保证重新加载恢复 B、C。

这里确认的是**展示状态丢失**，没有证据表示 B、C 被数据库误删。批量删除站点也受同一条件限制：删除目标须与当前已加载时间线存在交集。

**建议：**站点聚合只由聚合查询及明确的站点增量操作维护；时间线删除不得重建全站点列表。删除只移除目标 host，失败时按当前查询恢复；删除涉及已加载分页时，统一调整游标或标记结果失效，避免随后分页跳过数据。时间线删除对站点计数的影响采用失效刷新或正确的聚合更新，不能用当前时间线子集代替全量统计。

**验收：**删除 A 后 B、C 始终存在；删除失败能恢复；连续删除、分页中删除、批量删除部分失败均不会误清其他站点展示。

### F4 · P2：站点首屏与分页可以同代并发，导致结果被覆盖或过早结束

**位置**：[Screen](../AiraBrowser/entry/src/main/ets/app/components/history/HistoryManagerScreen.ets) 第 904–984、2343–2350 行。

`loadSiteFirstPage()` 保留旧列表，将 `hasLoadedAllSites`、`isLoadingMoreSites` 都设为 false，但没有“首屏正在加载”的门禁。滚动回调可使用旧 `sites.length` 作为 offset 发起分页。两者共享相同 sequence 和 query，都能通过迟到结果检查。

**条件性验证路径：**

1. 数据共 80 个站点，旧列表已加载 80 项。
2. 通过“按站点清理”等入口触发站点首屏重载；首屏 Promise 暂不返回。
3. 在旧列表底部触发可见范围变化，发起 offset=80 的分页。
4. 首屏先返回 40 项，再让 offset=80 的空页返回。
5. 分页将 `hasLoadedAllSites` 设为 true；此时只剩前 40 项，却无法继续读后 40 项。

反向完成顺序也可能发生分页追加结果被首屏替换。该路径需可控 Promise 和滚动回调验证，未作设备实测。

**建议：**将站点查询状态纳入 Controller：`initialLoading`、`loadingMore`、`nextOffset/cursor`、`hasMore`、`generation`；首屏未提交前禁止该代分页；分页 cursor 只从已经接受的查询结果推进。去重后的展示数组长度不能长期充当服务端/数据库原始分页进度。

另外，`applyLoadedSites()` 每次追加后都把可见范围重置为 0–20，会使图标调度暂时指向错误区域；仅在真正的新查询/重置时初始化范围，追加时保持滚动实际值。

## 4. 切换性能审查与优化建议

### P-A：优先消除反复首屏加载与模式状态互相污染

**确定事实：**`switchViewMode()` 每次模式变化都会调用 `loadCurrentModeFirstPage()`。时间线首屏完成后执行 `scrollTimelineToStart()`。站点每次重新聚合；切回时间线会以首屏数据重新构建两种展示结果，之前加载的站点聚合快照也被覆盖。

**建议设计：**按有效查询上下文分别保留时间线和站点快照，至少包含：

| 字段 | 用途 |
| --- | --- |
| mode、query、drilldown 条件 | 防止跨查询复用 |
| management boundary / profile / session 身份 | 保持现有权限及数据范围语义 |
| 数据 revision / dirty 状态 | 历史新增、删除、导入、同步后失效 |
| items、cursor/offset、hasMore | 模式独立分页 |
| initialLoading、refreshing、loadingMore、error | 区分等待、空结果、失败 |
| scroll anchor / offset | 恢复切换前位置 |
| generation | 拒绝迟到结果 |

无变化的来回切换直接显示已有快照；有变化且仍有可用快照时可先显示、后台刷新；首次无快照展示加载态。删除过的实体不能因为展示旧缓存而重新出现，需先应用删除失效/过滤规则。

缓存应有界，优先保留当前页面会话的两种模式和少量查询，禁止把全历史常驻内存。大屏已有会话 coordinator，可在现有 owner 中扩展，不另造平行页面实现。

### P-B：补齐站点 loading/error 状态，给点击立即反馈

**确定事实：**手机时间线存在 `isTimelineLoading`，站点没有对应首屏状态；站点数组为空时直接显示空态。站点查询 catch 为空，底层部分异常还会转成空数组。

**建议：**明确区分“未加载”“加载中”“成功且为空”“加载失败”“有数据正在刷新”。Tab 选中反馈不等待数据库完成；数据区优先复用有效快照，否则显示轻量加载反馈。失败保留最近成功数据并提供重试，避免误报“还没有历史记录”。

入口先记录 HdsTabs `onChange` 相对点击/呈现的时序，再决定是否需要调整控件事件或动画。源码只证明业务在 `onChange` 后启动，不能证明 HDS 固定延迟或发生重复回调。不要先重写全项目共享的 `SegmentedTabs`。

### P-C：拆分展示计算，减少分页后的全量重算

**位置**：[HistoryViewModel](../AiraBrowser/entry/src/main/ets/features/history/HistoryViewModel.ets) 第 62–80、119–224 行；[Controller](../AiraBrowser/entry/src/main/ets/features/history/HistoryManagerScreenController.ets) 第 156–203、422–435 行。

`buildViewState()` 无论 mode 都去重、过滤、构建日期分组和站点分组。时间线分页按累计已加载记录再次合并、排序，再进行 ViewModel 排序/分组。日期分组使用逐条 `groups.find()`，复杂度随日期组数增加。

建议按顺序处理：

1. 时间线只构建时间线展示；站点只转换聚合结果。此项同时解决 F2/F3 的状态污染。
2. 日期分组用 Map 做索引，并保持当前日期排序规则。
3. 确认 repository 的排序不变量，减少重复全量 sort/copy；不要未经契约约束直接删排序。
4. 分页只加工新页及其影响到的日期/URL 合并项，保持 `sourceVisitIds`、同日同 URL 去重和删除计数正确。
5. 仅当采样显示上述计算仍持续占据主线程较长时间，再评估 taskpool；算入序列化、传输、取消和结果合并成本。

首屏只有 40 条时，这部分未必是主要瓶颈；连续分页、大量同 URL 重复访问、跨很多日期时更值得测量。

### P-D：数据源通知与列表身份需要一起设计

**位置**：[HistorySiteListDataSource](../AiraBrowser/entry/src/main/ets/features/history/HistorySiteListDataSource.ets) 第 49–52、82–86 行；[HistoryTimelineDataSource](../AiraBrowser/entry/src/main/ets/features/history/HistoryTimelineDataSource.ets) 第 68–107 行；[BrowserDatabase](../AiraBrowser/entry/src/main/ets/data/database/BrowserDatabase.ets) 第 4376–4403 行。

站点每次 `replaceSites()` 都复制数组并调用 `onDataReloaded()`；时间线子数据源已有 add/delete 通知，但结构或展示变化后还会发 reload。站点 key 为 `host:visitCount:latestVisitedAt`，同站点计数或最新时间变化时组件身份也变化，选择和图标缓存同样受影响。

建议区分：

- 稳定业务身份：管理边界内的规范 host，用于选择、合并、图标关联。
- 内容版本：计数、最近访问、标题等，用于展示更新。
- 结构通知：追加、删除、移动时尽量采用准确的局部通知；整次查询替换再使用 reload。

**必须避免的误修：**不能只把 key 改为 host、仍替换普通对象并仅调用 reload，就假定行内容会刷新。官方文档说明相同 key 可能复用缓存，需配套可观察行模型或适合目标 SDK 的 `onDataChange`/数据集通知，并验证同 key 内容更新。

`onDataReloaded()` 不等于全部节点必然销毁重建；相同 key 可复用缓存。因此本报告只确认存在全量通知/对比工作，实际节点重建数量需测量。列表按索引计算的首尾圆角、padding 在追加或删除后也要正确更新。

### P-E：站点 SQL 的聚合成本应测量，不能把 LIMIT=40 当成只处理40行

**位置**：[BrowserDatabase](../AiraBrowser/entry/src/main/ets/data/database/BrowserDatabase.ets) 第 1285–1432 行；[Repository](../AiraBrowser/entry/src/main/ets/data/repositories/BrowserRepositories.ets) 第 2040–2070 行。

站点查询从 `history_urls` 按 host 执行 SUM/COUNT/MAX，按聚合后的最近时间排序，再 LIMIT/OFFSET，最后回连最新 URL。每个站点分页均执行聚合查询。它的输入规模是 URL 聚合表，不是直接逐条扫描全部访问事件，但输出只取 40 项不意味着上游只处理 40 行。

已有 `(host,last_visit_at DESC)` 索引；不能凭感觉再次添加同类索引。搜索使用多个字段的 `lower(COALESCE(...)) LIKE '%query%'`，普通前缀索引无法直接提供期望的包含匹配收益，需看实际执行计划。

建议先采集：query plan、聚合耗时、结果集映射耗时、不同 offset 的耗时、URL 总量和 host 总量。查询和映射分别计时；`await querySql()` 不是“SQL 同步阻塞 UI 线程”的证据，但 await 后的同步映射/计算仍值得分析。

若确认聚合主导，再评估：

1. 同 revision 的站点结果/页缓存，复用重复切换查询；相同请求进行合并。
2. 明确稳定的次级排序（如 host），解决同一最新时间下分页顺序不确定的问题；最新 URL 时间相同也应有确定的选择规则。
3. 有可靠聚合投影后，再评估按 `(latestVisitedAt, host)` 游标分页，避免不断增大的 OFFSET；仅更换分页语法不能自动消除原始 GROUP BY 的成本。
4. 必要时维护 host 聚合投影，但必须覆盖新增、删除最近访问、整站删除、导入、同步及保留策略，验证计数与最新项一致性。这属于后续较大改造，不建议先做。

### P-F：限制异常回退和 repository 全量刷新对交互的影响

SQL 失败后，站点/搜索回退会调用不带 limit 的 `listHistoryVisits()`，再在内存中过滤聚合。因此异常路径可能把分页请求升级为全量读取。当前没有证据表明用户此次触发了回退，应单独记录 fallback 次数与耗时。

另外 repository 初始化只取最近 100 条，但 `refresh()` 全量读取；批量删除/导入等路径会调用它。`listVisits(limit)` 仍会扫描缓存判断排序，缓存不保证始终只有100条。

建议用有界 preview 刷新或按变更维护缓存，把全量导出等需求与交互缓存分开；对回退给出显式错误/重试或有预算的后台恢复，避免无提示地在交互路径执行全量工作。变更前需要核对依赖全量缓存的导出等调用者，不能直接替换所有 refresh。

### P-G：大屏长列表与图标处理独立优化

[HistoryLargeScreenSites](../AiraBrowser/entry/src/main/ets/app/components/history/HistoryLargeScreenSites.ets) 第 64–84 行使用 `ForEach`；`.cachedCount(8)` 不会让它自动成为 LazyForEach。首批100项不等于立刻存在严重卡顿，但连续分页后应评估迁移为懒加载及行复用。

[Workspace](../AiraBrowser/entry/src/main/ets/app/components/history/HistoryLargeScreenWorkspace.ets) 第 453–483 行每次应用 snapshot 都更新时间线 datasource、遍历当前模式全部已加载图标目标。已有 `shouldSkipTarget`，不能描述为每次都重新下载所有图标。

建议按“内容 revision / 选择状态 / loading 状态”区分更新，仅有选择变化时不重建内容 datasource；图标采用可见范围及缓冲区，并保留当前解析缓存。需通过大屏实测验证收益。

## 5. 大屏端附带发现的条件性竞态

这些不是手机顶部“编辑置灰”的直接原因，单独列出以便后续处理。

### F5 · P2：旧历史标签的删除结果可能覆盖新标签界面

**位置**：[HistoryLargeScreenWorkspace](../AiraBrowser/entry/src/main/ets/app/components/history/HistoryLargeScreenWorkspace.ets) 第 598–620 行；对照第 409–423 行。

`deleteVisit`、`deleteSelection`、`clearAll`、`deleteSite` 都直接执行 `applySnapshot(await task)`。模式切换和分页则会捕获 bindingRevision、tabId、coordinator，等待后执行 `isBindingCurrent()`。

待验证时序：标签 A 发起删除 → 组件绑定切换到历史标签 B → A 的任务最后完成 → A 的快照无条件写入当前组件。建议所有写操作返回界面时采用同样的 binding 校验；页面离开或会话切换后不得发布旧快照。

### F6 · P2：清空/删除未使在途读取失效，旧记录可能重新出现

**位置**：[HistoryWorkspaceSessionCoordinator](../AiraBrowser/entry/src/main/ets/core/history/HistoryWorkspaceSessionCoordinator.ets) 第 178–235、347–371、449–477 行。

清空和删除设置 busy，但不使已经启动的查询 requestSequence 失效。分页开始时检查 busy，不代表已经在途的分页返回时仍受保护。

待验证时序：分页取得清空前结果但尚未交付 → 清空完成并发布空列表 → 旧页最后交付，序号仍匹配 → 已清空内容重新加入展示。建议写入开始时作读请求失效或事务协调，结束后按当前查询恢复读取。引用手机 Controller 的职责划分，不直接复制其状态到 UI。

## 6. 建议实施顺序与职责

| 顺序 | 工作 | 主要 owner | 完成标准 |
| --- | --- | --- | --- |
| 1 | 修正 F1 菜单和入口门禁 | `features/history` 能力派生 + Screen 展示 | 站点非空、时间线为空也能编辑/清理 |
| 2 | 拆分模式数据，修正 F2/F3 | `HistoryManagerScreenController`、`HistoryViewModel` | 入场任务和时间线变更不覆盖站点聚合 |
| 3 | 统一站点首屏/分页状态，修正 F4 | Controller + Feature | 同代首屏和分页有明确顺序，错误/空态可区分 |
| 4 | 每模式快照、滚动锚点、revision 失效 | Controller / 大屏 Coordinator | 无变更的反复切换不重复读取首屏 |
| 5 | 增量展示计算、datasource、可见图标 | ViewModel / datasource / presenter | 分页工作随新增量增长，内容更新正确 |
| 6 | 修正大屏 F5/F6，优化长列表 | Coordinator / Workspace / Sites | 会话切换和写操作期间无旧结果污染 |
| 7 | 按采样结果优化 SQL、缓存和回退 | repository / database / services | 查询计划与耗时证实收益，统计语义保持一致 |

前两项解决确定的用户可见问题，应先于重做布局、调整模糊材质或扩大并发。页面保持 UI shell；策略、查询生命周期、缓存失效和数据转换继续放在已有 features/core/data/services owner 中。

## 7. 验证方案

### 7.1 功能与竞态回归矩阵

| 场景 | 关键断言 |
| --- | --- |
| 站点 → 搜索 → 空输入退出 | 站点恢复后编辑立即可用，清理可执行 |
| 无历史 / 有历史 / 查询无结果 | 分别给出正确的可用状态与空态 |
| 入场280ms内切站点 | 最终是完整的站点聚合首屏，不被时间线覆盖 |
| 连续 timeline → sites → timeline | 迟到结果不污染当前模式，loading 能结束 |
| 首屏和分页分别以相反顺序返回 | 不跳页、不覆盖已提交结果、不提前 hasMore=false |
| 最新40条均为A，较早有B/C，删除A | B/C始终保留，数据库和展示计数一致 |
| 删除仅在站点聚合中、未在当前时间线中的B | 覆盖空ID早返回分支；只移除B，其他站点保持正确 |
| 删除失败、批量部分失败、删除中切换 | 失败可恢复，无旧缓存实体复活 |
| 追加站点页 | 不重置实际可见范围，首尾样式正确，图标目标正确 |
| 同 host 的计数/标题/最新URL变化 | 行内容更新；身份、选择及图标状态按设计保留 |
| 同一最新时间的多个 host | 分页稳定，无随机遗漏/重复 |
| 大屏 A 标签删除中切换 B | A 的结果不覆盖 B 的快照 |
| 大屏清空/删除与在途分页交错 | 已删除条目不被迟到结果恢复 |
| 页面离开时仍有请求 | 不再更新已离开的页面状态 |
| 导入/同步/保留策略后再切换 | 缓存正确失效，能力与真实数据一致 |

优先使用可控 Promise 的 Feature/Repository 替身和假定时器验证状态机，不依赖概率性点击。UI 验证覆盖菜单展开时数据从 loading 变 ready、关闭再打开菜单，以及目标 SDK 下 datasource 同 key 更新。

现有同步 contract 检查不能替代这类界面状态测试。本轮检索未发现直接针对本次模式切换和菜单条件的自动化回归覆盖。

### 7.2 分段性能指标

每次切换赋予不含浏览内容的 requestId，采集以下阶段；仅记录模式、数量、耗时、缓存命中和 generation，不需要记录 URL、标题或搜索词。

| 标记 | 事件 | 能回答的问题 |
| --- | --- | --- |
| T0 | 交互事件采样 | 用户操作何时进入应用 |
| T1 | HdsTabs.onChange / 业务切换开始 | 事件回调是否晚于交互 |
| T2 | 模式状态提交及选中反馈呈现 | 选中反馈是否被工作阻塞 |
| T3 | 缓存读取 / 数据库查询开始 | 切换前置同步工作量 |
| T4 | 查询返回并完成结果映射 | SQL与结果物化成本；必要时细分 |
| T5 | ViewModel / datasource 发布完成 | 展示转换和通知开销 |
| T6 | 目标列表首帧实际呈现 | 布局/渲染及最终切换延迟 |

T2/T6 应通过实际帧/呈现工具确认，不能把“执行完状态赋值”当成画面已显示。另记录主线程长任务、慢帧、内存峰值、查询次数、fallback 次数、图标解析目标数量。

### 7.3 数据集与验收目标

使用合成数据，至少覆盖空库、1千、1万、10万访问；分别设置少量 host 大量重复 URL、很多 host、跨多日期、同时间戳，以及冷缓存/热缓存/同步并发。访问事件数、唯一 URL 数和 host 数分别记录，不能只用“历史条数”描述聚合规模。

建议每组至少30次有效切换，区分首次冷加载与往返热切换，报告 p50/p95。推荐起始目标：

- 热切换不等待数据库，且无数据变更时不增加首屏 SQL 次数。
- Tab 选中反馈在下一个可用帧出现；热切换目标内容呈现 p95 ≤ 100ms，按真实设备等级校准。
- UI线程新增工作尽量控制在帧预算内：60Hz约16.7ms，120Hz约8.3ms；这不是数据库异步查询的耗时上限。
- 初次慢查询期间仍能立即看到正确 loading，页面不先闪“无历史”。
- 反复切换的内存占用稳定，不因缓存无界增长。
- 优化后无新增选择丢失、错误计数、漏页、删除复活等问题。

后续实际改代码后执行相应的状态机/数据源回归和比例适当的 contract checks；有匹配签名配置时按项目要求运行 `AIRA_DISTRIBUTION=community SKIP_INSTALL=1 ./scripts/build-aira-browser.sh`。本轮只新增审查文档，未执行这些构建或设备验证。

## 8. 官方资料与尚未证明的假设

本次通过华为官方开发者知识检索核对以下资料：

- [LazyForEach API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-rendering-control-lazyforeach)：按需创建、稳定且唯一的 key、数据源通知。
- [LazyForEach 开发指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-lazyforeach)：reload 时比较 key，相同 key 可复用缓存。
- [布局性能优化指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-layout-optimization-guidance)：长列表的 ForEach/LazyForEach 差异与适用场景。
- [组件复用](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-reusable)：列表配合懒加载及行组件复用。

具体 API 与通知行为须按仓库目标 SDK 核对版本，不能直接套用文档最新版本的新接口。

后续对照官方资料后，切换延迟按性能刷新范围处理，不把页签动画当成原因：

- [状态变量关联组件过多](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-state-management-faq-inner-component)：同一个状态变量绑在多个复杂组件上时，一次赋值会把这些组件一起刷新。时间线和站点列表原先共用 `iconStates`，解析任一模式的图标都会深拷贝并刷新另一个列表。现已拆成 `timelineIconStates` 与 `siteIconStates`。
- 同文「复杂类型重复赋值会触发不必要的刷新」：`exitSelectionMode()` 每次切换都执行 `selectedVisitIds = []`。空数组也是新对象，会刷新收到该 `@Prop` 的行。已有空选择时不再赋值。下钻状态同样只在确实有值时清除。
- [组件冻结](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-custom-components-freeze)：`LazyForEach` 缓存节点和复用池节点默认仍会响应状态变化。历史行组件已有 `@Reusable`，现加上 `freezeWhenInactive`，离屏行不随图标或选择状态刷新。
- [可见性](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-visibility)：`Hidden` 仍参与布局。已加载的非当前列表改为 `Visibility.None`，避免切换时再测量那一棵 `LazyForEach`。这不是销毁重建，也不是动画时长调整。

手机 hilog 后来补上了回调时序：数据已经复用，`switch_sync_done` 是 0–1ms，列表在回调后 14–16ms 显示。手指抬起到 `onChange` 约 307ms，对上 [HdsTabs.onChange](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdstabs)（切换后触发）和 [onSelected](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdstabs)（点击时触发）。页面内容在 `TabContent` 外，现在点击当下走 `onSelected`，晚到的 `onChange` 不再切第二次。没有改 `animationDuration`，也没有做 SQL/索引或 taskpool 改动。

仍未证明：菜单 ForEach 使用 label key 导致当前缺陷、SQL 在 UI 线程同步执行、每次 reload 都重建所有节点、用户设备已触发全量回退、后台同步一定与此次卡顿有关。上述因素可以按采样进一步核查，不应代替已有明确的 F1–F4 证据。
