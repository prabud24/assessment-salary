class RecordSalaryChange
  Result = Struct.new(:success, :salary_record, :errors, keyword_init: true) do
    def success?
      success
    end

    def failure?
      !success?
    end
  end

  def initialize(employee:, annual_salary:, currency:, effective_from:, business_date:, user:)
    @employee = employee
    @annual_salary = annual_salary
    @currency = currency
    @effective_from = effective_from
    @business_date = business_date
    @user = user
  end

  def call
    return failure(business_date: [ "must be a Date" ]) unless @business_date.is_a?(Date)

    @employee.with_lock do
      next failure(employee: [ "must be active" ]) unless @employee.status == "active"

      salary_record = SalaryRecord.new(
        employee: @employee,
        annual_salary: @annual_salary,
        currency: @currency,
        effective_from: @effective_from,
        effective_to: nil,
        created_by: @user
      )

      unless salary_record.effective_from
        salary_record.valid?
        next failure(salary_record.errors.to_hash, salary_record:)
      end

      if salary_record.effective_from < @business_date
        next failure(effective_from: [ "must be on or after the business date" ])
      end

      latest_record = SalaryRecord.where(employee_id: @employee.id)
        .order(effective_from: :desc, id: :desc)
        .first
      if latest_record && salary_record.effective_from <= latest_record.effective_from
        next failure(effective_from: [ "must be later than the latest salary record" ])
      end

      unless salary_record.valid?
        next failure(salary_record.errors.to_hash, salary_record:)
      end

      open_record = SalaryRecord.find_by(employee_id: @employee.id, effective_to: nil)
      if open_record
        open_record.update!(
          effective_to: salary_record.effective_from,
          closed_by: @user,
          closed_at: Time.current
        )
      end
      salary_record.save!

      success(salary_record)
    end
  rescue ActiveRecord::RecordInvalid => error
    failure(error.record.errors.to_hash, salary_record: error.record)
  end

  private

  def success(salary_record)
    Result.new(success: true, salary_record:, errors: {})
  end

  def failure(errors = nil, salary_record: nil, **field_errors)
    errors ||= field_errors
    Result.new(success: false, salary_record:, errors:)
  end
end
