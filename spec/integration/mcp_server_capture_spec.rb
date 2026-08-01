require "spec_helper"
require_relative "../support/fake_tools"

RSpec.describe "capturing a real MCP::Server" do
  let(:server) { FakeTools.server }

  def rpc(method, params = {}, id: 1)
    body = server.handle_json({ jsonrpc: "2.0", id: id, method: method, params: params }.to_json)
    body && JSON.parse(body)
  end

  it "records a tools/call with its name, arguments and result" do
    rpc("tools/call", { name: "echo", arguments: { text: "hello" } })

    call = McpLogs::Call.sole
    expect(call.rpc_method).to eq("tools/call")
    expect(call.tool_name).to eq("echo")
    expect(call.arguments).to eq("text" => "hello")
    expect(call.status).to eq("ok")
    expect(call.tool_error).to be(false)
    expect(call.response.to_json).to include("hello")
    expect(call.duration_ms).to be >= 0
    expect(call.server_name).to eq("fake")
  end

  it "records tools/list, which has no tool name" do
    rpc("tools/list")

    call = McpLogs::Call.sole
    expect(call.rpc_method).to eq("tools/list")
    expect(call.tool_name).to be_nil
    expect(call.status).to eq("ok")
  end

  it "records the client info sent with initialize" do
    rpc("initialize", {
      protocolVersion: "2025-06-18",
      capabilities: {},
      clientInfo: { name: "claude-code", version: "9.9" }
    })

    call = McpLogs::Call.sole
    expect(call.client_name).to eq("claude-code")
    expect(call.client_version).to eq("9.9")
  end

  it "records a tool-level failure as a successful call with tool_error set" do
    rpc("tools/call", { name: "refuse", arguments: {} })

    call = McpLogs::Call.sole
    expect(call.status).to eq("ok")
    expect(call.tool_error).to be(true)
  end

  it "records a raising tool as an error and still answers the client" do
    body = rpc("tools/call", { name: "explode", arguments: {} })

    expect(body["error"]).to be_present
    call = McpLogs::Call.sole
    expect(call.status).to eq("error")
    expect(call.error_type).to eq("internal_error")
    expect(call.completed_at).to be_present
  end

  it "records an unknown tool as an error" do
    rpc("tools/call", { name: "nope", arguments: {} })

    call = McpLogs::Call.sole
    expect(call.status).to eq("error")
    # The server's call_tool sets data[:error] = :tool_not_found before raising,
    # but its own top-level rescue(RequestHandlerError) immediately overwrites it
    # with the raised exception's error_type — :invalid_params for this raise
    # (lib/mcp/server.rb: `add_instrumentation_data(tool_name:, error: :tool_not_found)`
    # followed by `raise RequestHandlerError.new(..., error_type: :invalid_params)`,
    # then the dispatch rescue's `add_instrumentation_data(error: e.error_type)`).
    # So :invalid_params, not :tool_not_found, is what actually reaches the recorder.
    expect(call.error_type).to eq("invalid_params")
    expect(call.tool_name).to eq("nope")
  end

  it "carries the ambient HTTP context onto every call in the block" do
    McpLogs::Context.with(nil, actor: "curation-agent", session_id: "sess-9") do
      rpc("tools/call", { name: "echo", arguments: { text: "hi" } })
    end

    call = McpLogs::Call.sole
    expect(call.actor).to eq("curation-agent")
    expect(call.session_id).to eq("sess-9")
  end
end
