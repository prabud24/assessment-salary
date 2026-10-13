require "rails_helper"

RSpec.describe "HR manager seed configuration" do
  around do |example|
    original_email = ENV.delete("HR_MANAGER_EMAIL")
    original_password = ENV.delete("HR_MANAGER_PASSWORD")
    example.run
  ensure
    ENV["HR_MANAGER_EMAIL"] = original_email if original_email
    ENV["HR_MANAGER_PASSWORD"] = original_password if original_password
  end

  it "fails clearly if either required environment variable is missing" do
    ENV["HR_MANAGER_EMAIL"] = "hr@example.com"

    expect { load Rails.root.join("db/seeds.rb") }
      .to raise_error(SystemExit) { |error| expect(error.message).to include("HR_MANAGER_EMAIL and HR_MANAGER_PASSWORD") }
  end

  it "creates synthetic employees and audited salary histories reproducibly" do
    ENV["HR_MANAGER_EMAIL"] = " HR@Example.com "
    ENV["HR_MANAGER_PASSWORD"] = "seed-password"

    expect { load Rails.root.join("db/seeds.rb") }
      .to change(User, :count).by(1)
      .and change(Employee, :count).by(10_000)
    user = User.find_by!(email: "hr@example.com")
    digest = user.password_digest
    employees = Employee.where(employee_number: "EMP00001".."EMP10000")
    employee_ids = employees.pluck(:id)
    records = SalaryRecord.where(employee_id: employee_ids)
    salary_record_count = records.count

    expect(user.authenticate("seed-password")).to eq(user)
    expect(digest).not_to eq("seed-password")
    expect(employees.count).to eq(10_000)
    expect(employees.distinct.count(:country_code)).to be >= 8
    expect(employees.distinct.count(:department)).to be >= 6
    expect(employees.distinct.count(:status)).to eq(2)
    expect(salary_record_count).to be > 10_000
    expect(records.where(created_by_id: nil).or(records.where.not(created_by_id: user.id))).not_to exist
    expect(records.distinct.count(:currency)).to be >= 8
    expect(SalaryRecord.where(employee_id: employee_ids, effective_to: nil).count).to eq(10_000)
    expect(records.where.not(effective_to: nil).where(closed_by_id: nil)).not_to exist
    expect(records.where.not(effective_to: nil).where(closed_at: nil)).not_to exist
    expect(
      records.where(<<~SQL.squish)
        EXISTS (
          SELECT 1
          FROM salary_records overlapping
          WHERE overlapping.employee_id = salary_records.employee_id
            AND overlapping.id <> salary_records.id
            AND daterange(overlapping.effective_from, overlapping.effective_to, '[)')
              && daterange(salary_records.effective_from, salary_records.effective_to, '[)')
        )
      SQL
    ).not_to exist

    expect { load Rails.root.join("db/seeds.rb") }
      .not_to change { [ User.count, employees.count, records.count ] }
    expect(records.count).to eq(salary_record_count)
  end
end
