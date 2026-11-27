# 记账清单 iOS App 原型 v2

把桌面版（Vue 3 + Electron 的「记账清单」）重构为 iPhone 原生应用。v2 已按当前 SwiftUI 工程同步：4 Tab + 中央「＋」、资产「预算 / 工资 / 存款」、分析全部时间、年度版式、工资详情、Excel 全量导入导出与 01A 新图标。

## 怎么看

```bash
open prototype/index.html
open prototype/icons.html   # App Icon 5 个方向（01 已应用）
```

- 分五组排布：账单 / 分析 / 资产 / 资产·存款 / 设置，每屏下方是交互说明。
- 末尾是「已确认的方案」，记录当前产品与工程口径。
- 当前分组截图由 `capture.sh` 从 `index.html` 自动生成，读取最新的 `prototype/shots/`：

| 文件 | 内容 |
| --- | --- |
| `shots/bill.png` | 账单、月份、记一笔、分类、详情、筛选 |
| `shots/analysis.png` | 概览、分类下钻、年度总览、年度分类/排行、时间线 |
| `shots/payroll.png` | 资产·预算、工资、年终奖、工资录入 |
| `shots/deposit.png` | 资产·存款、新增存款、银行管理 |
| `shots/settings.png` | 设置、iCloud 同步、版本选择、自定义分类、删除分类、导入导出 |

`shots/ios-*`、`shots/dark-*` 是历史模拟器 / 设计稿截图，不作为当前依据；README 引导图使用 `bill/analysis/payroll/deposit/settings` 重新裁切。

## 结构

```
prototype/
├── index.html          # 构建产物（用浏览器打开这个）
├── capture.sh          # headless Chrome 抓取分组截图
├── tabbar-styles.html  # 中央「＋」6 种样式对比
├── icons.html          # App Icon 5 个方向对比（01 已应用）
├── icons/              # 5 个 1024 SVG 图标源文件 + 分类图标
├── build.py            # src/ → index.html
├── src/
│   ├── style.css
│   ├── layout.html
│   ├── part-bill.html
│   ├── part-analysis.html
│   ├── part-payroll.html
│   ├── part-deposit.html
│   ├── part-settings.html
│   └── part-decisions.html
└── shots/              # 当前分组截图 + 历史截图
```

修改 `src/` 后重新生成并抓图：

```bash
python3 prototype/build.py
./prototype/capture.sh
```

README 引导图由仓库根目录的 `tools/make_guide_images.py` 从 `shots/` 裁切生成，见根目录 README 的「README 引导图」。

`?only=bill|analysis|payroll|deposit|settings` 只渲染对应分组，便于截图。

## 信息架构（已确认）

```
TabView（4 Tab + 中央＋）
├── ＋          记一笔（全屏浮层）
├── 账单        月度汇总 + 按天分组 + 月份/筛选
├── 分析        概览 / 年度 / 时间线
│   ├── 分类下钻
│   └── 年度：结余、收支、五年柱、结余月历、分类汇总、交易排行
├── 资产
│   ├── 预算    月度预算项
│   ├── 工资    工资 / 年终奖 / 个税
│   └── 存款    存款列表、增加存款、银行管理
└── 设置
    ├── 数据处理（Excel 导入 / 导出）
    ├── iCloud 同步 → 版本选择（JSON / .db 快照）
    ├── 自定义分类（增删改、排序、归档）
    └── 反馈与更新 / 关于
```

## 关键交互约定

1. **唯一记账入口**：底部中央「＋」，所有页面共用。
2. **记账一屏完成**：类型 → 金额 → 一级分类 → 二级分类 → 日期/备注 → 保存；自定义数字键盘常驻。
3. **资产合并**：预算 / 工资 / 存款 用分段控件切换，避免第五个 Tab，默认进入预算。
4. **分类删除用归档**：历史账单保留分类快照，汇总归入「已归档」；「未分类」只做系统兜底。
5. **年度页**：结余主数字 + 收入/支出双色 + 五年迷你柱 + 结余月历；下方分类汇总与交易排行。
6. **同步**：用户选择文件夹，移动端写入 JSON 快照并恢复桌面 `.db` 快照；不使用 CloudKit，不做条目级冲突合并。
7. **颜色**：支出 `#E2434F`、收入 `#18A472`、主色 `#6C5DD3`，与桌面版 `Color.json` 一致。

## 数据模型建议

