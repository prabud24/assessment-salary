require "rails_helper"

RSpec.describe "Insights API", type: :request do
  let(:business_date) { Date.new(2026, 10, 13) }

  before do
    allow(SalaryInsights).to receive(:current_business_date).and_return(business_date)
  end

  def create_employee(number:, country: "IN", department: "Engineering", status: "active")
    Employee.create!(
      employee_number: "EMP#{format('%05d', number)}",
      name: "Employee #{number}",
      email: "employee#{number}@example.com",
      country_code: country,
      department: department,
      status: status
    )
  end

  def create_salary(employee, amount:, currency: "USD", from:, to: nil)
    previous_open_record = SalaryRecord.find_by(employee_id: employee.id, effective_to: nil)
    previous_open_record&.update!(effective_to: from)

    SalaryRecord.create!(
      employee: employee,
      annual_salary: amount,
      currency: currency,
      effective_from: from,
      effective_to: to
    )
  end

  describe "GET /api/v1/insights/average_salary_by_country" do
    it "groups current active salaries by country and currency without combining currencies" do
      india_usd = create_employee(number: 1, country: "IN")
      india_eur = create_employee(number: 2, country: "IN")
      us_usd = create_employee(number: 3, country: "US", department: "Sales")
      inactive = create_employee(number: 4, country: "IN", status: "inactive")
      no_current = create_employee(number: 5, country: "IN")

      create_salary(india_usd, amount: "100.000", from: business_date - 1.day)
      create_salary(india_eur, amount: "200.000", currency: "EUR", from: business_date - 1.day)
      create_salary(us_usd, amount: "300.000", from: business_date)
      create_salary(inactive, amount: "999.000", from: business_date - 1.day)
      create_salary(no_current, amount: "400.000", from: business_date - 1.day, to: business_date)

      get "/api/v1/insights/average_salary_by_country"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("results")).to eq(
        [
          { "country" => "IN", "currency" => "EUR", "average_salary" => "200.0", "employee_count" => 1 },
          { "country" => "IN", "currency" => "USD", "average_salary" => "100.0", "employee_count" => 1 },
          { "country" => "US", "currency" => "USD", "average_salary" => "300.0", "employee_count" => 1 }
        ]
      )
      expect(response.body).not_to match(/"average_salary"\s*:\s*\d/)
    end

    it "returns an empty results array when no employees have a current salary" do
      get "/api/v1/insights/average_salary_by_country"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("results" => [])
    end
  end

  describe "GET /api/v1/insights/total_salary_by_department" do
    it "aggregates by current department and currency, excluding inactive and unsalaried employees" do
      first_engineer = create_employee(number: 1)
      second_engineer = create_employee(number: 2)
      finance = create_employee(number: 3, department: "Finance")
      inactive = create_employee(number: 4, status: "inactive")
      no_salary = create_employee(number: 5)

      create_salary(first_engineer, amount: "100.125", from: business_date - 1.day)
      create_salary(second_engineer, amount: "200.250", from: business_date - 1.day)
      create_salary(finance, amount: "300.000", currency: "EUR", from: business_date - 1.day)
      create_salary(inactive, amount: "999.000", from: business_date - 1.day)

      get "/api/v1/insights/total_salary_by_department"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("results")).to eq(
        [
          { "department" => "Engineering", "currency" => "USD", "total_salary" => "300.375", "employee_count" => 2 },
          { "department" => "Finance", "currency" => "EUR", "total_salary" => "300.0", "employee_count" => 1 }
        ]
      )
      expect(SalaryRecord.where(employee: no_salary)).to be_empty
    end

    it "returns an empty results array when no employees have a current salary" do
      get "/api/v1/insights/total_salary_by_department"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("results" => [])
    end
  end

  describe "GET /api/v1/insights/salary_increases" do
    it "counts each same-currency increase event in the start-inclusive end-exclusive range" do
      employee = create_employee(number: 1)
      inactive = create_employee(number: 2, status: "inactive")
      create_salary(employee, amount: "100.000", from: Date.new(2026, 1, 1))
      create_salary(employee, amount: "120.000", from: Date.new(2026, 2, 1))
      create_salary(employee, amount: "110.000", from: Date.new(2026, 3, 1))
      create_salary(employee, amount: "130.000", from: Date.new(2026, 4, 1))
      create_salary(inactive, amount: "100.000", from: Date.new(2026, 2, 1))
      create_salary(inactive, amount: "150.000", from: Date.new(2026, 3, 1))
      create_salary(inactive, amount: "160.000", from: Date.new(2026, 4, 1))

      get "/api/v1/insights/salary_increases", params: {
        start: "2026-02-01",
        end: "2026-04-01"
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "results" => [ { "currency" => "USD", "increase_count" => 2 } ]
      )
    end

    it "counts multiple increases from one employee as separate events" do
      employee = create_employee(number: 1)
      create_salary(employee, amount: "100.000", from: Date.new(2026, 1, 1))
      create_salary(employee, amount: "120.000", from: Date.new(2026, 2, 1))
      create_salary(employee, amount: "140.000", from: Date.new(2026, 3, 1))

      get "/api/v1/insights/salary_increases", params: {
        start: "2026-02-01",
        end: "2026-04-01"
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "results" => [ { "currency" => "USD", "increase_count" => 2 } ]
      )
    end

    it "includes future-dated salary increase events in the requested range" do
      employee = create_employee(number: 1)
      create_salary(employee, amount: "100.000", from: Date.new(2026, 10, 1))
      create_salary(employee, amount: "120.000", from: Date.new(2026, 12, 1))

      get "/api/v1/insights/salary_increases", params: {
        start: "2026-12-01",
        end: "2027-01-01"
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "results" => [ { "currency" => "USD", "increase_count" => 1 } ]
      )
    end

    it "compares the selected records against their predecessor outside the selected range" do
      employee = create_employee(number: 1)
      create_salary(employee, amount: "100.000", from: Date.new(2026, 1, 1))
      create_salary(employee, amount: "120.000", from: Date.new(2026, 2, 1))

      get "/api/v1/insights/salary_increases", params: {
        start: "2026-02-01",
        end: "2026-03-01"
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "results" => [ { "currency" => "USD", "increase_count" => 1 } ]
      )
    end

    it "does not count a currency change as a comparable increase" do
      employee = create_employee(number: 1)
      create_salary(employee, amount: "100.000", currency: "USD", from: Date.new(2026, 1, 1))
      create_salary(employee, amount: "200.000", currency: "EUR", from: Date.new(2026, 2, 1))

      get "/api/v1/insights/salary_increases", params: {
        start: "2026-02-01",
        end: "2026-03-01"
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("results" => [])
    end

    [
      {},
      { start: "2026-01-01" },
      { end: "2026-02-01" },
      { start: "not-a-date", end: "2026-02-01" },
      { start: "2026-02-30", end: "2026-03-01" },
      { start: "2026-03-01", end: "2026-03-01" },
      { start: "2026-04-01", end: "2026-03-01" }
    ].each do |invalid_range|
      it "rejects invalid date range #{invalid_range}" do
        get "/api/v1/insights/salary_increases", params: invalid_range

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to include("errors")
      end
    end

    it "returns an empty results array when there are no increase events" do
      get "/api/v1/insights/salary_increases", params: {
        start: "2026-01-01",
        end: "2026-02-01"
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("results" => [])
    end
  end
end
