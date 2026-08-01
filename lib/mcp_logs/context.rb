module McpLogs
  # HTTP-level facts about the request being served. The mcp gem's around_request
  # hook sees none of this, so the host wraps its handler call in
  # McpLogs.with_context(request) and the recorder reads it back here.
  #
  # Fiber storage rather than Thread.current: it follows into fibers the server
  # may spawn, and it is restored on unwind, so a raising handler cannot strand a
  # stale context on a pooled thread.
  module Context
    KEY = :mcp_logs_context

    module_function

    def current
      Fiber[KEY] || {}
    end

    def with(request = nil, actor: nil, session_id: nil, protocol_version: nil)
      previous = Fiber[KEY]
      explicit = { actor: actor, session_id: session_id, protocol_version: protocol_version }.compact
      Fiber[KEY] = from_request(request).merge(explicit)
      yield
    ensure
      Fiber[KEY] = previous
    end

    def from_request(request)
      return {} if request.nil?

      {
        ip: request.respond_to?(:remote_ip) ? request.remote_ip : request.ip,
        user_agent: request.user_agent.presence,
        session_id: header(request, "Mcp-Session-Id"),
        protocol_version: header(request, "Mcp-Protocol-Version")
      }.compact
    end

    def header(request, name)
      request.get_header("HTTP_#{name.upcase.tr("-", "_")}").presence
    end
  end
end
