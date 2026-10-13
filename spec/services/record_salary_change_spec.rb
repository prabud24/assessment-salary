require "rails_helper"

RSpec.describe RecordSalaryChange do
  let(:employee) do
    Employee.create!(
      employee_number: "EMP00001",
      name: "Asha Rao",
      email: "asha.rao@example.com",
      country_code: "IN",
      department: "Engineering"
    )
  end

  let(:business_date) { Date.new(2026, 1, 1) }
  let(:user) { User.create!(email: "hr@example.com", password: "spec-password-2026") }

  def record_salary_change(overrides = {})
    attributes = {
      employee: employee,
      annual_salary: "60000.000",
      currency: "USD",
      effective_from: Date.new(2026, 1, 1),
      business_date: business_date,
      user: user
    }.merge(overrides)

    described_class.new(**attributes).call
  end

  def create_salary_record(overrides = {})
    SalaryRecord.create!({
      employee: employee,
      annual_salary: "50000.000",
      currency: "USD",
      effective_from: Date.new(2025, 1, 1),
      effective_to: nil,
      created_by: user
    }.merge(overrides))
  end

  describe "#call" do
    it "requires an explicit business date" do
      expect {
        described_class.new(
          employee: employee,
          annual_salary: "60000",
          currency: "USD",
          effective_from: Date.new(2026, 1, 1),
          user: user
        )
      }.to raise_error(ArgumentError, /business_date/)
    end

    it "rejects a non-date business date" do
      result = record_salary_change(business_date: nil)

      expect(result).to be_failure
      expect(result.errors).to eq(business_date: [ "must be a Date" ])
    end

    it "creates the first salary record without closing a prior record" do
      result = nil

      expect {
        result = record_salary_change
      }.to change(SalaryRecord, :count).by(1)

      expect(result).to be_success
      expect(result.salary_record).to have_attributes(
        employee: employee,
        annual_salary: BigDecimal("60000"),
        currency: "USD",
        effective_from: business_date,
        effective_to: nil
      )
      expect(result.salary_record.created_by).to eq(user)
    end

    it "closes the open-ended record and creates the new open-ended record" do
      previous_record = create_salary_record
      effective_date = Date.new(2026, 3, 1)

      result = record_salary_change(effective_from: effective_date)

      expect(result).to be_success
      expect(previous_record.reload.effective_to).to eq(effective_date)
      expect(previous_record.closed_by).to eq(user)
      expect(previous_record.closed_at).to be_present
      expect(result.salary_record.effective_from).to eq(effective_date)
      expect(result.salary_record.effective_to).to be_nil
    end

    it "creates adjacent half-open periods when changing salary" do
      previous_record = create_salary_record(effective_to: nil)
      effective_date = Date.new(2026, 3, 1)

      result = record_salary_change(effective_from: effective_date)

      expect(result).to be_success
      expect(previous_record.reload.effective_to).to eq(result.salary_record.effective_from)
    end

    it "rejects an inactive employee without changing salary history" do
      employee.update!(status: "inactive")
      previous_record = create_salary_record

      result = record_salary_change

      expect(result).to be_failure
      expect(result.errors).to eq(employee: [ "must be active" ])
      expect(previous_record.reload.effective_to).to be_nil
      expect(SalaryRecord.count).to eq(1)
    end

    it "rejects a date before the business date" do
      result = record_salary_change(effective_from: Date.new(2025, 12, 31))

      expect(result).to be_failure
      expect(result.errors).to eq(effective_from: [ "must be on or after the business date" ])
      expect(SalaryRecord.count).to eq(0)
    end

    [ Date.new(2026, 2, 1), Date.new(2026, 1, 31) ].each do |effective_date|
      it "rejects an effective date not later than the latest record (#{effective_date})" do
        previous_record = create_salary_record(effective_from: Date.new(2026, 2, 1))

        result = record_salary_change(effective_from: effective_date)

        expect(result).to be_failure
        expect(result.errors).to eq(effective_from: [ "must be later than the latest salary record" ])
        expect(previous_record.reload.effective_to).to be_nil
        expect(SalaryRecord.count).to eq(1)
      end
    end

    it "returns SalaryRecord validation errors for invalid salary details" do
      result = record_salary_change(annual_salary: "0")

      expect(result).to be_failure
      expect(result.salary_record.errors[:annual_salary]).to be_present
      expect(result.errors[:annual_salary]).to eq(result.salary_record.errors[:annual_salary])
    end

    it "rolls back the closing update if closing the previous record fails" do
      previous_record = create_salary_record
      allow_any_instance_of(SalaryRecord).to receive(:update!).and_raise(ActiveRecord::RecordNotSaved, "close failed")

      expect {
        record_salary_change(effective_from: Date.new(2026, 3, 1))
      }.to raise_error(ActiveRecord::RecordNotSaved, "close failed")

      expect(previous_record.reload.effective_to).to be_nil
      expect(SalaryRecord.count).to eq(1)
    end

    it "rolls back closing the previous record if creating the new record fails" do
      previous_record = create_salary_record
      allow_any_instance_of(SalaryRecord).to receive(:save!).and_wrap_original do |original, *args|
        if original.receiver.new_record?
          raise ActiveRecord::RecordNotSaved, "create failed"
        end

        original.call(*args)
      end

      expect {
        record_salary_change(effective_from: Date.new(2026, 3, 1))
      }.to raise_error(ActiveRecord::RecordNotSaved, "create failed")

      expect(previous_record.reload.effective_to).to be_nil
      expect(SalaryRecord.count).to eq(1)
    end
  end
end
