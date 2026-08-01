require_relative "lib/mcp_logs/version"

Gem::Specification.new do |spec|
  spec.name        = "mcp_logs"
  spec.version     = McpLogs::VERSION
  spec.authors     = ["Anton"]
  spec.summary     = "Rails engine for MCP request logging and tool documentation"
  spec.description = "Mountable Rails engine that records every Model Context Protocol " \
                     "request a Rails app serves and renders its tool contract as documentation."
  spec.homepage    = "https://github.com/tonic20/mcp_logs"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md", "LICENSE.txt"]
  end

  spec.add_dependency "rails", "~> 8.0"
  spec.add_dependency "pagy", ">= 43.0"

  # mcp is a development dependency on purpose: the engine must install and
  # render in an app that does not serve MCP. Capture is wired by the host.
  spec.add_development_dependency "mcp", "~> 1.0"
end
