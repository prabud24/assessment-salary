require_relative "seeds/synthetic_seed_data"

email = ENV["HR_MANAGER_EMAIL"]
password = ENV["HR_MANAGER_PASSWORD"]
abort("Set HR_MANAGER_EMAIL and HR_MANAGER_PASSWORD before running db:seed") if email.blank? || password.blank?

SyntheticSeedData.run!(email:, password:)
