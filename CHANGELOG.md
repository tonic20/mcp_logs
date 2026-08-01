# Changelog

## [Unreleased]

- Initial release: MCP request logging and tool documentation.
- Retention: `McpLogs::PurgeJob` and `rake mcp_logs:purge`.
- `rails generate mcp_logs:install` — initializer, route, migration.
- CI workflow running the suite against PostgreSQL.
- `config.base_controller_class` is **required** and has no default.
  `McpLogs.base_controller` raises `McpLogs::ConfigurationError` when it is
  unset or names no controller, and the generated initializer emits it
  uncommented as `"CHANGE_ME"`. Nothing is released yet so nothing breaks — but
  this is the decision a release makes permanent, since the pages render every
  logged argument and response and the engine ships no authentication of its own.
- Every string column a client can influence is `varchar(255)` and truncated to
  match at capture time; the calls page's filter dropdowns are bounded.
- `config.abandoned_after_hours` (default 24) and `McpLogs::Call.sweep_abandoned!`,
  run by `PurgeJob` and `rake mcp_logs:purge`, settle rows stranded in `running`
  by a process that died mid-call.
- `app/assets/config/mcp_logs_manifest.js`, required for the engine's stylesheet
  to precompile under Sprockets.
