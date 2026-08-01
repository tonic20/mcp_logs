module McpLogs
  # Descends from ActiveJob::Base rather than the host's ApplicationJob: the gem
  # has no business inheriting a host's retry policy or queue defaults.
  class PurgeJob < ActiveJob::Base
    # Retention alone never settles a row stranded in "running" — it stays that
    # way until the day it is deleted. Both jobs of housekeeping run here so a
    # host that schedules one thing gets both. Purge first: a stranded row past
    # the retention window is deleted rather than swept.
    def perform(retention_days = McpLogs.retention_days, abandoned_after_hours = McpLogs.abandoned_after_hours)
      McpLogs::Call.purge!(retention_days)
      McpLogs::Call.sweep_abandoned!(abandoned_after_hours)
    end
  end
end
