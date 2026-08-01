require "spec_helper"

RSpec.describe McpLogs::Context do
  def rack_request(headers = {})
    ActionDispatch::Request.new(
      Rack::MockRequest.env_for("/mcp", method: "POST").merge(
        "REMOTE_ADDR" => "203.0.113.7",
        "HTTP_USER_AGENT" => "claude-code/1.0"
      ).merge(headers)
    )
  end

  it "is empty outside a block" do
    expect(described_class.current).to eq({})
  end

  it "reads ip, user agent and the MCP headers off the request" do
    request = rack_request(
      "HTTP_MCP_SESSION_ID" => "sess-123",
      "HTTP_MCP_PROTOCOL_VERSION" => "2025-06-18"
    )

    described_class.with(request) do
      expect(described_class.current).to eq(
        ip: "203.0.113.7",
        user_agent: "claude-code/1.0",
        session_id: "sess-123",
        protocol_version: "2025-06-18"
      )
    end
  end

  it "omits headers that are absent rather than storing nils" do
    described_class.with(rack_request) do
      expect(described_class.current.keys).to contain_exactly(:ip, :user_agent)
    end
  end

  it "lets explicit options override what the request carries" do
    described_class.with(rack_request, actor: "curation-agent", session_id: "explicit") do
      expect(described_class.current[:actor]).to eq("curation-agent")
      expect(described_class.current[:session_id]).to eq("explicit")
    end
  end

  it "works with no request at all" do
    described_class.with(nil, actor: "cron") do
      expect(described_class.current).to eq(actor: "cron")
    end
  end

  it "restores the previous context, even when the block raises" do
    expect {
      described_class.with(rack_request) { raise "boom" }
    }.to raise_error("boom")

    expect(described_class.current).to eq({})
  end

  it "nests without leaking the inner context outward" do
    described_class.with(nil, actor: "outer") do
      described_class.with(nil, actor: "inner") do
        expect(described_class.current[:actor]).to eq("inner")
      end
      expect(described_class.current[:actor]).to eq("outer")
    end
  end
end
