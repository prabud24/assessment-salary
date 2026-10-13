require "set"

module SyntheticSeedData
  EMPLOYEE_COUNT = 10_000
  BATCH_SIZE = 1_000
  ADVISORY_LOCK_KEY = 47_281_639
  SEED_TIMESTAMP = Time.utc(2026, 10, 1, 12)

  FIRST_NAMES = %w[
    Aadhya Aaron Abigail Adam Aisha Alex Amara Amelia Anand Aria Arjun Ava
    Benjamin Chloe Daniel Elena Ethan Fatima Gabriel Hana Isaac James Leila
    Liam Maya Mateo Naomi Noah Olivia Priya Rahul Sofia
  ].freeze
  LAST_NAMES = %w[
    Adams Ahmed Baker Brown Chen Clarke Davis Diaz Fischer Garcia Gupta
    Harris Ivanov Johnson Khan Kim Kumar Lee Martin Miller Patel Roberts
    Schmidt Shah Singh Taylor Thomas Wilson Wong
  ].freeze
  DEPARTMENTS = %w[
    Engineering Finance Human\ Resources Marketing Operations Product
    Sales Customer\ Support Legal
  ].freeze

  COUNTRIES = {
    "AU" => { currency: "AUD", minimum: 65_000, maximum: 220_000 },
    "CA" => { currency: "CAD", minimum: 60_000, maximum: 210_000 },
    "CH" => { currency: "CHF", minimum: 85_000, maximum: 250_000 },
    "DE" => { currency: "EUR", minimum: 48_000, maximum: 190_000 },
    "FR" => { currency: "EUR", minimum: 42_000, maximum: 175_000 },
    "GB" => { currency: "GBP", minimum: 42_000, maximum: 185_000 },
    "IN" => { currency: "INR", minimum: 600_000, maximum: 4_000_000 },
    "JP" => { currency: "JPY", minimum: 5_000_000, maximum: 20_000_000 },
    "SG" => { currency: "SGD", minimum: 60_000, maximum: 230_000 },
    "US" => { currency: "USD", minimum: 55_000, maximum: 250_000 }
  }.freeze

  CURRENCIES = COUNTRIES.values.map { |country| country[:currency] }.uniq.freeze
  CURRENCY_SALARY_RANGES = {
    "AUD" => [ 65_000, 220_000 ],
    "CAD" => [ 60_000, 210_000 ],
    "CHF" => [ 85_000, 250_000 ],
    "EUR" => [ 42_000, 190_000 ],
    "GBP" => [ 42_000, 185_000 ],
    "INR" => [ 600_000, 4_000_000 ],
    "JPY" => [ 5_000_000, 20_000_000 ],
    "SGD" => [ 60_000, 230_000 ],
    "USD" => [ 55_000, 250_000 ]
  }.freeze
  YEARS = (2018..2025).to_a.freeze

  module_function

  def employee_number(number)
    format("EMP%05d", number)
  end

  def employee_rows
    (1..EMPLOYEE_COUNT).map do |number|
      random = Random.new(number)
      country_code = COUNTRIES.keys[(number - 1) % COUNTRIES.size]
      {
        employee_number: employee_number(number),
        name: "#{FIRST_NAMES[random.rand(FIRST_NAMES.size)]} #{LAST_NAMES[random.rand(LAST_NAMES.size)]}",
        email: format("employee%05d@example.test", number),
        country_code: country_code,
        department: DEPARTMENTS[random.rand(DEPARTMENTS.size)],
        status: random.rand(10).zero? ? "inactive" : "active",
        created_at: SEED_TIMESTAMP,
        updated_at: SEED_TIMESTAMP
      }
    end
  end

  def salary_rows(employee_id:, employee_number:, country_code:, existing_dates:, created_by_id:)
    number = employee_number.delete_prefix("EMP").to_i
    random = Random.new(number * 7_919)
    country = COUNTRIES.fetch(country_code)
    salary_count = random.rand(1..5)
    years = YEARS.sample(salary_count, random:).sort
    currency = country.fetch(:currency)
    salary = random.rand(country.fetch(:minimum)..country.fetch(:maximum))

    periods = years.each_with_index.map do |year, index|
      effective_from = Date.new(year, random.rand(1..12), 1)
      next_currency = if index.positive? && random.rand(10).zero?
        CURRENCIES.reject { |code| code == currency }.sample(random:)
      else
        currency
      end

      if next_currency != currency
        currency = next_currency
        minimum, maximum = CURRENCY_SALARY_RANGES.fetch(currency)
        salary = random.rand(minimum..maximum)
      elsif index.positive?
        salary = (salary * (100 + random.rand(4..14)) + 50) / 100
      end

      [ effective_from, salary, currency ]
    end

    periods.each_with_index.filter_map do |(effective_from, annual_salary, record_currency), index|
      next if existing_dates.include?(effective_from)

      effective_to = periods[index + 1]&.first
      {
        employee_id: employee_id,
        annual_salary: annual_salary,
        currency: record_currency,
        effective_from: effective_from,
        effective_to: effective_to,
        created_by_id: created_by_id,
        closed_by_id: effective_to ? created_by_id : nil,
        closed_at: effective_to ? SEED_TIMESTAMP : nil,
        created_at: SEED_TIMESTAMP,
        updated_at: SEED_TIMESTAMP
      }
    end
  end

  def run!(email:, password:)
    Employee.transaction do
      connection = ActiveRecord::Base.connection
      connection.execute("SELECT pg_advisory_xact_lock(#{ADVISORY_LOCK_KEY})")

      user = User.find_or_initialize_by(email: email)
      user.password = password
      user.save!

      rows = employee_rows
      rows.each_slice(BATCH_SIZE) do |batch|
        Employee.insert_all(batch, unique_by: :index_employees_on_employee_number)
      end

      employee_ids = Employee.where(employee_number: employee_number(1)..employee_number(EMPLOYEE_COUNT))
        .pluck(:employee_number, :id)
        .to_h
      existing_dates = SalaryRecord.where(employee_id: employee_ids.values)
        .pluck(:employee_id, :effective_from)
        .each_with_object(Hash.new { |dates, id| dates[id] = Set.new }) do |(employee_id, date), dates|
          dates[employee_id] << date
        end

      salary_batches = []
      rows.each do |row|
        number = row.fetch(:employee_number)
        employee_id = employee_ids.fetch(number)
        salary_batches.concat(
          salary_rows(
            employee_id: employee_id,
            employee_number: number,
            country_code: row.fetch(:country_code),
            existing_dates: existing_dates[employee_id],
            created_by_id: user.id
          )
        )
      end

      salary_batches.each_slice(BATCH_SIZE) { |batch| SalaryRecord.insert_all!(batch) }
    end
  end
end
