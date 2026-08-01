require "spec_helper"

RSpec.describe McpLogs::Recorder do
  # The gem hands the lambda a hash it mutates during the block. These specs do
  # the same by hand, so they pin the contract without booting a server.
  def record(data, server_name: "test-server", &handler)
    described_class.around_request(server_name: server_name).call(data, &handler)
  end

  it "records a successful tool call" do
    result = record({ method: "tools/call" }) do |*|
      { content: [{ type: "text", text: "{}" }], isError: false }
    end

    expect(result[:isError]).to be(false)
    call = McpLogs::Call.sole
    expect(call.rpc_method).to eq("tools/call")
    expect(call.status).to eq("ok")
    expect(call.server_name).to eq("test-server")
    expect(call.completed_at).to be_present
    expect(call.duration_ms).to be >= 0
  end

  it "picks up the tool name and arguments the server adds during the block" do
    data = { method: "tools/call" }
    record(data) do
      data[:tool_name] = "search_apps"
      data[:tool_arguments] = { "q" => "pagefly" }
      {}
    end

    call = McpLogs::Call.sole
    expect(call.tool_name).to eq("search_apps")
    expect(call.arguments).to eq("q" => "pagefly")
  end

  it "inserts a running row before the handler runs" do
    record({ method: "tools/call" }) do
      call = McpLogs::Call.sole
      expect(call).to be_running
      expect(call.completed_at).to be_nil
      {}
    end

    expect(McpLogs::Call.sole).not_to be_running
  end

  it "flags a tool-level failure without calling the request an error" do
    record({ method: "tools/call" }) { { content: [], isError: true } }

    call = McpLogs::Call.sole
    expect(call.status).to eq("ok")
    expect(call.tool_error).to be(true)
  end

  it "records a raised request as an error and re-raises it" do
    data = { method: "tools/call" }

    expect {
      record(data) do
        data[:error] = :internal_error
        raise ArgumentError, "bad news"
      end
    }.to raise_error(ArgumentError, "bad news")

    call = McpLogs::Call.sole
    expect(call.status).to eq("error")
    expect(call.error_type).to eq("internal_error")
    expect(call.error_message).to eq("ArgumentError: bad news")
  end

  it "caps an oversized error message and flags the call as truncated" do
    data = { method: "tools/call" }

    expect {
      record(data) { raise "x" * 5_000 }
    }.to raise_error(RuntimeError)

    call = McpLogs::Call.sole
    expect(call.error_message.bytesize).to eq(McpLogs::Recorder::ERROR_MESSAGE_BYTES)
    expect(call.truncated).to be(true)
  end

  it "records an error the server reported without raising" do
    data = { method: "tools/call" }
    record(data) do
      data[:error] = :tool_not_found
      {}
    end

    expect(McpLogs::Call.sole.status).to eq("error")
  end

  it "records a cancellation" do
    data = { method: "tools/call" }
    record(data) do
      data[:cancelled] = true
      {}
    end

    expect(McpLogs::Call.sole.cancelled).to be(true)
  end

  it "records client info once the client has introduced itself" do
    data = { method: "initialize" }
    record(data) do
      data[:client] = { name: "claude-code", version: "1.2.3" }
      {}
    end

    call = McpLogs::Call.sole
    expect(call.client_name).to eq("claude-code")
    expect(call.client_version).to eq("1.2.3")
  end

  it "stores the ambient request context" do
    McpLogs::Context.with(nil, actor: "curation-agent", session_id: "sess-1") do
      record({ method: "tools/list" }) { {} }
    end

    call = McpLogs::Call.sole
    expect(call.actor).to eq("curation-agent")
    expect(call.session_id).to eq("sess-1")
  end

  it "flags a call whose payload was capped" do
    McpLogs.max_payload_bytes = 100
    record({ method: "tools/call" }) { { "blob" => "x" * 5_000 } }

    expect(McpLogs::Call.sole.truncated).to be(true)
  end

  it "records nothing when logging is disabled, and still returns the result" do
    McpLogs.enabled = false

    expect(record({ method: "tools/call" }) { { ok: true } }).to eq(ok: true)
    expect(McpLogs::Call.count).to eq(0)
  end

  it "never lets a logging failure break the call" do
    allow(McpLogs::Call).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, "table gone")
    expect(Rails.error).to receive(:report).at_least(:once)

    expect(record({ method: "tools/call" }) { { ok: true } }).to eq(ok: true)
  end

  it "never lets a failure while finishing break the call" do
    allow_any_instance_of(McpLogs::Call).to receive(:update!).and_raise(ActiveRecord::StatementInvalid, "gone")
    expect(Rails.error).to receive(:report).at_least(:once)

    expect(record({ method: "tools/call" }) { { ok: true } }).to eq(ok: true)
  end

  # The two specs above stub create!/update! directly, so no statement ever
  # reaches PostgreSQL and no transaction is ever poisoned — they pin control
  # flow only. These provoke a real database error (division by zero, which
  # PostgreSQL rejects at the statement level) to prove the actual failure
  # mode the "never breaks the call" constraint is about: a failed statement
  # inside an open transaction leaves the connection aborted, so every query
  # after it fails too, unless the write runs in its own savepoint.
  it "keeps the enclosing transaction usable after a real database error while starting" do
    allow(McpLogs::Call).to receive(:create!) { McpLogs::Call.connection.execute("SELECT 1/0") }
    expect(Rails.error).to receive(:report).at_least(:once)

    expect(record({ method: "tools/call" }) { { ok: true } }).to eq(ok: true)
    expect { McpLogs::Call.count }.not_to raise_error
  end

  it "keeps the enclosing transaction usable after a real database error while finishing" do
    allow_any_instance_of(McpLogs::Call).to receive(:update!) { McpLogs::Call.connection.execute("SELECT 1/0") }
    expect(Rails.error).to receive(:report).at_least(:once)

    expect(record({ method: "tools/call" }) { { ok: true } }).to eq(ok: true)
    expect { McpLogs::Call.count }.not_to raise_error
  end
end
