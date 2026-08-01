class CreateMcpLogsCalls < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_logs_calls do |t|
      t.string  :server_name
      # Named rpc_method, not method: an ActiveRecord attribute called `method`
      # shadows Object#method on every instance of this class.
      t.string  :rpc_method, null: false
      t.string  :tool_name
      t.jsonb   :arguments
      t.jsonb   :response
      t.string  :status, null: false, default: "running"
      t.boolean :tool_error, null: false, default: false
      t.boolean :cancelled, null: false, default: false
      t.string  :error_type
      t.text    :error_message
      t.float   :duration_ms
      t.string  :client_name
      t.string  :client_version
      t.string  :protocol_version
      t.string  :session_id
      t.string  :actor
      t.string  :ip
      t.string  :user_agent
      # One flag per capped payload, not a single OR'd column: each of these is
      # set independently, so the detail page can say which payload was capped
      # instead of pointing at whichever one happened to render nearby.
      t.boolean :arguments_truncated, null: false, default: false
      t.boolean :response_truncated, null: false, default: false
      t.boolean :error_message_truncated, null: false, default: false
      t.datetime :started_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :mcp_logs_calls, :started_at
    add_index :mcp_logs_calls, :rpc_method
    add_index :mcp_logs_calls, :tool_name
    add_index :mcp_logs_calls, :status
    add_index :mcp_logs_calls, :session_id
  end
end
