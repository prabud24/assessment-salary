class Employee < ApplicationRecord
  STATUSES = %w[active inactive].freeze
  EMPLOYEE_NUMBER_FORMAT = /\AEMP(?!00000\z)\d{5}\z/
  COUNTRY_CODE_FORMAT = /\A[A-Z]{2}\z/

  normalizes :employee_number, with: ->(value) { value.strip.upcase }
  normalizes :name, :department, with: ->(value) { value.strip }
  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :country_code, with: ->(value) { value.strip.upcase }

  validates :employee_number, :name, :email, :country_code, :department, presence: true
  validates :employee_number, format: { with: EMPLOYEE_NUMBER_FORMAT }, allow_blank: true
  validates :employee_number, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, uniqueness: { case_sensitive: false }
  validates :country_code, format: { with: COUNTRY_CODE_FORMAT }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
end
