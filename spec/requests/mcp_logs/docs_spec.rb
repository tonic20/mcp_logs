require "spec_helper"
require_relative "../../support/fake_tools"

RSpec.describe "McpLogs::Docs", type: :request do
  before { McpLogs.server = -> { FakeTools.server } }

  it "renders the server identity and every tool" do
    get "/mcp_logs/docs"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("fake")
    expect(response.body).to include("1.0.0")
    expect(response.body).to include("A fake server for specs.")
    expect(response.body).to include("echo")
    expect(response.body).to include("refuse")
    expect(response.body).to include("explode")
  end

  it "renders the configured sections and parameter tables" do
    McpLogs.tool_sections = { "Basics" => %w[echo] }

    get "/mcp_logs/docs"

    expect(response.body).to include("Basics")
    expect(response.body).to include("Ungrouped")
    expect(response.body).to include("text")
    expect(response.body).to include("string")
  end

  it "says so for a tool with no parameters" do
    get "/mcp_logs/docs"

    expect(response.body).to include("No parameters.")
  end

  it "shows each tool's call count, linking into the filtered call list" do
    McpLogs::Call.create!(rpc_method: "tools/call", tool_name: "echo", status: "ok", started_at: Time.current)
    McpLogs::Call.create!(rpc_method: "tools/call", tool_name: "echo", status: "ok", started_at: Time.current)

    get "/mcp_logs/docs"

    expect(response.body).to include("/mcp_logs/calls?tool=echo")
    expect(response.body).to match(/2 calls/)
    expect(response.body).to match(/never called/i)
  end

  it "renders a plain explanation when no server is configured" do
    McpLogs.server = nil

    get "/mcp_logs/docs"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No MCP server is configured")
  end
end
