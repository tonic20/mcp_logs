McpLogs.setup do |config|
  # REQUIRED — replace CHANGE_ME before you deploy.
  #
  # These pages render every argument and every response your MCP server has
  # logged. This gem ships no authentication of its own: its controllers descend
  # from one of yours and inherit whatever that controller enforces. Name a
  # controller that requires a signed-in operator, e.g. "Admin::BaseController".
  #
  # Left as-is, the first request to /mcp_logs raises. There is no default,
  # because every default here is either broken or a security hole.
  config.base_controller_class = "CHANGE_ME"

  # Master switch. When false, nothing is recorded and calls run untouched.
  # config.enabled = true

  # A lambda returning your MCP::Server. Read by the docs page only.
  # config.server = -> { Mcp::Registry.server }

  # Group the docs page by tool name. Anything unlisted renders under "Ungrouped".
  # config.tool_sections = { "Read" => %w[search_apps get_app], "Write" => %w[edit_app] }

  # Payloads are filtered through Rails' filter_parameters, then this lambda,
  # then capped at max_payload_bytes.
  # config.record_payloads = true
  # config.max_payload_bytes = 64_000
  # config.payload_filter = ->(payload) { payload }

  # Used by McpLogs::PurgeJob and `rake mcp_logs:purge`. Schedule one of them.
  # config.retention_days = 30

  # The same job settles rows stranded in "running" — a call whose process died
  # before its completion was written. Set this above your slowest tool call.
  # config.abandoned_after_hours = 24

  # config.page_size = 50
end
