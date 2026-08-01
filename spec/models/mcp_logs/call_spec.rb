require "spec_helper"

RSpec.describe McpLogs::Call do
  def call!(**attrs)
    described_class.create!({ rpc_method: "tools/call", started_at: Time.current }.merge(attrs))
  end

  it "requires an rpc_method, a status in the list, and a start time" do
    expect(described_class.new(started_at: Time.current)).not_to be_valid
    expect(described_class.new(rpc_method: "ping", started_at: Time.current, status: "weird")).not_to be_valid
    expect(described_class.new(rpc_method: "ping", started_at: Time.current)).to be_valid
  end

  it "defaults to running" do
    expect(call!).to be_running
  end

  it "orders recent first" do
    older = call!(started_at: 2.hours.ago)
    newer = call!(started_at: 1.minute.ago)

    expect(described_class.recent.to_a).to eq([newer, older])
  end

  it "filters by method, tool, status and session, ignoring blank values" do
    hit  = call!(rpc_method: "tools/call", tool_name: "search_apps", status: "ok", session_id: "s1")
    miss = call!(rpc_method: "tools/list", tool_name: nil, status: "error", session_id: "s2")

    expect(described_class.for_method("tools/call")).to eq([hit])
    expect(described_class.for_tool("search_apps")).to eq([hit])
    expect(described_class.with_status("ok")).to eq([hit])
    expect(described_class.for_session("s1")).to eq([hit])
    expect(described_class.for_method("").count).to eq(2)
    expect(described_class.for_tool(nil).count).to eq(2)
  end

  it "counts calls per tool" do
    2.times { call!(tool_name: "search_apps") }
    call!(tool_name: "edit_app")
    call!(tool_name: nil, rpc_method: "tools/list")

    expect(described_class.tool_counts).to eq("search_apps" => 2, "edit_app" => 1)
  end

  it "purges calls older than the retention window and reports how many went" do
    call!(started_at: 40.days.ago)
    call!(started_at: 40.days.ago)
    survivor = call!(started_at: 1.day.ago)

    expect(described_class.purge!(30)).to eq(2)
    expect(described_class.all).to eq([survivor])
  end

  it "defaults purge to the configured retention window" do
    McpLogs.retention_days = 1
    call!(started_at: 2.days.ago)

    expect { described_class.purge! }.to change(described_class, :count).by(-1)
  end
end
