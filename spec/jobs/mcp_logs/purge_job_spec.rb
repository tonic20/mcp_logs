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

  # Retention alone never fixes a stranded row: it stays "running" until the day
  # it is deleted. The same scheduled job settles them, so a host that schedules
  # one thing gets both.
  it "also sweeps calls stranded in running" do
    stranded = McpLogs::Call.create!(rpc_method: "tools/call", status: "running", started_at: 3.days.ago)

    described_class.perform_now

    expect(stranded.reload.error_type).to eq(McpLogs::Call::ABANDONED)
  end

  it "accepts an explicit abandoned bound" do
    stranded = McpLogs::Call.create!(rpc_method: "tools/call", status: "running", started_at: 2.hours.ago)

    described_class.perform_now(McpLogs.retention_days, 1)

    expect(stranded.reload.status).to eq("error")
  end
end
