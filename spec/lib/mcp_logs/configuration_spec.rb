require "spec_helper"

RSpec.describe McpLogs do
  it "has a version" do
    expect(McpLogs::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "ships defaults for everything a host can safely leave alone" do
    expect(McpLogs.enabled?).to be(true)
    expect(McpLogs.record_payloads?).to be(true)
    expect(McpLogs.max_payload_bytes).to eq(64_000)
    expect(McpLogs.retention_days).to eq(30)
    expect(McpLogs.page_size).to eq(50)
    expect(McpLogs.tool_sections).to eq({})
    expect(McpLogs.server).to be_nil
  end

  # base_controller_class is deliberately absent from the list above. The pages
  # render every argument and response the server has logged, so an engine that
  # booted without being told what to descend from would be serving the audit
  # log to anyone who could reach it.
  it "refuses to build a base controller until the host names one" do
    expect(McpLogs::Configuration.new.base_controller_class).to be_nil

    McpLogs.base_controller_class = nil

    expect { McpLogs.base_controller }
      .to raise_error(McpLogs::ConfigurationError, /base_controller_class.*config\/initializers\/mcp_logs\.rb/m)
  end

  # The generated initializer ships "CHANGE_ME", so this is the error a host who
  # ran the installer and read nothing else actually gets.
  it "says which setting is wrong when the named controller does not exist" do
    McpLogs.base_controller_class = "CHANGE_ME"

    expect { McpLogs.base_controller }
      .to raise_error(McpLogs::ConfigurationError, /base_controller_class is "CHANGE_ME"/)
  end

  it "yields the configuration to setup" do
    McpLogs.setup do |config|
      config.page_size = 5
      config.base_controller_class = "ActionController::API"
    end

    expect(McpLogs.page_size).to eq(5)
    expect(McpLogs.base_controller).to eq(ActionController::API)
  end

  it "calls the configured server lambda each time" do
    calls = 0
    McpLogs.server = -> { calls += 1 }

    McpLogs.server
    McpLogs.server

    expect(calls).to eq(2)
  end
end
