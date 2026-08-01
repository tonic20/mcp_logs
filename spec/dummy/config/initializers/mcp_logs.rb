# What the install generator writes into a host app, filled in for this dummy.
#
# base_controller_class has no default — McpLogs.base_controller raises without
# it — so the dummy sets it explicitly, exactly as a host must. ActionController::Base
# is the honest answer here: this app has no authentication to inherit, and the
# request specs want the pages reachable.
McpLogs.setup do |config|
  config.base_controller_class = "ActionController::Base"
end
