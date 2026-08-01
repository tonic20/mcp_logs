module McpLogs
  # One JSON-RPC request served by an MCP server. Inserted as "running" the
  # moment the request starts, updated when it finishes — so a long tool call is
  # visible while it runs rather than only after it returns.
  class Call < ApplicationRecord
    STATUSES = %w[running ok error].freeze

    validates :rpc_method, presence: true
    validates :started_at, presence: true
    validates :status, inclusion: { in: STATUSES }

    scope :recent, -> { order(started_at: :desc, id: :desc) }

    # Filters take request params straight from the controller, so a blank value
    # means "no filter" rather than "match the empty string".
    scope :for_method,  ->(value) { where(rpc_method: value) if value.present? }
    scope :for_tool,    ->(value) { where(tool_name: value) if value.present? }
    scope :with_status, ->(value) { where(status: value) if value.present? }
    scope :for_session, ->(value) { where(session_id: value) if value.present? }

    def self.tool_counts
      where.not(tool_name: nil).group(:tool_name).count
    end

    def self.purge!(retention_days = McpLogs.retention_days)
      where(started_at: ...retention_days.to_i.days.ago).delete_all
    end

    def running? = status == "running"

    def duration_seconds = duration_ms && duration_ms / 1000.0
  end
end
