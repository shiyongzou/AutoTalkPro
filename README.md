# TG AI Sales Desktop

Flutter desktop app (macOS + Windows) for multi-channel AI sales operations (Telegram + WeCom official stub).

## Phase 2 architecture (implemented)

### 1) Local persistence (Drift)

Database: `lib/core/persistence/drift_local_database.dart`

Tables:
- `conversations`
- `customer_profiles`
- `business_template_versions`
- `messages`
- `action_policies`
- `goal_state_logs`
- `audit_logs`
- `dispatch_guards`
- `knowledge_center_intel`（行业趋势 / 价格带 / 竞品要点 / 本周建议）

Mapped model classes:
- `Conversation`
- `CustomerProfile`
- `BusinessTemplateVersion`
- `Message`
- `ActionPolicy`
- `GoalStateLog`
- `IndustryMarketIntel`

### 2) Repository layer

Interfaces:
- `lib/features/template/domain/template_repository.dart`
- `lib/features/conversation/domain/conversation_repository.dart`
- `lib/features/message/domain/message_repository.dart`
- `lib/features/knowledge/domain/knowledge_center_repository.dart`

Drift implementations:
- `lib/features/template/data/drift_template_repository.dart`
- `lib/features/conversation/data/drift_conversation_repository.dart`
- `lib/features/message/data/drift_message_repository.dart`
- `lib/features/knowledge/data/drift_knowledge_center_repository.dart`

### 3) Application services scaffolding

- Goal engine: `lib/features/goal/application/goal_engine_service.dart`
- Risk radar: `lib/features/risk/application/risk_radar_service.dart`
- Message QA service (pre-send guard + normalization + high-risk regex): `lib/features/qa/application/message_qa_service.dart`
- Outbound dispatch (QA gate + binding check + idempotency + retry + stuck recovery + exception recovery + full audit + persistence): `lib/features/outbound/application/outbound_dispatch_service.dart`
- Dispatch idempotency guard + stuck-recovery: `lib/features/outbound/data/drift_dispatch_guard_repository.dart`
- Audit repository (full trace): `lib/features/audit/data/drift_audit_repository.dart`
- Report generator (daily/weekly/monthly): `lib/features/report/application/report_generator_service.dart`
- AI draft service (mock + OpenAI-compatible HTTP): `lib/features/ai/application/ai_draft_service.dart`
- Intent classifier service（rule-based 起步，区分：闲聊 / 关系维护 / 业务推进 / 风险投诉）:
  - `lib/features/conversation/application/intent_classifier_service.dart`
- Response cadence policy（建议立即回复 / 延迟发送 / 跳过低价值回复，含策略权重与节奏参数）:
  - `lib/features/conversation/application/response_cadence_policy.dart`
  - 默认权重：业务推进 0.90 / 关系维护 0.78 / 闲聊 0.46
  - 默认节奏参数：业务自然停顿 3 分钟、关系维护延迟 8~18 分钟、闲聊延迟 3~10 分钟
- Conversation draft advisor（把意图识别+节奏策略接入草稿流程，默认只给建议不自动发送）:
  - `lib/features/conversation/application/conversation_draft_advisor_service.dart`
- Weekly communication advisor（按行业+模板输出“本周沟通建议”，可被 AI draft 调用）: `lib/features/knowledge/application/weekly_communication_advisor.dart`
- AI settings repository (SharedPreferences + secure API key storage):
  - `lib/features/ai/data/local_ai_settings_repository.dart`
  - `lib/features/ai/data/in_memory_ai_settings_repository.dart`
- Unified channel adapter layer:
  - interface: `lib/features/channel/domain/channel_adapter.dart`
  - manager/router (supports runtime adapter update): `lib/features/channel/application/channel_manager.dart`
  - Telegram adapters:
    - mock: `lib/features/telegram/data/mock_telegram_adapter.dart`
    - official stub: `lib/features/telegram/data/official_telegram_adapter.dart`
  - WeCom official stub adapter: `lib/features/wecom/data/wecom_adapter.dart`
- Telegram config repository (prefs + secure apiHash storage):
  - `lib/features/telegram/domain/telegram_config_repository.dart`
  - `lib/features/telegram/data/local_telegram_config_repository.dart`
