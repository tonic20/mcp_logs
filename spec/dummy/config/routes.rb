Rails.application.routes.draw do
  mount McpLogs::Engine, at: "/mcp_logs"
end
