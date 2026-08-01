module McpLogs
  # Renders a server's tool contract as reference documentation for a person, as
  # opposed to the server itself, which serves it to an agent.
  #
  # Reads MCP::Tool.to_h rather than the tool classes' own DSL, because to_h is
  # the exact payload tools/list returns — so the page cannot drift from what a
  # connected client actually receives.
  module Docs
    Param   = Data.define(:name, :type, :required, :description)
    Tool    = Data.define(:name, :title, :description, :params)
    Section = Data.define(:title, :tools)

    UNGROUPED = "Ungrouped".freeze

    module_function

    # `sections` is { "Title" => ["tool_name", ...] }, in the order the host wants
    # them rendered. A tool missing from every section still renders, under
    # UNGROUPED, so an omission is visible rather than silent.
    def sections(server, sections = McpLogs.tool_sections)
      return [] if server.nil?

      by_name = tools_by_name(server)

      grouped = sections.map do |title, names|
        Section.new(title: title, tools: names.filter_map { |name| by_name[name.to_s] }.map { |klass| tool(klass) })
      end

      leftover = by_name.except(*sections.values.flatten.map(&:to_s))
      grouped << Section.new(title: UNGROUPED, tools: leftover.values.map { |klass| tool(klass) }) if leftover.any?

      grouped.reject { |section| section.tools.empty? }
    end

    # MCP::Server#tools is already { name => tool class }; going through it rather
    # than the class list means the page shows exactly what the server serves.
    def tools_by_name(server)
      server.tools.transform_keys(&:to_s)
    end

    def tool(klass)
      contract = klass.to_h

      Tool.new(
        name: contract[:name],
        title: contract[:title],
        description: contract[:description].to_s.strip,
        params: params(contract[:inputSchema] || {})
      )
    end

    # Property keys arrive as Symbols but the `required` array holds Strings, so
    # membership has to be tested on strings. Comparing the Symbol key directly
    # against `required` returns false for every parameter, silently rendering the
    # whole contract as optional.
    def params(schema)
      required = Array(schema[:required] || schema["required"]).map(&:to_s)
      properties = schema[:properties] || schema["properties"] || {}

      properties.map do |name, spec|
        spec = spec.symbolize_keys if spec.respond_to?(:symbolize_keys)

        Param.new(
          name: name.to_s,
          type: type_label(spec),
          required: required.include?(name.to_s),
          description: spec[:description].to_s
        )
      end
    end

    # Folds enum and array item type into the type label rather than the view, so
    # a schema's accepted values are visible on the page instead of only in the
    # tool's source file.
    def type_label(spec)
      base = spec[:type].to_s
      base = "#{base} of #{spec.dig(:items, :type)}" if base == "array" && spec.dig(:items, :type)
      spec[:enum] ? "#{base} (#{spec[:enum].join(" | ")})" : base
    end
  end
end
