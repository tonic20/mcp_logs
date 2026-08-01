# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 1) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "mcp_logs_calls", force: :cascade do |t|
    t.string "actor", limit: 255
    t.jsonb "arguments"
    t.boolean "arguments_truncated", default: false, null: false
    t.boolean "cancelled", default: false, null: false
    t.string "client_name", limit: 255
    t.string "client_version", limit: 255
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.float "duration_ms"
    t.text "error_message"
    t.boolean "error_message_truncated", default: false, null: false
    t.string "error_type"
    t.string "ip", limit: 255
    t.string "protocol_version", limit: 255
    t.jsonb "response"
    t.boolean "response_truncated", default: false, null: false
    t.string "rpc_method", null: false
    t.string "server_name"
    t.string "session_id", limit: 255
    t.datetime "started_at", null: false
    t.string "status", default: "running", null: false
    t.boolean "tool_error", default: false, null: false
    t.string "tool_name", limit: 255
    t.datetime "updated_at", null: false
    t.string "user_agent", limit: 255
    t.index ["rpc_method"], name: "index_mcp_logs_calls_on_rpc_method"
    t.index ["session_id"], name: "index_mcp_logs_calls_on_session_id"
    t.index ["started_at"], name: "index_mcp_logs_calls_on_started_at"
    t.index ["status"], name: "index_mcp_logs_calls_on_status"
    t.index ["tool_name"], name: "index_mcp_logs_calls_on_tool_name"
  end
end
