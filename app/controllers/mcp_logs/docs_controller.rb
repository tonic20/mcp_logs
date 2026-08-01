module McpLogs
  class DocsController < ApplicationController
    def show
      @server = McpLogs.server
      @sections = Docs.sections(@server)
      @counts = Call.tool_counts
    end
  end
end
