ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rspec/rails"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Every spec starts from stock configuration; a spec that changes a setting
  # cannot leak it into the next file.
  config.before { McpLogs.reset_configuration! }
end
