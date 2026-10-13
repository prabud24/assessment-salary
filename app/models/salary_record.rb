class SalaryRecord < ApplicationRecord
  CURRENCY_FORMAT = /\A[A-Z]{3}\z/
  MAX_ANNUAL_SALARY = BigDecimal("9999999999999999.999")

  belongs_to :employee

  normalizes :currency, with: ->(value) { value.strip.upcase }

  validates :annual_salary, numericality: { greater_than: 0 }
  validate :annual_salary_fits_database_precision_and_scale
  validates :currency, presence: true, format: { with: CURRENCY_FORMAT }
  validates :effective_from, presence: true
  validate :effective_to_must_follow_effective_from

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
end
