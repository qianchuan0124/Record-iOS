# 移动端备份同步协议 v1.3

> 对应实现：`Record-iOS/Features/Settings/SyncFolderService.swift`
> 适用版本：iOS App 当前 JSON 快照格式
> 最后更新：2026-11-22

## 1. 传输方式

iOS 端不经过业务后端，也不调用任何远端记账服务。

1. 用户在 App 内通过系统文件选择器选择一个文件夹。
2. App 保存该文件夹的 security-scoped bookmark。
3. 每次备份在该文件夹写入一个 JSON 快照文件。
4. 如果该文件夹位于 iCloud Drive，文件由 Apple iCloud 在登录同一 Apple ID 的设备之间同步；如果用户选择“我的 iPhone”或其他文件提供商，则不会跨设备同步。
5. App 不上传数据库文件，不建立 HTTP/WebSocket 连接。

因此“云端备份”准确含义是：**用户选择的文件目录 + iCloud Drive 的系统同步**，不是自建云服务。

## 2. 文件命名与生命周期

```
record-backup-yyyyMMdd-HHmmss.json
```

- 编码：UTF-8
- 内容：格式化 JSON（`.prettyPrinted`、`.sortedKeys`）
- 日期：ISO 8601（`JSONEncoder.dateEncodingStrategy = .iso8601`）
- 目录内只保留最近 **5 份** iOS JSON 快照；桌面版 `.db` 不参与该裁剪。
- 自动备份：
  - 设置中开启“自动备份”后生效；
  - App 回到前台时检查；
  - 距上次备份超过 **300 秒**才写入；
  - 不保证 App 被系统杀死或未回到前台时自动备份。

## 3. JSON 顶层结构

```json
{
  "createdAt": "2026-11-22T08:26:00Z",
  "device": "iPhone",
  "hardware": {
    "identifier": "iPhone17,1",
    "name": "iPhone 16 Pro"
  },
  "records": [],
  "categories": [],
  "customBanks": [],
  "deposits": [],
  "salaries": [],
  "bonuses": [],
  "budgets": [],
  "budgetSettings": {
    "cycleEnabled": true,
    "startDay": 26,
    "endDay": 25,
    "incomeMode": "current"
  },
  "payrollSettings": {
    "salaryTaxMonthMode": "current"
  }
}
```

### 3.1 顶层字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `createdAt` | ISO8601 字符串 | 是 | 快照创建时间 |
| `device` | string | 是 | 来源设备显示名，见第 7 节 |
| `hardware` | `HardwareDTO` | 否 | 硬件标识与型号名；旧快照可以没有，见第 7 节 |
| `records` | `RecordDTO[]` | 是 | 账单 |
| `categories` | `CategoryDTO[]` | 是 | 分类/子分类配置 |
| `customBanks` | `BankDTO[]` | 否 | 手动添加的银行；内置银行不上传，旧快照可以没有 |
| `deposits` | `DepositDTO[]` | 是 | 存款 |
| `salaries` | `SalaryDTO[]` | 是 | 工资 |
| `bonuses` | `BonusDTO[]` | 是 | 年终奖 |
| `budgets` | `BudgetDTO[]` | 是 | 预算项 |
| `budgetSettings` | `BudgetSettingsDTO` | 否 | 预算周期/收入口径；老快照可以没有 |
| `payrollSettings` | `PayrollSettingsDTO` | 否 | 工资算税配置；老快照可以没有 |

当前实现没有显式 `schemaVersion` 字段；解码以字段是否存在为准。建议下一版本增加：

```json
{ "schemaVersion": 1 }
```

并保持旧快照兼容（缺失时按 v1 处理）。

## 4. 数据对象

### 4.1 HardwareDTO