| 桌面版 | iOS |
| --- | --- |
| `Record` | `@Model Record`：date、amount(Decimal)、type、categoryId、categorySnapshot、subCategory、remark、countInBudget |
| `Category.json` | `Category`：name、icon、order、parentId、isArchived、isSystem；「未分类」固定 id |
| `DepositBank` / `DepositRecord` | `Bank` / `Deposit` |
| `SalaryRecord` / `AnnualBonus` / `BudgetItem` | 同名 `@Model`，复用累计预扣税率表 |
| SQLite + iCloud 快照 | SwiftData + 文件夹 JSON / `.db` 快照；Excel 全量导入导出 |

## 已确认的边界

- **资产首页**：分段控件（预算 / 工资 / 存款），默认预算，不做总览层级。
- **账户 / 银行卡**：不引入；年度页只保留年份筛选，交易排行不显示账户。
- **不计入统计**：不做；所有账单参与收支与结余，保留「计入预算」。
- **中央「＋」**：已选定 B 悬浮圆形（无描边），备选见 `tabbar-styles.html`。
- **同步**：只做文件夹快照，不做 CloudKit / 条目级冲突合并。
- **Excel 覆盖导入**：只清空 Excel 中存在的表；合并可能产生重复账单/工资/奖金/存款。

## 当前维护

- 原型与 SwiftUI 工程保持同口径，新增/修改界面先改 `src/`，再运行 `build.py` 和 `capture.sh`。
- README 功能引导图由 `shots/` 自动生成，不再手工标注模拟器截图。
- App Icon 已选定 01A「账页紫光 · 金币印章」，源文件为 `icons/01-ledger-glow.svg`。
- 原型覆盖 23 屏，账单 / 分析 / 预算 / 工资 / 存款 / 设置均支持浅色与深色。

## iOS 实现进度（2026-11-26）

已落地 SwiftUI 工程，`xcodebuild` 编译通过，可在 iPhone 模拟器运行：

- **导航**：底栏 4 Tab + 中央 B 圆形按钮（作为第 5 个槽位嵌在 Tab 栏内），全局唯一记一笔入口
- **账单**：顶部月份与收支汇总固定，只有账单列表滚动；每天独立卡片；分类图标使用桌面工程 SVG（模板染色）；点账单进入半屏详情/编辑；筛选页使用系统导航栏；分类为单行横向滚动，时间范围常驻；搜索页支持最近 10 条历史
- **分析**：标题与概览/年度/时间线固定，内容滚动；概览默认全部时间，环形图 + 分类明细（点击下钻）；年度分类汇总可下钻，点结余月历某月回到该月概览；时间线卡片进入账单详情
- **资产**：标题与三段切换固定，默认预算；银行管理（内置真实 Logo、拖动排序、自定义）、存款自动算息、工资与年终奖、累计预扣税率、预算进度
- **设置**：iCloud Drive 文件夹同步（选择文件夹 / 立即备份 / 自动备份 / 从 JSON 或 `.db` 快照恢复）、自定义分类、CSV / Excel 全量导入导出、关于
- **数据**：SwiftData 本地库，65 个子分类种子；历史税额差异会提示重算或保留；`-seedDemo` 可注入演示数据（DEBUG）

运行：

```bash
xcodebuild -project Record-iOS.xcodeproj -scheme Record-iOS \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
```

## 暗色搭配

设计稿：`prototype/dark-theme.html`（总览图 `shots/dark-theme-board.png`）。原型稿的 23 屏已全部适配深色，右下角切换或 `?theme=dark`。

| Token | 暗色 | 浅色 |
| --- | --- | --- |
| 背景 | `#0F1115` | `#F4F5F7` |
| 卡片 | `#171A21` | `#FFFFFF` |
| 浮起 | `#1E222B` | `#FFFFFF` |
| 日期条 | `#1B1F27` | `#F7F8FB` |
| 描边 | `#2A2F3A` | `#EBECF0` |
| 主文字 | `#F2F4F8` | `#1B1F27` |
| 次文字 | `#A6ADBB` | `#5A6274` |
| 品牌 | `#9B8CFF` | `#6C5DD3` |
| 品牌浅底 | `#2A2440` | `#EFECFB` |
| 支出 | `#FF6B76` | `#E2434F` |
| 收入 | `#3FD39A` | `#18A472` |

分类色在暗色下统一提亮（餐饮 `#FF9A66`、交通 `#6CA6FF`、购物 `#FF7AB8`、居家 `#45D6A8`…），色相不变。实现使用 `Color(light:dark:)` 动态颜色，设置 → 个性化 → 外观 可切「跟随系统 / 浅色 / 深色」。
