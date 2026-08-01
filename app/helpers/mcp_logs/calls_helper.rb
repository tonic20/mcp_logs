module McpLogs
  module CallsHelper
    def mcpl_status_badge(call)
      label = call.tool_error && call.status == "ok" ? "tool error" : call.status
      modifier = call.tool_error && call.status == "ok" ? "warn" : call.status

      tag.span(label, class: "mcpl-badge mcpl-badge--#{modifier}")
    end

    def mcpl_duration(call)
      return "—" if call.duration_ms.nil?
      return "#{call.duration_ms.round} ms" if call.duration_ms < 1000

      "#{(call.duration_ms / 1000).round(2)} s"
    end

    def mcpl_value(value)
      value.presence || tag.span("—", class: "mcpl-muted")
    end

    def mcpl_json(value)
      return tag.p("None.", class: "mcpl-muted") if value.blank?

      tag.pre(JSON.pretty_generate(value), class: "mcpl-json")
    end

    # A capped payload is self-identifying: McpLogs::Payload.cap replaces the
    # value with a marker hash carrying these three keys. The call-level
    # `truncated` column ORs arguments, response and error_message together,
    # so it can't say which one was actually capped — this checks the payload
    # itself instead, so each panel speaks only for what it holds.
    def mcpl_capped?(value)
      value.is_a?(Hash) && value["truncated"] == true && value.key?("bytes") && value.key?("preview")
    end
  end
end