```json
{
  "identifier": "iPhone17,1",
  "name": "iPhone 16 Pro"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `identifier` | string | 系统硬件标识，来自 `uname().machine`，如 `iPhone17,1`；模拟器为 `arm64`/`x86_64` |
| `name` | string | 型号名，App 内置映射；未知型号或模拟器会回退为标识或 `iOS Simulator` |

该对象为可选字段，不参与恢复，只用于备份来源标识和排查。

### 4.2 RecordDTO

```json
{
  "date": "2026-11-22T03:00:00Z",
  "amount": 39.0,
  "typeRaw": "expense",
  "category": "居家",
  "subCategory": "话费",
  "remark": "手机套餐",
  "countInBudget": true
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `date` | ISO8601 | 账单日期 |
| `amount` | double | 正数金额；方向由 `typeRaw` 决定 |
| `typeRaw` | string | `expense` 或 `income` |
| `category` | string | 一级分类名称 |
| `subCategory` | string | 子分类名称 |
| `remark` | string | 备注，可为空 |
| `countInBudget` | bool | 是否计入预算 |

### 4.3 CategoryDTO

| 字段 | 类型 | 说明 |
|---|---|---|
| `name` | string | 分类名称 |
| `icon` | string | 图标短名 |
| `colorHex` | string | 颜色，不带 `#` |
| `order` | int | 排序 |
| `parentName` | string/null | 父分类；一级分类为 null |
| `isArchived` | bool | 是否归档 |
| `isSystem` | bool | 是否系统分类 |

### 4.4 DepositDTO

| 字段 | 类型 | 说明 |
|---|---|---|
| `bankName` | string | 银行名称 |
| `amount` | double | 本金 |
| `startDate` | ISO8601 | 起存日 |
| `years` | double | 存期（年） |
| `rate` | double | 年利率，百分数值（如 `2.45`） |
| `interest` | double | 利息 |
| `order` | int | 排序 |

### 4.5 SalaryDTO

| 字段 | 类型 | 说明 |
|---|---|---|
| `date` | ISO8601 | 发薪日 |
| `baseSalary` | double | 基本工资 |
| `overtimePay` | double | 加班费 |
| `oneTimeBonus` | double | 一次性奖金 |
| `socialInsurance` | double | 五险一金 |
| `tax` | double | 个税 |
| `taxRate` | double | 税率百分数值 |

净收入由 App 按 `max(0, baseSalary + overtimePay + oneTimeBonus - socialInsurance - tax)` 计算，快照不存净收入。

### 4.6 BonusDTO

| 字段 | 类型 | 说明 |
|---|---|---|
| `date` | ISO8601 | 发放日 |
| `bonus` | double | 税前年终奖 |
| `tax` | double | 个税 |
| `taxRate` | double | 税率百分数值 |

### 4.7 BudgetDTO

```json
{ "name": "餐饮", "amount": 3000.0 }
```

预算项在本地是独立表；快照按 `name + amount` 保存，恢复时整体替换。

### 4.8 BankDTO

```json
{ "name": "九江银行", "icon": "九", "colorHex": "1B7F79", "order": 120 }
```

`customBanks` 只包含 `Bank.isSystem == false` 的手动银行。内置银行由 App 安装/升级时在本地补齐，不写入快照；恢复时只替换自定义银行，内置银行保持不变。旧快照没有该字段时，保留本机现有自定义银行。

### 4.9 PayrollSettingsDTO

```json
{ "salaryTaxMonthMode": "current" }
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `salaryTaxMonthMode` | string | `current`（按发薪当月）或 `previous`（按发薪月的上一个归属月） |

工资日期在桌面端和移动端都表示发薪日；`previous` 模式下，1 月发薪归属上一年 12 月。该字段可选，缺省按 `current`。

## 5. 预算配置的备份方式

### 5.1 本机存储

预算配置不放在 SwiftData 业务表，而是放在 `UserDefaults`：

- key：`record.budget.preferences.v1`
- value：`BudgetPreferences` 的 JSON 编码
- 字段：
  - `cycleEnabled`: 是否启用自定义开销周期
  - `startDay`: 周期开始日，1...31
  - `endDay`: 周期结束日，1...31
  - `incomeMode`: `current`（本月收入）或 `next`（下月收入）

读取时会做归一化，`startDay`/`endDay` 被限制在 1...31。

### 5.2 写入快照

`SyncSnapshot.makeData` 读取当前 `BudgetPreferences` 并写入顶层 `budgetSettings`：

```json
"budgetSettings": {
  "cycleEnabled": true,
  "startDay": 26,
  "endDay": 25,
  "incomeMode": "next"
}
```

预算项本身写入顶层 `budgets` 数组，与 `budgetSettings` 分开：

- `budgets`：预算项名称和金额
- `budgetSettings`：预算周期和收入口径

### 5.3 恢复快照

恢复 iOS JSON 时：

1. 删除本机所有记录、分类、存款、工资、年终奖、预算项；
2. 按快照重新插入；
3. 如果快照包含 `budgetSettings`，写回 `BudgetPreferences`；
4. 如果老快照没有 `budgetSettings`，保留本机当前预算配置，不重置为默认值；
5. 保存 SwiftData。

注意：恢复是**整库覆盖，不是合并**。银行目录 `Bank` 不在快照中，恢复后会保留本机银行目录，存款通过 `bankName` 关联。

### 5.4 桌面版 `.db` 兼容

从桌面版 `.db` 导入时：

- 文件命名：`record_yyyyMMdd_HHmmss_<deviceTag>_<mode>[_n].db`，兼容旧命名；
- 预算项：读取 `budget_item` 表（`isDeleted = 0`）；
- 预算配置：读取 `app_setting` 表中 `key = 'budget'` 的 JSON，映射到：
  - `cycleEnabled`
  - `startDay`
  - `endDay`
  - `incomeMode`
- 其他数据：`record`、`deposit_record`、`salary_record`、`annual_bonus`；
- 银行：读取 `deposit_bank`，并按存款的 `bankId/bankKey` 补建本机银行目录；
- 分类：优先读取桌面版旁边的 `*.categories.json` 侧车文件；
- `latest.json`：桌面端版本提示，不导入。

完整字段映射和双向兼容规则见第 6 节。

### 5.5 工资算税配置

本机存放在 `UserDefaults`：

- key：`record.payroll.preferences.v1`
- 字段：`salaryTaxMonthMode`（`current` / `previous`）
- 与预算配置相同，写入快照顶层 `payrollSettings`；恢复时存在该字段才覆盖，缺失时保留当前配置。

工资算税使用累计预扣预缴税率表；工资日期是发薪日，算税月份由该配置决定。年终奖使用全年一次性奖金单独税率表，不受该配置影响。

### 5.6 银行目录

银行目录存放于 SwiftData 的 `Bank` 表，每行有 `isSystem` 标记：

- 内置银行：`isSystem = true`，只保存在本机；安装、升级或数据修复时在本地补齐，不进入 JSON 快照。
- 手动银行：`isSystem = false`，写入快照顶层 `customBanks`；恢复时先删除本机自定义银行，再按快照重建，内置银行不动。
- 旧快照没有 `customBanks` 时保留本机自定义银行，避免旧备份覆盖本地新增银行。
- 桌面 `.db` 恢复时保留本机内置银行，只把桌面端 `deposit_bank` 中非内置银行作为自定义银行导入。

## 6. 与桌面端协议 v1.0 兼容

桌面端协议文件：`../../Record/docs/desktop-backup-sync-protocol.md`（本仓库外的桌面工程）。

### 6.1 目录与文件互认

桌面端固定使用同步根目录下的 `记账清单/` 子目录，移动端允许用户直接选择同步根目录或其中的目录。

移动端当前会扫描：

- 用户选择的目录本身；
- 用户选择目录下的 `记账清单/`；
- 用户选择目录下以 `Record备份-` 开头的子目录。

这样两种放置方式都可以互相发现：

```text
<用户选择的同步根目录>/
├── record-backup-20261122-162600.json   移动端快照
├── Record备份-20261122/                 移动端可选目录
│   └── record-backup-20261122-150000.json
└── 记账清单/                            桌面端固定目录
    ├── latest.json
    ├── record_20261122_101500_a1b2_manual.db
    └── record_20261122_101500_a1b2_manual.db.categories.json
```

互认规则：

- 移动端写 `record-backup-yyyyMMdd-HHmmss.json`，桌面端扫描端支持该前缀。
- 移动端识别桌面端 `record_yyyyMMdd_HHmmss_<deviceTag>_<mode>[_n].db`，以及旧命名 `record_yyyyMMdd_HHmmss_<deviceTag>.db`。
- 桌面端 `latest.json` 是桌面端版本提示文件，移动端当前不作为版本来源，也不解析；移动端以实际 JSON/`.db` 文件列表为准。
- 桌面端 `.db` 旁的 `.categories.json` 是分类侧车文件，移动端恢复 `.db` 时会读取。
- 移动端 JSON 不写入 `latest.json`；桌面端扫描 JSON 时也不依赖 `latest.json`。

建议用户两端选择同一个同步根目录，或桌面端使用默认的 `记账清单/`、移动端选择该 `记账清单/`。移动端不扫描同步根目录的上级目录，桌面端会扫描其上级目录，这是两端扫描范围的差异。

### 6.2 字段映射

| 移动端 JSON | 桌面端落点 | 兼容说明 |
|---|---|---|
| `records[]` | `record` | `typeRaw` 的 `expense`/`income` 对应桌面 `支出`/`收入` |
| `categories[]` | `category-custom.json` | 按 `parentName` 重建分类树 |
| `customBanks[]` | `deposit_bank` | 只同步手动银行；内置银行由移动端本地维护 |
| `deposits[]` | `deposit_record` | `bankName` 关联内置银行或 `deposit_bank` 自定义银行 |
| `salaries[]` | `salary_record` | 净收入按移动端公式计算，不单独存 netPay |
| `bonuses[]` | `annual_bonus` | 金额、个税、税率 |
| `budgets[]` | `budget_item` | 名称 + 金额 |
| `budgetSettings` | `app_setting` 的 `key = 'budget'` | 字段名与移动端一致 |
| `payrollSettings` | `app_setting` 的 `key = 'payroll'` | `salaryTaxMonthMode`；桌面端导出、移动端读取 |

桌面端导入移动端 JSON 时：

- `hardware` 优先取 `hardware.name`，其次 `hardware.identifier`，最后回退 `device`；
- ISO 8601 日期映射为桌面端本地当天 00:00；
- `budgetSettings` 缺失时保留桌面端当前账期配置；
- 未知字段忽略，缺少 `hardware` 或 `budgetSettings` 不阻断恢复。

移动端导入桌面端 `.db` 时：

- 读取 `record`、`salary_record`、`annual_bonus`、`budget_item`、`deposit_bank`、`deposit_record`；
- `deposit_bank` 中的内置银行不重复导入；非内置银行作为自定义银行保留；
- 读取 `app_setting` 中 `key = 'budget'` 的 JSON，映射到 `budgetSettings`；
- 读取 `app_setting` 中 `key = 'payroll'` 的 JSON，映射到 `payrollSettings`；
- 读取 `.db` 同名的 `.categories.json` 侧车；
- 不读取 `latest.json`。

业务数据按整库覆盖；银行目录例外：内置银行保留本地，自定义银行按快照覆盖。完整恢复顺序见第 5.3 节和桌面端协议第 6 节。

### 6.3 预算配置

桌面端 `app_setting` 中 `key = 'budget'` 的 JSON 与移动端 `budgetSettings` 结构对齐：

```json
{
  "cycleEnabled": true,
  "startDay": 26,
  "endDay": 25,
  "incomeMode": "current"
}
```

- 桌面端导入移动端：写入 `app_setting`；
- 移动端导入桌面端：读取 `app_setting` 后写回 `BudgetPreferences`；
- 缺失时保留接收端当前配置，不重置为默认值。

### 6.4 工资算税配置

桌面端 `app_setting` 中 `key = 'payroll'` 的 JSON 与移动端 `payrollSettings` 对齐：

```json
{
  "salaryTaxMonthMode": "current"
}
```

移动端从桌面 `.db` 恢复时会读取该配置并写回 `PayrollPreferences`；移动端 JSON 备份也会携带 `payrollSettings`。缺失时保留移动端当前配置。

## 7. 设备字段与隐私

快照当前写入两个独立字段：

```swift
device: UIDevice.current.name
hardware: {
    identifier: uname().machine   // 例：iPhone17,1
    name: 内置映射表              // 例：iPhone 16 Pro
}
```

说明：

- `device` 是用户可见的设备名。模拟器上通常显示 `iPhone 18 Pro`；真机在 iOS 16+ 无 user-assigned-device-name 权限时通常返回 `iPhone`/`iPad`，也可能返回用户自定义名称。
- `hardware.identifier` 是**精确硬件标识**，如 `iPhone17,1`。这是本次新增的主动型号字段。
- `hardware.name` 是 App 内置映射得到的人类可读型号名；未收录的新机型回退为 identifier，模拟器回退为 `iOS Simulator`。
- 不包含 UDID、序列号、IMEI、广告标识或任何账号信息。
- `hardware` 为可选字段：旧快照没有该字段时仍可正常恢复；新客户端恢复旧快照时也不会失败。
- 该字段会随 JSON 一起写入用户选择的文件夹；如果文件夹是 iCloud Drive，Apple 会按用户 Apple ID 同步该文件。

如果后续需要减少设备可识别性，可以把 `DeviceHardware.current` 置为 `nil`，或只保留 `identifier` 不写 `name`；协议保持向后兼容。

## 8. 读取与校验

- `backupInfo(for:)` 只读取 JSON 顶层数组长度生成预览计数，不会反序列化全部业务对象。
- 正式恢复使用 `JSONDecoder` 解码 `Payload`，缺少必填字段会失败。
- `budgetSettings` 是可选字段，用于兼容旧快照。
- `payrollSettings` 是可选字段，旧快照缺失时按 nil 处理。
- `hardware` 是可选字段，旧快照缺失时按 nil 处理。
- 未知字段会被 `Codable` 忽略；新增可选字段不会破坏旧客户端。
- 当前没有显式 schema 版本、签名、校验和或加密。

## 9. 恢复安全边界

- 恢复前 UI 会提示覆盖本机全部数据，并建议先手动备份。
- 当前 `restore` 实现本身不会自动生成“恢复前快照”；协议使用者应先调用一次 `writeBackup` 再恢复。
- iOS JSON 恢复不覆盖银行目录，本机银行目录保留。
- 桌面 `.db` 恢复会先删除本机银行目录，再按 `deposit_bank` 和存款引用重建。
- 同步文件夹通过 security-scoped bookmark 访问；权限失效时返回 `folderAccessDenied`。

## 10. 安全与隐私注意

- 快照是明文 JSON，包含账单、备注、工资、个税、存款、预算以及硬件型号标识等敏感数据。
- 安全性依赖用户选择的存储位置和系统文件保护；App 不做额外加密。
- 不要把快照发送到未授权的第三方服务。
- 若后续需要跨账号/跨组织同步，应增加加密、签名、版本和冲突解决机制，而不是直接复用当前“整库覆盖”语义。

## 11. 代码位置

- 快照写入/读取/恢复：`Record-iOS/Features/Settings/SyncFolderService.swift`
- 移动端目录扫描（含 `记账清单/`、`Record备份-*`）：`SyncFolderService.loadBackups`
- 设备硬件标识采集：`Record-iOS/Features/Settings/SyncFolderService.swift` 中的 `DeviceHardware`
- 预算配置模型：`Record-iOS/Models/BudgetPreferences.swift`
- 工资算税配置：`Record-iOS/Models/PayrollPreferences.swift`
- 工资/年终奖算税：`Record-iOS/Models/PayrollTax.swift`
- 版本列表/对比 UI：`Record-iOS/Features/Settings/SettingsView.swift`
- 桌面 `.db` 导入：`Record-iOS/Features/Settings/DesktopSnapshot.swift`
- 自动备份触发：`Record-iOS/ContentView.swift`
