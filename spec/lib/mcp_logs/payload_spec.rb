require "spec_helper"

RSpec.describe McpLogs::Payload do
  before { described_class.reset! }

  it "passes a small hash through untouched" do
    expect(described_class.prepare({ "domain" => "shop.example" }))
      .to eq([{ "domain" => "shop.example" }, false])
  end

  it "returns nil for a nil payload" do
    expect(described_class.prepare(nil)).to eq([nil, false])
  end

  it "records nothing when payloads are turned off" do
    McpLogs.record_payloads = false

    expect(described_class.prepare({ "domain" => "shop.example" })).to eq([nil, false])
  end

  it "applies the host's filter_parameters" do
    # The dummy app filters :token — see spec/dummy/config/application.rb.
    prepared, = described_class.prepare({ "token" => "s3cret", "domain" => "shop.example" })

    expect(prepared["token"]).to eq("[FILTERED]")
    expect(prepared["domain"]).to eq("shop.example")
  end

  it "applies the configured payload_filter after filter_parameters" do
    McpLogs.payload_filter = ->(payload) { payload.except("domain") }

    prepared, = described_class.prepare({ "token" => "s3cret", "domain" => "shop.example" })

    expect(prepared).to eq("token" => "[FILTERED]")
  end

  it "caps an oversized payload and flags it" do
    McpLogs.max_payload_bytes = 200
    prepared, truncated = described_class.prepare({ "blob" => "x" * 5_000 })

    expect(truncated).to be(true)
    expect(prepared["truncated"]).to be(true)
    expect(prepared["bytes"]).to be > 200
    expect(prepared["preview"].bytesize).to be <= 200
  end

  it "does not leave invalid UTF-8 behind when it cuts mid-character" do
    McpLogs.max_payload_bytes = 20
    prepared, = described_class.prepare({ "blob" => "é" * 100 })

    expect(prepared["preview"]).to be_valid_encoding
  end

  it "wraps a non-hash payload so it can still be filtered and stored" do
    expect(described_class.prepare("plain string")).to eq([{ "value" => "plain string" }, false])
  end
end
