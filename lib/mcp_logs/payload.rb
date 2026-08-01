module McpLogs
  # Turns a tool's arguments or a handler's result into something safe to store:
  # host-redacted, host-filtered, and bounded in size.
  module Payload
    module_function

    # Returns [value_to_store, truncated?]. A nil value, or payload recording
    # turned off, stores nothing at all.
    def prepare(value)
      return [nil, false] if value.nil?
      return [nil, false] unless McpLogs.record_payloads?

      filtered = McpLogs.payload_filter.call(parameter_filter.filter(normalize(value)))
      cap(filtered)
    end

    # ActiveSupport::ParameterFilter only walks hashes, and the columns are jsonb,
    # so a bare scalar result gets a wrapper rather than being dropped.
    def normalize(value)
      value.is_a?(Hash) ? value.deep_stringify_keys : { "value" => value }
    end

    def cap(value)
      json = value.to_json
      return [value, false] if json.bytesize <= McpLogs.max_payload_bytes

      # byteslice can cut mid-character; scrub keeps the column valid UTF-8.
      preview = json.byteslice(0, McpLogs.max_payload_bytes).scrub("")
      [{ "truncated" => true, "bytes" => json.bytesize, "preview" => preview }, true]
    end

    # Rebuilt only when reset! is called: compiling the filter's regexps on every
    # logged call would be pure overhead on the request path.
    def parameter_filter
      @parameter_filter ||=
        ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end

    def reset!
      @parameter_filter = nil
    end
  end
end
