# Product Build Plan (MVP)

## Target
Telegram AI business agent desktop client for macOS + Windows.

## MVP modules

1. Session Workspace
   - chat list
   - isolated context per customer
2. Profile & Memory
   - customer memory snapshots
   - history analysis hook
3. Template System
   - import/export JSON templates
   - role/goal/constraints configuration
4. Model Gateway
   - provider abstraction
   - apiKey + oauth placeholder
5. Automation Rules
   - notify on deal-stage trigger
6. Reporting
   - daily/weekly/monthly summary generation

## Non-functional requirements

- zero session mix-up
- auditability for all auto-sent messages
- local encrypted storage for sensitive credentials

## Suggested technical stack

- Flutter Desktop UI
- Drift (SQLite) for local persistence
- TDLib bridge for Telegram protocol
- AI gateway service with provider adapters
