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
  end
end
