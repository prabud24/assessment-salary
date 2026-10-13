class CreateUsersAndSalaryRecordAudit < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"

    add_reference :salary_records, :created_by, foreign_key: { to_table: :users, on_delete: :restrict }
    add_reference :salary_records, :closed_by, foreign_key: { to_table: :users, on_delete: :restrict }
    add_column :salary_records, :closed_at, :datetime
  end
end
