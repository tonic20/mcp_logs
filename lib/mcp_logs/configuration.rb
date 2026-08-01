module McpLogs
  class Configuration
    # server:                a lambda returning the host's MCP::Server. Read by the
    #                        docs page only — capture never builds a server.
    # base_controller_class: a String, constantized on first autoload of the engine's
    #                        ApplicationController, i.e. after host initializers have run.
    #                        Point it at a host controller to inherit its authentication.
    # tool_sections:         { "Section title" => ["tool_name", ...] }. Names, not classes,
    #                        so the gem never references host constants.
    attr_accessor :enabled, :server, :base_controller_class, :tool_sections,
                  :record_payloads, :max_payload_bytes, :payload_filter,
                  :retention_days, :page_size

    def initialize
      @enabled               = true
      @server                = nil
      @base_controller_class = "ActionController::Base"
      @tool_sections         = {}
      @record_payloads       = true
      @max_payload_bytes     = 64_000
      @payload_filter        = ->(payload) { payload }
      @retention_days        = 30
      @page_size             = 50
    end
  end
end
