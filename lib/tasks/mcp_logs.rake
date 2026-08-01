namespace :mcp_logs do
  desc "Delete logged MCP calls older than McpLogs.retention_days"
  task purge: :environment do
    deleted = McpLogs::Call.purge!
    puts "mcp_logs: deleted #{deleted} calls older than #{McpLogs.retention_days} days"
  end
end
