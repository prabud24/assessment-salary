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

ActiveRecord::Schema[7.2].define(version: 2026_10_13_114930) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "plpgsql"

  create_table "employees", force: :cascade do |t|
    t.string "employee_number", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "country_code", limit: 2, null: false
    t.string "department", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_employees_on_lower_email", unique: true
    t.index ["country_code"], name: "index_employees_on_country_code"
    t.index ["department"], name: "index_employees_on_department"
    t.index ["employee_number"], name: "index_employees_on_employee_number", unique: true
    t.check_constraint "country_code::text ~ '^[A-Z]{2}$'::text", name: "employees_country_code_format"
    t.check_constraint "employee_number::text ~ '^EMP[0-9]{5}$'::text AND employee_number::text <> 'EMP00000'::text", name: "employees_employee_number_format"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "employees_status_allowed"
  end

  create_table "salary_records", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.decimal "annual_salary", precision: 19, scale: 3, null: false
    t.string "currency", limit: 3, null: false
    t.date "effective_from", null: false
    t.date "effective_to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_from"], name: "index_salary_records_on_employee_id_and_effective_from"
    t.index ["employee_id"], name: "index_salary_records_on_employee_id"
    t.index ["employee_id"], name: "index_salary_records_on_employee_id_open_ended", unique: true, where: "(effective_to IS NULL)"
    t.check_constraint "annual_salary > 0::numeric", name: "salary_records_annual_salary_positive"
    t.check_constraint "currency::text ~ '^[A-Z]{3}$'::text", name: "salary_records_currency_format"
    t.check_constraint "effective_to IS NULL OR effective_to > effective_from", name: "salary_records_effective_period_valid"
    t.exclusion_constraint "employee_id WITH =, daterange(effective_from, effective_to, '[)'::text) WITH &&", using: :gist, name: "salary_records_no_overlapping_periods"
  end

  add_foreign_key "salary_records", "employees", on_delete: :restrict
end
