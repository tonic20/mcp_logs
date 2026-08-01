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
      @methods = Call.distinct.order(:rpc_method).pluck(:rpc_method)
      @tools = Call.where.not(tool_name: nil).distinct.order(:tool_name).pluck(:tool_name)
    end

    def show
      @call = Call.find(params[:id])
    end
  end
end
