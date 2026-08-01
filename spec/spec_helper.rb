ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rspec/rails"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.include ActiveSupport::Testing::TimeHelpers
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Every spec starts from stock configuration plus whatever the dummy host's
  # initializer sets, so a spec that changes a setting cannot leak it into the
  # next file. The initializer is re-run rather than restated here: the dummy is
  # the gem's example of a configured host, and this keeps the two in step.
  config.before do
    McpLogs.reset_configuration!
    load Rails.root.join("config/initializers/mcp_logs.rb")
  end
end
