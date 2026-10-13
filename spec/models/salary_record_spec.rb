require "rails_helper"

RSpec.describe SalaryRecord, type: :model do
  let(:employee) do
    Employee.create!(
      employee_number: "EMP00001",
      name: "Asha Rao",
      email: "asha.rao@example.com",
      country_code: "IN",
      department: "Engineering"
    )
  end
  let(:user) { User.create!(email: "hr@example.com", password: "spec-password-2026") }

  def build_salary_record(overrides = {})
    SalaryRecord.new({
      employee: employee,
      annual_salary: "50000.000",
      currency: "USD",
      effective_from: Date.new(2026, 1, 1),
      created_by: user
    }.merge(overrides))
  end

  def insert_salary_record(overrides = {})
    attrs = {
      employee_id: employee.id,
      annual_salary: "50000.000",
      currency: "USD",
      effective_from: Date.new(2026, 1, 1),
      effective_to: nil
    }.merge(overrides)
    columns = attrs.keys.join(", ")
    values = attrs.values.map { |value| SalaryRecord.connection.quote(value) }.join(", ")
    SalaryRecord.connection.execute(
      "INSERT INTO salary_records (#{columns}, created_at, updated_at) VALUES (#{values}, NOW(), NOW())"
    )
  end

  describe "validity" do
    it "is valid with all required attributes" do
      expect(build_salary_record).to be_valid
    end

    it "belongs to an employee" do
      expect(build_salary_record.employee).to eq(employee)
    end

    it "requires an acting user when creating a salary record" do
      expect(build_salary_record(created_by: nil)).not_to be_valid
    end
  end

  describe "required attributes" do
    %i[employee annual_salary currency effective_from].each do |attribute|
      it "requires #{attribute}" do
        record = build_salary_record(attribute => nil)

        expect(record).not_to be_valid
        expect(record.errors[attribute]).to be_present
      end
    end
  end

  describe "annual_salary" do
    it "accepts the smallest positive value at the stored scale" do
      expect(build_salary_record(annual_salary: "0.001")).to be_valid
    end

    it "accepts values with trailing zeros beyond the stored scale" do
      expect(build_salary_record(annual_salary: "50000.0000")).to be_valid
    end

    it "accepts values exactly representable at the stored scale" do
      expect(build_salary_record(annual_salary: "50000.125")).to be_valid
    end

    it "accepts the largest value supported by the database precision" do
      record = build_salary_record(annual_salary: "9999999999999999.999")

      expect(record).to be_valid
      expect { record.save! }.to change(SalaryRecord, :count).by(1)
    end

    %w[0 -0.001].each do |amount|
      it "rejects #{amount}" do
        record = build_salary_record(annual_salary: amount)

        expect(record).not_to be_valid
        expect(record.errors[:annual_salary]).to be_present
      end
    end

    it "rejects values with more than three fractional digits" do
      record = build_salary_record(annual_salary: "50000.0001")

      expect(record).not_to be_valid
      expect(record.errors[:annual_salary]).to include("must be representable with no more than 3 decimal places")
    end

    it "rejects values above the database precision limit" do
      record = build_salary_record(annual_salary: "10000000000000000.000")

      expect(record).not_to be_valid
      expect(record.errors[:annual_salary]).to include("must be less than or equal to 9999999999999999.999")
    end
  end

  describe "currency" do
    it "trims whitespace and normalizes to uppercase" do
      expect(build_salary_record(currency: " usd ").currency).to eq("USD")
    end

    %w[US USDD U1D 123].each do |code|
      it "rejects #{code}" do
        record = build_salary_record(currency: code)

        expect(record).not_to be_valid
        expect(record.errors[:currency]).to be_present
      end
    end
  end

  describe "effective period" do
    it "accepts a null effective_to as an open-ended period" do
      expect(build_salary_record(effective_to: nil)).to be_valid
    end

    it "rejects an end date equal to the start date" do
      record = build_salary_record(effective_to: Date.new(2026, 1, 1))

      expect(record).not_to be_valid
      expect(record.errors[:effective_to]).to include("must be after effective_from")
    end

    it "rejects an end date before the start date" do
      record = build_salary_record(effective_to: Date.new(2025, 12, 31))

      expect(record).not_to be_valid
      expect(record.errors[:effective_to]).to include("must be after effective_from")
    end

    it "allows historical effective dates" do
      expect(build_salary_record(effective_from: Date.new(2000, 1, 1))).to be_valid
    end

    it "allows adjacent periods for the same employee" do
      SalaryRecord.create!(
        employee: employee,
        annual_salary: "50000",
        currency: "USD",
        effective_from: Date.new(2026, 1, 1),
        effective_to: Date.new(2026, 2, 1),
        created_by: user,
        closed_by: user,
        closed_at: Time.current
      )
      adjacent_record = build_salary_record(
        effective_from: Date.new(2026, 2, 1),
        created_by: user
      )

      expect(adjacent_record).to be_valid
      expect { adjacent_record.save! }.to change(SalaryRecord, :count).by(1)
    end

    it "requires actor and timestamp audit details when closing a record" do
      record = SalaryRecord.create!(
        employee: employee,
        annual_salary: "50000",
        currency: "USD",
        effective_from: Date.new(2026, 1, 1),
        created_by: user
      )

      record.effective_to = Date.new(2026, 2, 1)

      expect(record).not_to be_valid
      expect(record.errors[:closed_by]).to be_present
      expect(record.errors[:closed_at]).to be_present
    end
  end

  describe "database constraints" do
    it "accepts adjacent periods for the same employee via raw SQL" do
      expect {
        insert_salary_record(
          effective_from: Date.new(2026, 1, 1),
          effective_to: Date.new(2026, 2, 1)
        )
        insert_salary_record(
          effective_from: Date.new(2026, 2, 1),
          effective_to: Date.new(2026, 3, 1)
        )
      }.to change(SalaryRecord, :count).by(2)
    end

    it "accepts overlapping periods for different employees via raw SQL" do
      other_employee = Employee.create!(
        employee_number: "EMP00002",
        name: "Ravi Kumar",
        email: "ravi.kumar@example.com",
        country_code: "IN",
        department: "Engineering"
      )

      expect {
        insert_salary_record(
          effective_from: Date.new(2026, 1, 1),
          effective_to: Date.new(2026, 3, 1)
        )
        insert_salary_record(
          employee_id: other_employee.id,
          effective_from: Date.new(2026, 2, 1),
          effective_to: Date.new(2026, 4, 1)
        )
      }.to change(SalaryRecord, :count).by(2)
    end

    it "rejects an amount exceeding the database precision" do
      expect {
        insert_salary_record(annual_salary: "10000000000000000.000")
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects an overlapping period even when validations are bypassed" do
      insert_salary_record(effective_to: Date.new(2026, 3, 1))

      expect {
        insert_salary_record(
          effective_from: Date.new(2026, 2, 1),
          effective_to: Date.new(2026, 4, 1)
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /salary_records_no_overlapping_periods/)
    end

    it "rejects an overlapping open-ended period" do
      insert_salary_record(effective_from: Date.new(2026, 1, 1))

      expect {
        insert_salary_record(effective_from: Date.new(2026, 2, 1))
      }.to raise_error(ActiveRecord::StatementInvalid, /salary_records_no_overlapping_periods/)
    end

    it "rejects an open-ended period overlapping an existing finite period" do
      insert_salary_record(
        effective_from: Date.new(2026, 1, 1),
        effective_to: Date.new(2026, 3, 1)
      )

      expect {
        insert_salary_record(effective_from: Date.new(2026, 2, 1))
      }.to raise_error(ActiveRecord::StatementInvalid, /salary_records_no_overlapping_periods/)
    end
  end
end
