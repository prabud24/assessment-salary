class User < ApplicationRecord
  has_secure_password

  normalizes :email, with: ->(value) { value.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
end
