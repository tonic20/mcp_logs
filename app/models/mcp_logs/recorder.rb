module McpLogs
  # The body of the lambda a host hands to MCP::Configuration#around_request.
  #
  # The gem calls it as `around_request.call(data, &block)`, where `data` is a
  # hash the server keeps writing into for the duration of the block: tool_name,
  # tool_arguments, client and error all land *during* the call, not before it.
  # So the row is inserted with what is known up front (the method) and completed
  # with everything else once the block returns.
  #
  # Load-bearing requirement on the host: build a fresh MCP::Server per request.
  # In mcp 1.0.0 the `data` hash above is not per-request — it is
  # `@instrumentation_data`, a plain instance variable on the MCP::Server
  # object, reassigned to `{}` at the top of every `instrument_call`
  # (lib/mcp/instrumentation.rb). If one server instance serves two concurrent
  # requests, request B's reassignment can land while A is still mid-handler,
  # so A's later `tool_name`/`tool_arguments`/`error` writes end up in B's hash
  # instead of A's. This recorder only holds the reference it was handed and
  # trusts it describes the request in progress; it has no way to detect or
  # correct for a shared server, so the host must not memoize or share one.
  class Recorder
    # error_message goes into a plain text column, not jsonb, and has no
    # upstream size bound the way arguments/response do via Payload: exception
    # messages routinely echo attribute values or an entire failing SQL
    # statement. This is a size bound only, not redaction — filtering
    # free-text exception messages is out of scope here.
    ERROR_MESSAGE_BYTES = 2_000

    # Cap for every string column a client can influence: tool_name, session_id,
    # client_name, client_version, protocol_version, user_agent.
    #
    # These are not validated input. mcp 1.0.0 reads tool_name straight from
    # params.name and hands it to this hook *before* looking the tool up, so an
    # unknown tool records whatever the client sent; the rest are raw request
    # headers. Uncapped, one looping client writes megabyte rows for the whole
    # retention window and puts one <option> per distinct value on the calls
    # page — taking down the page an operator would open to find out why.
    #
    # 255 is the migration's `limit:`, and PostgreSQL's varchar(n) counts
    # characters, so this counts characters too and a value cut here always
    # fits. It is far above every legitimate value (a tool name is an
    # identifier, a session id a UUID, a protocol version a date), which is why
    # the cut is silent: unlike a capped payload there is nothing an operator
    # would want back, so it gets no *_truncated flag.
    STRING_LIMIT = 255

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
          }.merge(capped_context)
        )
      end
    end

    def finish(record, data, started:, response: nil, exception: nil)
      return if record.nil?

      # Measured before Payload.prepare and the write below do their own work,
      # so duration_ms times the handler, not the recorder's own bookkeeping.
      elapsed_ms = (clock - started) * 1000

      guarded do
        arguments, arguments_truncated = Payload.prepare(data[:tool_arguments])
        body, response_truncated = Payload.prepare(result_payload(response))
        error_message, error_message_truncated = capped_error_message(exception)

        # update_columns, not update!: this writes every column named below
        # unconditionally, where update! sends only the ones ActiveRecord considers
        # dirty relative to the object `start` built. That difference matters for
        # exactly one case, and it is not hypothetical. If the sweep settled this
        # row as abandoned while the handler was still running, the row now carries
        # an error_type and error_message this in-memory object has never seen —
        # and since both are nil in memory AND nil in the assignment below, dirty
        # tracking omits them, leaving a completed call permanently labelled
        # abandoned. Validations go with them: these values are constructed rather
        # than user input, and a validation failure would only be swallowed by
        # `guarded` anyway.
        record.update_columns(
          updated_at: Time.current,
          tool_name: capped(data[:tool_name]),
          arguments: arguments,
          arguments_truncated: arguments_truncated,
          response: body,
          response_truncated: response_truncated,
          tool_error: tool_error?(response),
          cancelled: !!data[:cancelled],
          status: (exception || data[:error]) ? "error" : "ok",
          error_type: data[:error]&.to_s || exception&.class&.name,
          error_message: error_message,
          error_message_truncated: error_message_truncated,
          client_name: capped(client(data)[:name]),
          client_version: capped(client(data)[:version]),
          duration_ms: elapsed_ms,
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

    # actor is the host's own label rather than anything the client sent, but it
    # shares a column width with the rest, so it is capped alongside them.
    def capped_context
      Context.current
        .slice(:session_id, :protocol_version, :actor, :ip, :user_agent)
        .transform_values { |value| capped(value) }
    end

    def capped(value)
      value && value.to_s.truncate(STRING_LIMIT, omission: "")
    end

    def capped_error_message(exception)
      return [nil, false] unless exception

      message = "#{exception.class}: #{exception.message}"
      return [message, false] if message.bytesize <= ERROR_MESSAGE_BYTES

      # byteslice can cut mid-character; scrub keeps the column valid UTF-8.
      [message.byteslice(0, ERROR_MESSAGE_BYTES).scrub(""), true]
    end

    # The log is never the reason a tool call fails. A failed statement inside
    # an open PostgreSQL transaction leaves the connection aborted, so every
    # subsequent query on it fails too — including the handler's own, if it is
    # running inside a transaction of its own. requires_new: true opens a
    # savepoint instead of reusing the surrounding one, so a failure here rolls
    # back only the log write and leaves any enclosing transaction usable.
    def guarded
      Call.transaction(requires_new: true) { yield }
    rescue StandardError => exception
      # The report is itself guarded. Anything escaping this method reaches
      # MCP::Instrumentation#instrument_call, which reports and re-raises, so a
      # failing error reporter would turn an already-committed tool write into a
      # -32603 for the client — which an agent will retry, duplicating the
      # write. ErrorReporter#report already swallows subscriber failures when a
      # logger is present, so this is near-unreachable; it is also the only line
      # in the recorder that was outside the guarantee the rest of it makes.
      begin
        Rails.error.report(exception, handled: true, source: "mcp_logs")
      rescue StandardError
        nil
      end
      nil
    end
  end
end
