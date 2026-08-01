require "spec_helper"

RSpec.describe McpLogs::PurgeJob do
  it "deletes calls past the configured retention window" do
    McpLogs.retention_days = 7
    McpLogs::Call.create!(rpc_method: "tools/call", status: "ok", started_at: 10.days.ago)
    survivor = McpLogs::Call.create!(rpc_method: "tools/call", status: "ok", started_at: 1.day.ago)

    described_class.perform_now

    expect(McpLogs::Call.all).to eq([survivor])
  end

  it "accepts an explicit window" do
    McpLogs::Call.create!(rpc_method: "tools/call", status: "ok", started_at: 3.days.ago)

    described_class.perform_now(1)

    expect(McpLogs::Call.count).to eq(0)
  end
end
