McpLogs.setup do |config|
  # Master switch. When false, nothing is recorded and calls run untouched.
  # config.enabled = true

  # A lambda returning your MCP::Server. Read by the docs page only.
  # config.server = -> { Mcp::Registry.server }

  # Inherit your app's authentication by descending from one of its controllers.
  # config.base_controller_class = "Admin::BaseController"

  # Group the docs page by tool name. Anything unlisted renders under "Ungrouped".
  # config.tool_sections = { "Read" => %w[search_apps get_app], "Write" => %w[edit_app] }

  # Payloads are filtered through Rails' filter_parameters, then this lambda,
  # then capped at max_payload_bytes.
  # config.record_payloads = true
  # config.max_payload_bytes = 64_000
  # config.payload_filter = ->(payload) { payload }

  # Used by McpLogs::PurgeJob and `rake mcp_logs:purge`. Schedule one of them.
  # config.retention_days = 30

  # config.page_size = 50
end