- WeCom config repository (prefs + secure secret storage):
  - `lib/features/wecom/domain/wecom_config_repository.dart`
  - `lib/features/wecom/data/local_wecom_config_repository.dart`

Most services are deterministic; OpenAI-compatible mode can perform real HTTP draft generation when configured.

### Intent & cadence limitations (current phase)

- 当前意图识别为规则引擎（关键词 + 简单语义规则 + 最近客户上下文承接），不具备跨会话深推理能力。
- 节奏策略支持可配置权重与时间参数：风险/业务优先，关系维护与闲聊强调“自然呼吸感”，避免机械秒回。
- 业务推进场景已加入“短暂停顿”控制（非直接提问可建议 3 分钟自然停顿），减少机器人式连发。
- “生成草稿”流程目前仅输出建议，不会自动触发真实发送；人工确认与发送动作仍需单独执行。

### 4) App shell navigation pages

Implemented pages:
- Channel Center (channel switcher + adapter health status + chat sync view)
- Conversation Center (persisted conversations + 意图识别 + 节奏建议 + 草稿建议；默认不自动发送)
- Customer Center
- Task Center
- Report Center（含运营看板：KPI柱状图 / 会话占比饼图（活跃非风险+风险+其他互斥分桶）/ 销售漏斗（图例+数值标签+空态）/ 运营漏斗卡片 / 风险趋势 / Top风险会话 / 高风险客户TopN卡片 + 行业市场情报摘要卡片 + 商用门禁自检卡片）
- AI Center (provider settings + template import/history + Knowledge Center 建议预览)

Each page reads/writes minimal persisted data.

### 4.1) UI 风格系统（第一轮）

已建立统一设计令牌并接入 `ThemeExtension`：
- 颜色：导航背景/选中态、弱化面板、成功/警告/危险状态色
- 圆角：`cornerSm / cornerMd / cornerLg`
- 间距：`spaceXs / spaceSm / spaceMd / spaceLg / spaceXl`
- 字体层级：`title/body/label` 等统一 text theme

统一组件：
- 主导航：`NavigationRail` 使用统一背景和选中指示色
- 卡片：`AppSurfaceCard`
- 状态标签：`AppStatusTag`
- 指标块：`AppMetricTile`
- 表单与按钮：由 `inputDecorationTheme / filledButtonTheme / outlinedButtonTheme` 统一风格

信息层次统一（控制台风格，兼容深浅主题切换）：
- Channel Center：概览指标 + 操作区 + 配置区 + 列表区
- Conversation Center：概览指标 + 操作区 + 策略结果 + 会话列表
- Report Center：概览指标 + 报告操作 + 门禁结果 + 图表明细

### 5) Template import/version/scope continuity

The existing template import flow is preserved and moved into an organized structure:
- Domain: `lib/features/template/domain/*`
- Import parsing: `lib/features/template/application/template_import_service.dart`
- Version persistence + activation: `lib/features/template/data/drift_template_repository.dart`

AI Center includes scope selection, JSON import, history viewing, and active version switching.

## Channel integration notes (Telegram / WeCom)

- Active outbound channel is selected in **Channel Center**.
- In Channel Center:
  - Telegram channel can toggle official mode and edit apiId/apiHash/phone/sessionPath.
  - WeCom channel can edit corpId/agentId/secret/apiBase.
- Current supported adapters:
  - Telegram mock (development/testing)
  - Telegram official stub (`OfficialTelegramAdapter`) with TDLib gateway abstraction injection point
  - WeCom official stub (configuration + health validation only)
- Telegram 官方链路状态机占位：`未登录 -> 待验证码 -> 已登录 / 错误 / 重连中`
  - `OfficialTelegramAdapter` 暴露显式登录动作占位接口：`connect / requestCode / verifyCode / logout`
  - 提供 `authStateChanges` 状态变更流（含 action/from/to/error/timestamp），便于后续接入真实 TDLib 回调
  - 状态在 Channel Center 可视化展示（含状态流标签），并提供下一步操作提示
  - 新增状态机转移约束（非法转移进入错误态）与错误恢复入口（recover -> reconnect）
  - 补充重连态约束：`reconnecting` 期间不允许直接 `logout`（保持重连态并返回明确错误提示）
  - 发送前会执行 `ChannelSendGuard` 前置校验：未登录/待验证码/错误/重连中状态一律阻断，并附带 nextAction 提示
  - Channel Center 登录按钮按状态启停：未登录可请求验证码、待验证码可提交、错误态可进入重连
