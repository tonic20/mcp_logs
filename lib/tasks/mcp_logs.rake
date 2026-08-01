namespace :mcp_logs do
  desc "Delete logged MCP calls past McpLogs.retention_days, and settle any stranded in running"
  task purge: :environment do
    deleted = McpLogs::Call.purge!
    puts "mcp_logs: deleted #{deleted} calls older than #{McpLogs.retention_days} days"

    swept = McpLogs::Call.sweep_abandoned!
    puts "mcp_logs: marked #{swept} calls abandoned after #{McpLogs.abandoned_after_hours} hours running"
  end
end
