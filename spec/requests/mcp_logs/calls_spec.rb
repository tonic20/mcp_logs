require "spec_helper"

RSpec.describe "McpLogs::Calls", type: :request do
  def call!(**attrs)
    McpLogs::Call.create!({ rpc_method: "tools/call", started_at: 1.minute.ago, status: "ok" }.merge(attrs))
  end

  def rows
    Nokogiri::HTML(response.body).css("tbody").text
  end

  # Text of the panel titled `heading` on the call detail page, so a spec can
  # assert a notice appears next to the payload it actually describes instead
  # of just being somewhere on the page.
  def panel(heading)
    Nokogiri::HTML(response.body).css(".mcpl-panel").find { |node| node.at_css("h2")&.text&.include?(heading) }&.text.to_s
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

  describe "GET /mcp_logs/calls/:id" do
    it "shows the arguments, the response and the request metadata" do
      call = call!(
        tool_name: "search_apps",
        arguments: { "q" => "pagefly" },
        response: { "content" => [{ "type" => "text", "text" => "{\"ok\":true}" }] },
        session_id: "sess-1",
        actor: "curation-agent",
        client_name: "claude-code",
        ip: "203.0.113.7",
        duration_ms: 42.0,
        completed_at: Time.current
      )

      get "/mcp_logs/calls/#{call.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("search_apps")
      expect(response.body).to include("pagefly")
      expect(response.body).to include("curation-agent")
      expect(response.body).to include("203.0.113.7")
      expect(response.body).to include("42 ms")
    end

    it "links to the same tool and the same session" do
      call = call!(tool_name: "edit_app", session_id: "sess-9")

      get "/mcp_logs/calls/#{call.id}"

      expect(response.body).to include("/mcp_logs/calls?tool=edit_app")
      expect(response.body).to include("/mcp_logs/calls?session=sess-9")
    end

    it "shows an error call's type and message" do
      call = call!(status: "error", error_type: "internal_error", error_message: "RuntimeError: kaboom")

      get "/mcp_logs/calls/#{call.id}"

      expect(response.body).to include("internal_error")
      expect(response.body).to include("kaboom")
    end

    it "flags the arguments panel, and only the arguments panel, when arguments_truncated is set" do
      call = call!(
        arguments: { "truncated" => true, "bytes" => 90_000, "preview" => "{...}" },
        arguments_truncated: true,
        response: { "content" => "ok" }
      )

      get "/mcp_logs/calls/#{call.id}"

      expect(panel("Arguments")).to include("capped")
      expect(panel("Response")).not_to include("capped")
    end

    it "flags the response panel, and only the response panel, when response_truncated is set" do
      call = call!(
        arguments: { "q" => "pagefly" },
        response: { "truncated" => true, "bytes" => 90_000, "preview" => "{...}" },
        response_truncated: true
      )

      get "/mcp_logs/calls/#{call.id}"

      expect(panel("Response")).to include("capped")
      expect(panel("Arguments")).not_to include("capped")
    end

    it "flags the error panel, and only the error panel, when error_message_truncated is set" do
      call = call!(
        status: "error",
        error_type: "internal_error",
        error_message: "RuntimeError: kaboom",
        error_message_truncated: true,
        arguments: { "q" => "pagefly" },
        response: { "content" => "ok" }
      )

      get "/mcp_logs/calls/#{call.id}"

      expect(panel("Error")).to include("capped")
      expect(panel("Arguments")).not_to include("capped")
      expect(panel("Response")).not_to include("capped")
    end

    it "shows no capped notice anywhere when nothing was truncated" do
      call = call!(arguments: { "q" => "pagefly" }, response: { "content" => "ok" })

      get "/mcp_logs/calls/#{call.id}"

      expect(response.body).not_to include("capped")
    end
  end
end
