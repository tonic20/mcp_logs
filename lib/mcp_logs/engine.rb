module McpLogs
  class Engine < ::Rails::Engine
    isolate_namespace McpLogs

    rake_tasks do
      load File.expand_path("../tasks/mcp_logs.rake", __dir__)
    end
  end
end
