class SalaryRecord < ApplicationRecord
  CURRENCY_FORMAT = /\A[A-Z]{3}\z/
  MAX_ANNUAL_SALARY = BigDecimal("9999999999999999.999")

  belongs_to :employee
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :closed_by, class_name: "User", optional: true

  normalizes :currency, with: ->(value) { value.strip.upcase }

  validates :annual_salary, numericality: { greater_than: 0 }
  validate :annual_salary_fits_database_precision_and_scale
  validates :created_by, presence: true, on: :create
  validates :currency, presence: true, format: { with: CURRENCY_FORMAT }
  validates :effective_from, presence: true
  validate :effective_to_must_follow_effective_from
  validate :closing_audit_details_must_be_present,
    if: -> { will_save_change_to_effective_to? && effective_to.present? }

  private

  def annual_salary_fits_database_precision_and_scale
    raw_annual_salary = annual_salary_before_type_cast
    return if raw_annual_salary.blank?

    amount = BigDecimal(raw_annual_salary.to_s)
    if amount.round(3) != amount
      errors.add(:annual_salary, "must be representable with no more than 3 decimal places")
    elsif amount.abs > MAX_ANNUAL_SALARY
      errors.add(:annual_salary, "must be less than or equal to #{MAX_ANNUAL_SALARY.to_s('F')}")
    end
  rescue ArgumentError
    # The numericality validation reports values that cannot be parsed.
  end

  def effective_to_must_follow_effective_from
    return if effective_to.blank? || effective_from.blank? || effective_to > effective_from

    errors.add(:effective_to, "must be after effective_from")
  end

  def closing_audit_details_must_be_present
    errors.add(:closed_by, :blank) if closed_by.nil?
    errors.add(:closed_at, :blank) if closed_at.nil?
  end
end
