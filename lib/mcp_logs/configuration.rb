module McpLogs
  # Raised when the engine is asked to do something the host has not told it how
  # to do. Always fatal at boot or on the first request, never mid-capture.
  class ConfigurationError < StandardError; end

  class Configuration
    # server:                a lambda returning the host's MCP::Server. Read by the
    #                        docs page only — capture never builds a server.
    # base_controller_class: a String, constantized on first autoload of the engine's
    #                        ApplicationController, i.e. after host initializers have run.
    #                        Has no default on purpose — see McpLogs.base_controller.
    # tool_sections:         { "Section title" => ["tool_name", ...] }. Names, not classes,
    #                        so the gem never references host constants.
    attr_accessor :enabled, :server, :base_controller_class, :tool_sections,
                  :record_payloads, :max_payload_bytes, :payload_filter,
                  :retention_days, :abandoned_after_hours, :page_size

    def initialize
      @enabled               = true
      @server                = nil
      @base_controller_class = nil
      @tool_sections         = {}
      @record_payloads       = true
      @max_payload_bytes     = 64_000
      @payload_filter        = ->(payload) { payload }
      @retention_days        = 30
      @abandoned_after_hours = 24
      @page_size             = 50
    end
  end
end
