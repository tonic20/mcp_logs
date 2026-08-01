module McpLogs
  # Descends from ActiveJob::Base rather than the host's ApplicationJob: the gem
  # has no business inheriting a host's retry policy or queue defaults.
  class PurgeJob < ActiveJob::Base
    def perform(retention_days = McpLogs.retention_days)
      McpLogs::Call.purge!(retention_days)
    end
  end
end
