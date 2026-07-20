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

ActiveRecord::Schema[8.1].define(version: 2026_07_19_160000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "last4", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id"], name: "index_api_keys_on_organization_id"
    t.index ["token_digest"], name: "index_api_keys_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "item_id", null: false
    t.string "source", default: "web", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["item_id"], name: "index_comments_on_item_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "comparisons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "item_a_id", null: false
    t.bigint "item_b_id", null: false
    t.string "outcome", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index "LEAST(item_a_id, item_b_id), GREATEST(item_a_id, item_b_id)", name: "index_comparisons_on_unordered_pair", unique: true
    t.index ["item_a_id"], name: "index_comparisons_on_item_a_id"
    t.index ["item_b_id"], name: "index_comparisons_on_item_b_id"
    t.index ["user_id"], name: "index_comparisons_on_user_id"
  end

  create_table "credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "nickname"
    t.text "public_key", null: false
    t.integer "sign_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["external_id"], name: "index_credentials_on_external_id", unique: true
    t.index ["user_id"], name: "index_credentials_on_user_id"
  end

  create_table "item_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.bigint "source_id", null: false
    t.bigint "target_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id", "target_id", "kind"], name: "index_item_links_on_source_id_and_target_id_and_kind", unique: true
    t.index ["source_id"], name: "index_item_links_on_source_id"
    t.index ["target_id"], name: "index_item_links_on_target_id"
  end

  create_table "item_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "item_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id", "tag_id"], name: "index_item_tags_on_item_id_and_tag_id", unique: true
    t.index ["item_id"], name: "index_item_tags_on_item_id"
    t.index ["tag_id"], name: "index_item_tags_on_tag_id"
  end

  create_table "item_types", force: :cascade do |t|
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index "organization_id, lower((name)::text)", name: "index_item_types_on_organization_id_and_lower_name", unique: true
    t.index ["organization_id"], name: "index_item_types_on_organization_id"
  end

  create_table "items", force: :cascade do |t|
    t.datetime "ai_reviewed_at"
    t.datetime "created_at", null: false
    t.string "item_type", default: "feature", null: false
    t.integer "number", null: false
    t.bigint "parent_id"
    t.integer "points"
    t.bigint "project_id", null: false
    t.text "review_note"
    t.datetime "review_requested_at"
    t.string "source", default: "web", null: false
    t.bigint "status_id", null: false
    t.float "strength", default: 0.0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_items_on_parent_id"
    t.index ["project_id", "number"], name: "index_items_on_project_id_and_number", unique: true
    t.index ["project_id"], name: "index_items_on_project_id"
    t.index ["review_requested_at"], name: "index_items_on_review_requested_at", where: "(review_requested_at IS NOT NULL)"
    t.index ["status_id"], name: "index_items_on_status_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "owner", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "project_slug_aliases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.bigint "project_id", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index "organization_id, lower((slug)::text)", name: "index_project_slug_aliases_on_org_and_lower_slug", unique: true
    t.index ["organization_id"], name: "index_project_slug_aliases_on_organization_id"
    t.index ["project_id"], name: "index_project_slug_aliases_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "last_item_number", default: 0, null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "slug"], name: "index_projects_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_projects_on_organization_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "statuses", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_statuses_on_organization_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.citext "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_tags_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_tags_on_organization_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "default_organization_id"
    t.string "email"
    t.datetime "email_verified_at"
    t.datetime "updated_at", null: false
    t.citext "username", null: false
    t.string "webauthn_id", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["default_organization_id"], name: "index_users_on_default_organization_id"
    t.index ["username"], name: "index_users_on_username", unique: true
    t.index ["webauthn_id"], name: "index_users_on_webauthn_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_keys", "organizations"
  add_foreign_key "api_keys", "users"
  add_foreign_key "comments", "items"
  add_foreign_key "comments", "users"
  add_foreign_key "comparisons", "items", column: "item_a_id"
  add_foreign_key "comparisons", "items", column: "item_b_id"
  add_foreign_key "comparisons", "users"
  add_foreign_key "credentials", "users"
  add_foreign_key "item_links", "items", column: "source_id"
  add_foreign_key "item_links", "items", column: "target_id"
  add_foreign_key "item_tags", "items"
  add_foreign_key "item_tags", "tags"
  add_foreign_key "item_types", "organizations"
  add_foreign_key "items", "items", column: "parent_id"
  add_foreign_key "items", "projects"
  add_foreign_key "items", "statuses"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "project_slug_aliases", "organizations"
  add_foreign_key "project_slug_aliases", "projects"
  add_foreign_key "projects", "organizations"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "statuses", "organizations"
  add_foreign_key "tags", "organizations"
  add_foreign_key "users", "organizations", column: "default_organization_id"
end
