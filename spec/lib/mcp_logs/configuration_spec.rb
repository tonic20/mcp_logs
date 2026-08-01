require "spec_helper"

RSpec.describe McpLogs do
  it "has a version" do
    expect(McpLogs::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "ships defaults that work without any host configuration" do
    expect(McpLogs.enabled?).to be(true)
    expect(McpLogs.record_payloads?).to be(true)
    expect(McpLogs.max_payload_bytes).to eq(64_000)
    expect(McpLogs.retention_days).to eq(30)
    expect(McpLogs.page_size).to eq(50)
    expect(McpLogs.tool_sections).to eq({})
    expect(McpLogs.server).to be_nil
    expect(McpLogs.base_controller).to eq(ActionController::Base)
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
