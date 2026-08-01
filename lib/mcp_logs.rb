require "pagy"
require "mcp_logs/version"
require "mcp_logs/configuration"
require "mcp_logs/engine"
require "mcp_logs/context"
require "mcp_logs/payload"

module McpLogs
  # `server` is absent on purpose: McpLogs.server calls the configured lambda
  # rather than returning it, so it gets an explicit reader below and only its
  # writer is generated here.
  SETTINGS = %i[
    enabled base_controller_class tool_sections record_payloads
    max_payload_bytes payload_filter retention_days abandoned_after_hours page_size
  ].freeze

  MISSING_BASE_CONTROLLER = <<~MESSAGE.freeze
    McpLogs has no base_controller_class, so its pages would have no authentication.

    Set it in config/initializers/mcp_logs.rb to a controller of your own whose
    authentication the log pages should inherit:

      config.base_controller_class = "Admin::BaseController"

    Use "ActionController::Base" only if you intend /mcp_logs — every tool
    argument and response your MCP server has recorded — to be readable by
    anyone who can reach the app.
  MESSAGE

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

    def server=(value)
      configuration.server = value
    end

    # Resolved when the engine's ApplicationController is first autoloaded, i.e.
    # after the host's initializers have run.
    #
    # There is no default. Every page this engine serves renders arguments and
    # responses the host's MCP server has logged, so an engine that quietly
    # descended from ActionController::Base would publish the audit log of any
    # app that installed it without reading the whole README. Failing here costs
    # a stranger one boot; the alternative costs them the log.
    def base_controller
      configured = configuration.base_controller_class.to_s
      raise ConfigurationError, MISSING_BASE_CONTROLLER if configured.empty?

      configured.constantize
    rescue NameError
      # The generated initializer ships a placeholder, so "set but not resolvable"
      # is the likeliest way a host gets here — and a bare NameError names the
      # constant without saying which setting produced it.
      raise ConfigurationError, "McpLogs base_controller_class is #{configured.inspect}, " \
                                "which does not name a controller. #{MISSING_BASE_CONTROLLER}"
    end

    def around_request(server_name: nil)
      McpLogs::Recorder.around_request(server_name: server_name)
    end

    def with_context(request = nil, **options, &block)
      McpLogs::Context.with(request, **options, &block)
    end
  end
end
