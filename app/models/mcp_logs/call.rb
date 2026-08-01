module McpLogs
  # One JSON-RPC request served by an MCP server. Inserted as "running" the
  # moment the request starts, updated when it finishes — so a long tool call is
  # visible while it runs rather than only after it returns.
  class Call < ApplicationRecord
    STATUSES = %w[running ok error].freeze

    # error_type for a row whose finish never landed. Its own value rather than
    # an exception class name, because no exception was raised here — the
    # process that would have raised one is gone.
    ABANDONED = "abandoned".freeze

    ABANDONED_MESSAGE = "No completion was ever recorded for this call. Whatever was " \
                        "serving it stopped first — a deploy, a crash, or a failed log " \
                        "write — so its result and duration are unknown.".freeze

    # How many distinct values a filter dropdown will offer. Bounded because
    # tool_name is raw client input (see Recorder::STRING_LIMIT): the number of
    # distinct values is capped by requests served, not by tools that exist, so
    # an unbounded SELECT DISTINCT would let one looping client put an <option>
    # per request on every render of the page opened to investigate it.
    FILTER_OPTIONS_LIMIT = 200

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

    def self.filter_values(column)
      where.not(column => nil).distinct.order(column).limit(FILTER_OPTIONS_LIMIT).pluck(column)
    end

    def self.tool_counts
      where.not(tool_name: nil).group(:tool_name).count
    end

    def self.purge!(retention_days = McpLogs.retention_days)
      where(started_at: ...retention_days.to_i.days.ago).delete_all
    end

    # A row is inserted "running" and updated when the request finishes. If that
    # update never lands — the container restarted mid-call, or the write itself
    # failed — nothing retries it, so the row would claim to be running for the
    # entire retention window: a permanent false positive on the page an
    # operator reads to answer "what is the agent doing right now", and an
    # inflated count in tool_counts.
    #
    # completed_at and duration_ms stay nil on purpose. The sweep knows the call
    # did not finish; it does not know when it stopped, and stamping "now" would
    # invent a fact. Returns how many rows it settled.
    def self.sweep_abandoned!(hours = McpLogs.abandoned_after_hours)
      where(status: "running")
        .where(started_at: ...hours.to_i.hours.ago)
        .update_all(status: "error", error_type: ABANDONED, error_message: ABANDONED_MESSAGE,
                    updated_at: Time.current)
    end

    def running? = status == "running"

    def duration_seconds = duration_ms && duration_ms / 1000.0
  end
end
