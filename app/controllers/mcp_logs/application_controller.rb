module McpLogs
  # Descends from whatever the host configured, so authentication, Current
  # attributes and any other host-wide before_actions apply with no auth code in
  # this gem. The constant is resolved when this file is first autoloaded, which
  # is after the host's initializers have run.
  #
  # The layout is re-declared because the host's base controller almost certainly
  # sets its own, and the engine's pages are styled by the engine's own CSS.
  class ApplicationController < McpLogs.base_controller
    layout "mcp_logs/application"
  end
end
