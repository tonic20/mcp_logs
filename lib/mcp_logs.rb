require "pagy"
require "mcp_logs/version"
require "mcp_logs/configuration"
require "mcp_logs/engine"
require "mcp_logs/context"
require "mcp_logs/payload"

module McpLogs
  SETTINGS = %i[
    enabled server base_controller_class tool_sections
    record_payloads max_payload_bytes payload_filter retention_days page_size
  ].freeze

  class << self
    def setup
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    # Specs and hosts that reconfigure at runtime need a clean slate.
    def reset_configuration!
      @configuration = Configuration.new
    end

    # One reader and one writer per setting, so `McpLogs.page_size = 1` works in a
    # spec and `McpLogs.page_size` reads naturally in a view.
    SETTINGS.each do |setting|
      define_method(setting) { configuration.public_send(setting) }
      define_method(:"#{setting}=") { |value| configuration.public_send(:"#{setting}=", value) }
    end

    def enabled? = !!configuration.enabled

    def record_payloads? = !!configuration.record_payloads

    # Calls the configured lambda. Returns nil when no server is configured, which
    # the docs page renders as "no server configured" rather than raising.
    def server = configuration.server&.call

    def base_controller = configuration.base_controller_class.to_s.constantize

    def around_request(server_name: nil)
      McpLogs::Recorder.around_request(server_name: server_name)
    end

    def with_context(request = nil, **options, &block)
      McpLogs::Context.with(request, **options, &block)
    end
  end
end
