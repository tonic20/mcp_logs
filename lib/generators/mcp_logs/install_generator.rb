module McpLogs
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    def copy_initializer
      template "initializer.rb", "config/initializers/mcp_logs.rb"
    end

    def mount_engine
      route 'mount McpLogs::Engine, at: "/mcp_logs"'
    end

    def copy_migrations
      rake "mcp_logs:install:migrations"
    end
  end
end
