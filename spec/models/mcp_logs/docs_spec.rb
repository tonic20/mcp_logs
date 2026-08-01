require "spec_helper"
require_relative "../../support/fake_tools"

RSpec.describe McpLogs::Docs do
  let(:server) { FakeTools.server }

  it "groups tools into the configured sections, in configured order" do
    sections = described_class.sections(server, { "Second" => %w[refuse], "First" => %w[echo] })

    expect(sections.map(&:title)).to eq(["Second", "First", "Ungrouped"])
    expect(sections.first.tools.map(&:name)).to eq(["refuse"])
  end

  it "puts an unlisted tool under Ungrouped rather than dropping it" do
    sections = described_class.sections(server, { "First" => %w[echo] })

    expect(sections.last.title).to eq("Ungrouped")
    expect(sections.last.tools.map(&:name)).to contain_exactly("refuse", "explode")
  end

  it "omits a section whose tools are not registered" do
    sections = described_class.sections(server, { "First" => %w[echo], "Gone" => %w[missing] })

    expect(sections.map(&:title)).to eq(["First", "Ungrouped"])
  end

  it "renders every tool in one flat section when nothing is configured" do
    sections = described_class.sections(server, {})

    expect(sections.map(&:title)).to eq(["Ungrouped"])
    expect(sections.first.tools.size).to eq(3)
  end

  it "flattens parameters out of the input schema with types and required flags" do
    tool = described_class.sections(server, {}).flat_map(&:tools).find { |t| t.name == "echo" }

    expect(tool.params.map(&:name)).to eq(["text"])
    expect(tool.params.first.type).to eq("string")
    expect(tool.params.first.required).to be(true)
  end

  it "yields no params for a tool with no properties" do
    tool = described_class.sections(server, {}).flat_map(&:tools).find { |t| t.name == "refuse" }

    expect(tool.params).to eq([])
  end

  it "strips a heredoc description's trailing newline" do
    tool = described_class.sections(server, {}).flat_map(&:tools).find { |t| t.name == "echo" }

    expect(tool.description).not_to end_with("\n")
  end

  it "folds enum values and array item types into the type label" do
    schema = {
      properties: {
        reason: { type: "string", enum: %w[dead first_party] },
        urls: { type: "array", items: { type: "string" } }
      },
      required: ["reason"]
    }

    params = described_class.params(schema)

    expect(params.map(&:type)).to eq(["string (dead | first_party)", "array of string"])
    expect(params.map(&:required)).to eq([true, false])
  end

  it "returns no sections when no server is configured" do
    expect(described_class.sections(nil)).to eq([])
  end
end
