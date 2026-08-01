require "mcp"

# A miniature version of a host's tool set: one that succeeds, one that returns a
# tool-level failure, and one that raises. Specs run against a real MCP::Server
# built from these, so the capture path is exercised through the gem's own
# plumbing rather than a hand-rolled imitation of it.
module FakeTools
  class Echo < MCP::Tool
    tool_name "echo"
    description "Echoes its input back."
    input_schema({ type: "object", properties: { text: { type: "string" } }, required: ["text"] })

    def self.call(text:, server_context: nil)
      MCP::Tool::Response.new([{ type: "text", text: text }], structured_content: { "text" => text })
    end
  end

  class Refuse < MCP::Tool
    tool_name "refuse"
    description "Always returns a tool-level failure."
    input_schema({ type: "object", properties: {}, required: [] })

    def self.call(server_context: nil)
      MCP::Tool::Response.new([{ type: "text", text: "no" }], error: true)
    end
  end

  class Explode < MCP::Tool
    tool_name "explode"
    description "Always raises."
    input_schema({ type: "object", properties: {}, required: [] })

    def self.call(server_context: nil)
      raise "kaboom"
    end
  end

  TOOLS = [Echo, Refuse, Explode].freeze

  def self.server(server_name: "fake")
    MCP::Server.new(
      name: server_name,
      version: "1.0.0",
      instructions: "A fake server for specs.",
      tools: TOOLS,
      capabilities: { tools: {} },
      configuration: MCP::Configuration.new(
        around_request: McpLogs.around_request(server_name: server_name),
        exception_reporter: ->(_exception, _context) {}
      )
    )
  end
end
