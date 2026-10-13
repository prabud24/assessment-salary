require "rails_helper"

RSpec.describe "Employees API", type: :request do
  let(:employee_attributes) do
    {
      employee_number: "EMP00001",
      name: "Asha Rao",
      email: "asha.rao@example.com",
      country_code: "IN",
      department: "Engineering",
      status: "active"
    }
  end

  def create_employee(overrides = {})
    Employee.create!(employee_attributes.merge(overrides))
  end

  def employee_json(employee)
    {
      "id" => employee.id,
      "employee_number" => employee.employee_number,
      "name" => employee.name,
      "email" => employee.email,
      "country_code" => employee.country_code,
      "department" => employee.department,
      "status" => employee.status,
      "created_at" => employee.created_at.as_json,
      "updated_at" => employee.updated_at.as_json
    }
  end

  describe "GET /api/v1/employees" do
    it "returns employees with pagination metadata ordered by employee number" do
      higher_number = create_employee(employee_number: "EMP00002", email: "higher@example.com")
      lower_number = create_employee

      get "/api/v1/employees"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to eq(
        "employees" => [ employee_json(lower_number), employee_json(higher_number) ],
        "pagination" => {
          "page" => 1,
          "per_page" => 25,
          "total_count" => 2,
          "total_pages" => 1
        }
      )
    end

    it "searches employee number, name, and email case-insensitively" do
      number_match = create_employee
      name_match = create_employee(
        employee_number: "EMP00002",
        name: "Mina NameNeedle",
        email: "mina@example.com"
      )
      email_match = create_employee(
        employee_number: "EMP00003",
        name: "Ravi Kumar",
        email: "EmailNeedle@example.com"
      )
      create_employee(
        employee_number: "EMP00004",
        name: "Unrelated",
        email: "unrelated@example.com"
      )

      get "/api/v1/employees", params: { q: "00001" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("employees").pluck("id")).to contain_exactly(
        number_match.id
      )

      get "/api/v1/employees", params: { q: "nAmEnEeDlE" }

      expect(response.parsed_body.fetch("employees").pluck("id")).to contain_exactly(name_match.id)

      get "/api/v1/employees", params: { q: "eMaIlNeEdLe" }

      expect(response.parsed_body.fetch("employees").pluck("id")).to contain_exactly(email_match.id)
    end

    it "treats SQL LIKE wildcard characters in search literally" do
      matching = create_employee(name: "Asha 100%_Team")
      create_employee(
        employee_number: "EMP00002",
        name: "Asha 100XXTeam",
        email: "other@example.com"
      )

      get "/api/v1/employees", params: { q: "%_" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("employees").pluck("id")).to eq([ matching.id ])
    end

    it "applies country, department, and status filters together" do
      matching = create_employee(country_code: "IN", department: "Engineering", status: "active")
      create_employee(
        employee_number: "EMP00002",
        email: "other-country@example.com",
        country_code: "US"
      )
      create_employee(
        employee_number: "EMP00003",
        email: "other-department@example.com",
        department: "Finance"
      )
      create_employee(
        employee_number: "EMP00004",
        email: "inactive@example.com",
        status: "inactive"
      )

      get "/api/v1/employees", params: {
        country: "IN",
        department: "Engineering",
        status: "active"
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("employees").pluck("id")).to eq([ matching.id ])
      expect(response.parsed_body.dig("pagination", "total_count")).to eq(1)
    end

    it "paginates with the requested page and page size" do
      3.times do |index|
        create_employee(
          employee_number: format("EMP%05d", index + 1),
          email: "person#{index + 1}@example.com"
        )
      end

      get "/api/v1/employees", params: { page: "2", per_page: "2" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("employees").pluck("employee_number")).to eq([ "EMP00003" ])
      expect(response.parsed_body.fetch("pagination")).to eq(
        "page" => 2,
        "per_page" => 2,
        "total_count" => 3,
        "total_pages" => 2
      )
    end

    [
      { page: "abc" },
      { page: "0" },
      { page: "-1" },
      { page: "1.5" },
      { per_page: "abc" },
      { per_page: "0" },
      { per_page: "-1" },
      { per_page: "2.5" }
    ].each do |pagination_params|
      it "rejects invalid pagination parameters #{pagination_params}" do
        get "/api/v1/employees", params: pagination_params

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to include("errors")
      end
    end

    it "caps per_page at 100" do
      101.times do |index|
        create_employee(
          employee_number: format("EMP%05d", index + 1),
          email: "person#{index + 1}@example.com"
        )
      end

      get "/api/v1/employees", params: { per_page: "150" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("employees").length).to eq(100)
      expect(response.parsed_body.dig("pagination", "per_page")).to eq(100)
      expect(response.parsed_body.dig("pagination", "total_count")).to eq(101)
    end
  end

  describe "POST /api/v1/employees" do
    it "creates an employee and returns its location" do
      expect {
        post "/api/v1/employees", params: { employee: employee_attributes }, as: :json
      }.to change(Employee, :count).by(1)

      employee = Employee.order(:id).last
      expect(response).to have_http_status(:created)
      expect(response.location).to eq("http://www.example.com/api/v1/employees/#{employee.id}")
      expect(response.parsed_body).to eq("employee" => employee_json(employee))
    end

    it "returns model validation errors" do
      invalid_attributes = employee_attributes.merge(employee_number: "invalid")

      expect {
        post "/api/v1/employees", params: { employee: invalid_attributes }, as: :json
      }.not_to change(Employee, :count)

      expect(response).to have_http_status(422)
      expect(response.parsed_body.dig("errors", "employee_number")).to be_present
    end

    it "does not accept an id supplied by the client" do
      post "/api/v1/employees",
        params: { employee: employee_attributes.merge(id: 999) },
        as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("employee", "id")).not_to eq(999)
    end
  end

  describe "GET /api/v1/employees/:id" do
    it "returns the explicit employee representation without salary history" do
      employee = create_employee

      get "/api/v1/employees/#{employee.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("employee" => employee_json(employee))
    end

    it "returns a consistent not-found error for a missing employee" do
      get "/api/v1/employees/999999"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq(
        "errors" => { "base" => [ "Employee not found" ] }
      )
    end
  end

  describe "PATCH /api/v1/employees/:id" do
    it "updates permitted employee fields" do
      employee = create_employee

      patch "/api/v1/employees/#{employee.id}",
        params: { employee: { name: " Asha Updated ", department: " Product " } },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("employee", "name")).to eq("Asha Updated")
      expect(response.parsed_body.dig("employee", "department")).to eq("Product")
    end

    it "returns model validation errors for invalid updates" do
      employee = create_employee

      patch "/api/v1/employees/#{employee.id}",
        params: { employee: { status: "terminated" } },
        as: :json

      expect(response).to have_http_status(422)
      expect(response.parsed_body.dig("errors", "status")).to be_present
    end

    it "ignores a client-supplied id and leaves the employee id unchanged" do
      employee = create_employee
      original_id = employee.id

      patch "/api/v1/employees/#{employee.id}",
        params: { employee: { id: 999, name: "Updated Name" } },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("employee", "id")).to eq(original_id)
    end

    it "returns a consistent not-found error for a missing employee" do
      patch "/api/v1/employees/999999",
        params: { employee: { name: "Updated Name" } },
        as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq(
        "errors" => { "base" => [ "Employee not found" ] }
      )
    end
  end
end
