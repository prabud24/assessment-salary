class CreateSalaryRecords < ActiveRecord::Migration[7.2]
  def change
    enable_extension "btree_gist"

    create_table :salary_records do |t|
      t.references :employee, null: false, foreign_key: { on_delete: :restrict }
      t.decimal :annual_salary, precision: 19, scale: 3, null: false
      t.string :currency, limit: 3, null: false
      t.date :effective_from, null: false
      t.date :effective_to

      t.timestamps
    end

    add_index :salary_records, %i[employee_id effective_from]
    add_index :salary_records, :employee_id,
      unique: true,
      where: "effective_to IS NULL",
      name: "index_salary_records_on_employee_id_open_ended"

    add_check_constraint :salary_records,
      "annual_salary > 0",
      name: "salary_records_annual_salary_positive"
    add_check_constraint :salary_records,
      "currency ~ '^[A-Z]{3}$'",
      name: "salary_records_currency_format"
    add_check_constraint :salary_records,
      "effective_to IS NULL OR effective_to > effective_from",
      name: "salary_records_effective_period_valid"

    add_exclusion_constraint :salary_records,
      "employee_id WITH =, daterange(effective_from, effective_to, '[)') WITH &&",
      using: :gist,
      name: "salary_records_no_overlapping_periods"
  end
end
