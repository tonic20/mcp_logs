module McpLogs
  class CallsController < ApplicationController
    include Pagy::Method

    def index
      scope = Call.recent
        .for_method(params[:method])
        .for_tool(params[:tool])
        .with_status(params[:status])
        .for_session(params[:session])

      @pagy, @calls = pagy(:offset, scope, limit: McpLogs.page_size)

      # The filter dropdowns list what has actually been logged, so they can never
      # offer a method or tool that would return an empty page.
      @methods = filter_options(:rpc_method, params[:method])
      @tools = filter_options(:tool_name, params[:tool])
    end

    def show
      @call = Call.find(params[:id])
    end

    private

    # Bounded by Call::FILTER_OPTIONS_LIMIT, with the active filter added back if
    # the bound cut it — otherwise filtering by a tool past the cut would drop
    # that tool out of the select, silently resetting it to "Any" on submit.
    def filter_options(column, selected)
      values = Call.filter_values(column)
      selected.present? ? (values | [selected]).sort : values
    end
  end
end
