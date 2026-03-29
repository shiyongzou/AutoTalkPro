# Commercial Release Gate

This checklist is a hard gate. Any failed P0 item blocks release.

## P0 (Blocking)

1. Pre-send QA hard intercept
   - Forbidden promises are blocked
   - Empty/malformed messages are blocked
2. Conversation-peer binding check
   - `conversationId` must match target `peerId`
3. Idempotency and retry
   - requestId dedup
   - retry with backoff on transient send failures
4. Audit trace
   - QA result, send attempts, final result are recorded
5. Credential security
   - API keys/secrets stored in secure storage
6. Quality checks
   - `analyze` and `test` are green

## P1 (Required for staged pilot)

1. Channel health dashboard
2. Daily/weekly report charts and highlights
3. Intent + cadence strategy in draft advice
4. Market intel suggestions connected to draft generation

## P2 (Scale-up)

1. Real Telegram adapter
2. Real WeCom official adapter flow
3. Role-based access / full audit controls
4. Automated evaluation agents for each release

## Gate Command

```bash
./scripts/ci_gate.sh
```

## Release Gate Threshold Configuration

`./scripts/release_check.sh` supports configurable thresholds (via env vars):

- `COVERAGE_THRESHOLD` / `COVERAGE_VALUE`
- `UI_TOKEN_THRESHOLD` / `UI_TOKEN_COVERAGE`
- `UI_VIOLATION_THRESHOLD` / `UI_VIOLATION_COUNT`

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
