require "rails_helper"

RSpec.describe "Salary Records API", type: :request do
  let(:employee) do
    Employee.create!(
      employee_number: "EMP00001",
      name: "Asha Rao",
      email: "asha.rao@example.com",
      country_code: "IN",
      department: "Engineering"
    )
  end

  let(:business_date) { Time.current.in_time_zone("Asia/Kolkata").to_date }
  let(:salary_record_attributes) do
    {
      annual_salary: "60000.125",
      currency: "USD",
      effective_from: business_date.iso8601
    }
  end

  def create_salary_record(overrides = {})
    SalaryRecord.create!({
      employee: employee,
      annual_salary: "50000.000",
      currency: "USD",
      effective_from: business_date - 1.year,
      effective_to: nil
    }.merge(overrides))
  end

  def salary_record_json(record)
    {
      "annual_salary" => record.annual_salary.to_s("F"),
      "currency" => record.currency,
      "effective_from" => record.effective_from.as_json,
      "effective_to" => record.effective_to&.as_json,
      "created_at" => record.created_at.as_json,
      "updated_at" => record.updated_at.as_json
    }
  end

  describe "GET /api/v1/employees/:employee_id/salary_records" do
    it "returns salary history ordered newest first and only the public fields" do
      older = create_salary_record(effective_from: business_date - 2.years, effective_to: business_date - 1.year)
      newer = create_salary_record(effective_from: business_date - 1.year, effective_to: nil)

      get "/api/v1/employees/#{employee.id}/salary_records"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "salary_records" => [ salary_record_json(newer), salary_record_json(older) ]
      )
      expect(response.parsed_body.fetch("salary_records").first.keys).to match_array(
        %w[annual_salary currency effective_from effective_to created_at updated_at]
      )
    end

    it "returns 404 when the employee does not exist" do
      get "/api/v1/employees/999999/salary_records"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq(
        "errors" => { "base" => [ "Employee not found" ] }
      )
    end
  end

  describe "POST /api/v1/employees/:employee_id/salary_records" do
    it "creates a first salary record and serializes annual salary as a string" do
      expect {
        post "/api/v1/employees/#{employee.id}/salary_records",
          params: { salary_record: salary_record_attributes },
          as: :json
      }.to change(SalaryRecord, :count).by(1)

      record = SalaryRecord.last
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq("salary_record" => salary_record_json(record))
      expect(response.parsed_body.dig("salary_record", "annual_salary")).to be_a(String)
      expect(response.body).not_to match(/"annual_salary"\s*:\s*\d/)
    end

    it "closes the previous open record and creates an adjacent new record" do
      previous_record = create_salary_record
      effective_date = (business_date + 1.day).iso8601

      post "/api/v1/employees/#{employee.id}/salary_records",
        params: {
          salary_record: salary_record_attributes.merge(effective_from: effective_date)
        },
        as: :json

      expect(response).to have_http_status(:created)
      expect(previous_record.reload.effective_to).to eq(Date.iso8601(effective_date))
      expect(response.parsed_body.dig("salary_record", "effective_to")).to be_nil
      expect(response.parsed_body.dig("salary_record", "effective_from")).to eq(effective_date)
    end

    it "returns 422 for a missing effective date" do
      attributes = salary_record_attributes.except(:effective_from)

      post "/api/v1/employees/#{employee.id}/salary_records",
        params: { salary_record: attributes },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("errors", "effective_from")).to include("is required")
    end

    it "returns 422 for a malformed effective date" do
      post "/api/v1/employees/#{employee.id}/salary_records",
        params: {
          salary_record: salary_record_attributes.merge(effective_from: "not-a-date")
        },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("errors", "effective_from")).to include(
        "must be a valid date in YYYY-MM-DD format"
      )
    end

    it "returns 422 for a date before the business date" do
      post "/api/v1/employees/#{employee.id}/salary_records",
        params: {
          salary_record: salary_record_attributes.merge(effective_from: (business_date - 1.day).iso8601)
        },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("errors", "effective_from")).to include(
        "must be on or after the business date"
      )
    end

    it "returns 422 with model validation errors for invalid salary details" do
      post "/api/v1/employees/#{employee.id}/salary_records",
        params: {
          salary_record: salary_record_attributes.merge(annual_salary: "0", currency: "US")
        },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("errors", "annual_salary")).to be_present
      expect(response.parsed_body.dig("errors", "currency")).to be_present
    end

    it "returns 422 for an inactive employee" do
      employee.update!(status: "inactive")

      post "/api/v1/employees/#{employee.id}/salary_records",
        params: { salary_record: salary_record_attributes },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("errors", "employee")).to include("must be active")
    end

    it "returns 422 when the effective date is not later than the latest salary record" do
      create_salary_record(effective_from: business_date, effective_to: nil)

      post "/api/v1/employees/#{employee.id}/salary_records",
        params: { salary_record: salary_record_attributes },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("errors", "effective_from")).to include(
        "must be later than the latest salary record"
      )
    end

    it "returns 404 when the employee does not exist" do
      post "/api/v1/employees/999999/salary_records",
        params: { salary_record: salary_record_attributes },
        as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq(
        "errors" => { "base" => [ "Employee not found" ] }
      )
    end
  end
end
