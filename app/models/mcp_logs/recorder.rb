module McpLogs
  # The body of the lambda a host hands to MCP::Configuration#around_request.
  #
  # The gem calls it as `around_request.call(data, &block)`, where `data` is a
  # hash the server keeps writing into for the duration of the block: tool_name,
  # tool_arguments, client and error all land *during* the call, not before it.
  # So the row is inserted with what is known up front (the method) and completed
  # with everything else once the block returns.
  class Recorder
    def self.around_request(server_name: nil)
      recorder = new(server_name: server_name)
      ->(data, &handler) { recorder.call(data, &handler) }
    end

    def initialize(server_name: nil)
      @server_name = server_name
    end

    def call(data, &handler)
      return handler.call unless McpLogs.enabled?

      record  = start(data)
      started = clock

      begin
        response = handler.call
      rescue Exception => exception # rubocop:disable Lint/RescueException
        # Re-raised immediately and unchanged; the rescue exists only so a
        # failing request still gets a completed row rather than a stuck one.
        finish(record, data, started: started, exception: exception)
        raise
      end

      finish(record, data, started: started, response: response)
      response
    end

    private

    # data[:duration] is set in the gem's `ensure`, which runs after this lambda
    # returns, so the recorder times the handler itself.
    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def start(data)
      guarded do
        Call.create!(
          {
            server_name: @server_name,
            rpc_method: data[:method].to_s,
            status: "running",
            started_at: Time.current
          }.merge(Context.current.slice(:session_id, :protocol_version, :actor, :ip, :user_agent))
        )
      end
    end

    def finish(record, data, started:, response: nil, exception: nil)
      return if record.nil?

      guarded do
        arguments, arguments_capped = Payload.prepare(data[:tool_arguments])
        body, body_capped = Payload.prepare(result_payload(response))

        record.update!(
          tool_name: data[:tool_name],
          arguments: arguments,
          response: body,
          truncated: arguments_capped || body_capped,
          tool_error: tool_error?(response),
          cancelled: !!data[:cancelled],
          status: exception || data[:error] ? "error" : "ok",
          error_type: data[:error]&.to_s || exception&.class&.name,
          error_message: exception && "#{exception.class}: #{exception.message}",
          client_name: client(data)[:name],
          client_version: client(data)[:version],
          duration_ms: (clock - started) * 1000,
          completed_at: Time.current
        )
      end
    end

    # A cancelled request returns the gem's NO_RESPONSE sentinel, and non-tool
    # methods can return anything; only a Hash is worth storing as a result.
    def result_payload(response)
      response.is_a?(Hash) ? response : nil
    end

    # An MCP::Tool::Response built with error: true serializes to isError: true.
    # That is a *successful* JSON-RPC response carrying a tool-level failure —
    # a rejected pattern, an already-resolved domain — so it gets its own flag
    # rather than being folded into status.
    def tool_error?(response)
      return false unless response.is_a?(Hash)

      !!(response[:isError] || response["isError"])
    end

    def client(data)
      value = data[:client]
      value.is_a?(Hash) ? value.symbolize_keys : {}
    end

    # The log is never the reason a tool call fails.
    def guarded
      yield
    rescue StandardError => exception
      Rails.error.report(exception, handled: true, source: "mcp_logs")
      nil
    end
  end
end
