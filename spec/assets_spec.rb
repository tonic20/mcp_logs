require "spec_helper"

# The dummy app uses Propshaft, which needs no manifest, so nothing else in this
# suite can notice the engine failing to declare its stylesheet. Under Sprockets
# an engine's asset is not precompiled unless it is declared here or added to
# the host's config.assets.precompile, and the failure surfaces only in
# production — assets:precompile succeeds, then every page 500s on
# Sprockets::Rails::Helper::AssetNotPrecompiledError.
RSpec.describe "the asset manifest" do
  it "declares every stylesheet the engine's layout asks for" do
    root = McpLogs::Engine.root
    manifest = root.join("app/assets/config/mcp_logs_manifest.js").read
    layout = root.join("app/views/layouts/mcp_logs/application.html.erb").read

    layout.scan(/stylesheet_link_tag ["']([\w\/-]+)["']/).flatten.each do |name|
      expect(manifest).to include("//= link #{name}.css")
      expect(root.join("app/assets/stylesheets/#{name}.css")).to exist
    end
  end
end
