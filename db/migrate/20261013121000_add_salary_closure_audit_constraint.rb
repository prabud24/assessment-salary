class AddSalaryClosureAuditConstraint < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :salary_records,
      "(closed_by_id IS NULL) = (closed_at IS NULL)",
      name: "salary_records_closure_audit_consistent"
  end
end