- WeCom configuration model: `lib/features/wecom/domain/wecom_config.dart`
- WeCom skeleton intentionally does **not** include any unofficial / bypass approach.

### Compliance statement

This project only reserves integration points for platform **official APIs and authorization flows**.
Any non-official, unauthorized, reverse-engineered, or policy-violating access method is out of scope.

## Run

```bash
cd /Users/mac/Desktop/tg_ai_sales_desktop
/Users/mac/fvm/versions/3.41.5/bin/flutter pub get
/Users/mac/fvm/versions/3.41.5/bin/flutter run -d macos
```

## Verify quality

```bash
/Users/mac/fvm/versions/3.41.5/bin/flutter analyze
/Users/mac/fvm/versions/3.41.5/bin/flutter test
```

对话策略样例测试（业务承接 / 关系维护 / 闲聊转推进，避免机械回复）位于：
- `test/conversation_strategy_test.dart`

UI 样式断言测试（至少 2 项）位于：
- `test/ui_style_system_test.dart`

页面结构渲染测试：
- `test/widget_test.dart`（含 Channel Center 概览指标 + 操作区断言，以及 Report Center 的“运营漏斗卡片/高风险客户TopN卡片”存在性断言）

报表与运营看板测试：
- `test/report_generator_service_test.dart`
  - 覆盖日报摘要、漏斗、风险趋势、Top 风险会话/高风险客户排序与 Markdown 导出内容
- `test/report_dashboard_metrics_test.dart`
  - 覆盖会话占比分桶互斥规则（活跃非风险 / 风险 / 其他）与异常输入钳制

官方接入与发送链路关键测试：
- `test/official_telegram_state_machine_test.dart`
  - 覆盖登录主流程、非法状态迁移阻断、错误恢复、重连态禁止退出约束
- `test/outbound_dispatch_test.dart`
  - 覆盖未登录阻断、待验证码阻断、幂等去重、重试成功、异常恢复、stuck sending 恢复调用
- `test/critical_flow_e2e_test.dart`
  - 覆盖模板导入 → 草稿建议 → QA校验 → 发送落库 → 审计追踪 的关键端到端流程

## Release flow (commercial gate)

1) Run static checks + unit/widget tests

```bash
./scripts/ci_gate.sh
```

2) Run one-shot release check and generate JSON + Markdown reports

```bash
./scripts/release_check.sh
```

- Output report: `docs/reports/latest_gate.json`
- Output summary markdown: `docs/reports/latest_gate.md`
- Optional env vars:
  - `COVERAGE_THRESHOLD` (default: `70`)
  - `COVERAGE_VALUE` (example: `78.5`)
  - `UI_TOKEN_COVERAGE` (example: `0.93`)
  - `UI_TOKEN_THRESHOLD` (default: `0.9`)
  - `UI_VIOLATION_COUNT` (default: `0`)
  - `UI_VIOLATION_THRESHOLD` (default: `0`)

Example:

```bash
COVERAGE_THRESHOLD=80 \
COVERAGE_VALUE=82.4 \
UI_TOKEN_COVERAGE=0.94 \
UI_TOKEN_THRESHOLD=0.9 \
UI_VIOLATION_COUNT=1 \
UI_VIOLATION_THRESHOLD=2 \
./scripts/release_check.sh
```

3) In desktop app `Report Center`
- Click **运行商用门禁自检**
- Click **导出门禁JSON** to archive `latest_gate.json`
- Click **导出门禁Markdown** to archive `latest_gate.md`

- Gate checklist: `docs/COMMERCIAL_RELEASE_GATE.md`
- CI workflow: `.github/workflows/quality-gate.yml`

## Template sample

Use:
- `docs/business_template.sample.json`
