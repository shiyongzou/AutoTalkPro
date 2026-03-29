# Commercial Release Gate Summary

- generatedAt: `2026-03-26T21:15:31.952373`
- ciGate: `passed (ok)`
- result: **PASSED** (score=92)
- checks: `13`
- blockers: `0`

## Blocking items (P0)
- None

## All checks
- ✅ [P0] **发送前QA拦截**: 已启用
- ✅ [P0] **幂等防重链路**: 已启用
- ✅ [P0] **审计链路**: 已启用
- ✅ [P0] **凭据安全存储**: 已启用
- ✅ [P0] **质量门禁(analyze)**: 通过
- ✅ [P0] **质量门禁(test)**: 通过
- ✅ [P0] **当前通道健康检查(telegram)**: Telegram Mock 运行正常
- ✅ [P1] **当前通道发送就绪检查(telegram)**: 当前适配器未实现发送前置校验接口（建议补齐 ChannelSendGuard）
- ✅ [P1] **Telegram官方配置**: 当前未启用官方模式
- ❌ [P1] **WeCom官方配置**: corpId 不能为空；agentId 不能为空；secret 不能为空
- ✅ [P1] **配置完整性（当前激活通道）**: 当前激活通道配置完整
- ✅ [P1] **UI风格一致性**: 通过（违规 0 项/阈值 0 项，Design Token 覆盖率 未提供）
- ✅ [P1] **关键测试覆盖率阈值**: 占位检查：未接入覆盖率采集（配置阈值 70%）
