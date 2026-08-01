require "spec_helper"

RSpec.describe "McpLogs::Calls", type: :request do
  def call!(**attrs)
    McpLogs::Call.create!({ rpc_method: "tools/call", started_at: 1.minute.ago, status: "ok" }.merge(attrs))
  end

  def rows
    Nokogiri::HTML(response.body).css("tbody").text
  end

  it "lists calls newest first" do
    call!(tool_name: "search_apps", started_at: 2.hours.ago)
    call!(tool_name: "edit_app", started_at: 1.minute.ago)

    get "/mcp_logs"

    expect(response).to have_http_status(:ok)
    expect(response.body.index("edit_app")).to be < response.body.index("search_apps")
  end

  it "filters by tool, method, status and session" do
    call!(tool_name: "search_apps", session_id: "s1")
    call!(tool_name: "edit_app", rpc_method: "tools/list", status: "error", session_id: "s2")

    get "/mcp_logs", params: { tool: "search_apps" }
    expect(rows).to include("search_apps")
    expect(rows).not_to include("edit_app")

    get "/mcp_logs", params: { status: "error" }
    expect(rows).to include("edit_app")

    get "/mcp_logs", params: { method: "tools/list" }
    expect(rows).to include("edit_app")

    get "/mcp_logs", params: { session: "s1" }
    expect(rows).to include("search_apps")
    expect(rows).not_to include("edit_app")
  end

  it "keeps every logged tool in the filter dropdown, so a filtered page can still switch to it" do
    call!(tool_name: "search_apps")
    call!(tool_name: "edit_app")

    get "/mcp_logs", params: { tool: "search_apps" }

    options = Nokogiri::HTML(response.body).css("select#tool option").map(&:text)
    expect(options).to include("search_apps", "edit_app")
  end

  it "paginates using the configured page size" do
    McpLogs.page_size = 1
    call!(tool_name: "search_apps")
    call!(tool_name: "edit_app")

    get "/mcp_logs"

    expect(response.body.scan("<tbody").size).to eq(1)
    expect(Nokogiri::HTML(response.body).css("tbody tr").size).to eq(1)
    expect(response.body).to include("Next")
  end

  it "says so when there is nothing to show" do
    get "/mcp_logs"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No calls recorded yet")
  end

  it "shows a running call as running" do
    call!(status: "running", tool_name: "replay_observations")

    get "/mcp_logs"

    expect(response.body).to include("running")
  end
end
