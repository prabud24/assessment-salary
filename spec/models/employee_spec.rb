require "rails_helper"

RSpec.describe Employee, type: :model do
  def build_employee(overrides = {})
    Employee.new({
      employee_number: "EMP00001",
      name: "Asha Rao",
      email: "asha.rao@example.com",
      country_code: "IN",
      department: "Engineering"
    }.merge(overrides))
  end

  # Raw SQL bypasses both validations and attribute normalization.
  def insert_row(overrides = {})
    attrs = {
      employee_number: "EMP00001", name: "Asha Rao", email: "asha.rao@example.com",
      country_code: "IN", department: "Engineering", status: "active"
    }.merge(overrides)
    columns = attrs.keys.join(", ")
    values = attrs.values.map { |value| Employee.connection.quote(value) }.join(", ")
    Employee.connection.execute(
      "INSERT INTO employees (#{columns}, created_at, updated_at) VALUES (#{values}, NOW(), NOW())"
    )
  end

  describe "validity" do
    it "is valid with all required attributes" do
      expect(build_employee).to be_valid
    end

    it "defaults status to active" do
      expect(build_employee.status).to eq("active")
    end
  end

  describe "required fields" do
    %i[employee_number name email country_code department].each do |field|
      it "requires #{field}" do
        employee = build_employee(field => nil)
        expect(employee).not_to be_valid
        expect(employee.errors[field]).to include("can't be blank")
      end

      it "rejects a blank #{field}" do
        expect(build_employee(field => "   ")).not_to be_valid
      end
    end
  end

  describe "employee_number" do
    it "accepts the lower boundary EMP00001" do
      expect(build_employee(employee_number: "EMP00001")).to be_valid
    end

    it "accepts the upper boundary EMP99999" do
      expect(build_employee(employee_number: "EMP99999")).to be_valid
    end

    %w[EMP00000 EMP0001 EMP100000 ABC00001 EMP0000A 00001].each do |value|
      it "rejects #{value}" do
        employee = build_employee(employee_number: value)
        expect(employee).not_to be_valid
        expect(employee.errors[:employee_number]).to be_present
      end
    end

    it "trims whitespace and upcases" do
      expect(build_employee(employee_number: "  emp00042 ").employee_number).to eq("EMP00042")
    end

    it "must be unique" do
      build_employee.save!
      duplicate = build_employee(email: "other@example.com")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:employee_number]).to include("has already been taken")
    end
  end

  describe "email" do
    it "trims whitespace and downcases" do
      expect(build_employee(email: "  Asha.Rao@Example.COM ").email).to eq("asha.rao@example.com")
    end

    it "rejects an invalid format" do
      expect(build_employee(email: "not-an-email")).not_to be_valid
    end

    it "must be unique ignoring case" do
      build_employee.save!
      duplicate = build_employee(employee_number: "EMP00002", email: "ASHA.RAO@EXAMPLE.COM")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include("has already been taken")
    end
  end

  describe "country_code" do
    it "normalizes lowercase to uppercase" do
      expect(build_employee(country_code: " us ").country_code).to eq("US")
    end

    %w[USA U 1N U1].each do |value|
      it "rejects #{value}" do
        expect(build_employee(country_code: value)).not_to be_valid
      end
    end
  end

  describe "status" do
    %w[active inactive].each do |value|
      it "accepts #{value}" do
        expect(build_employee(status: value)).to be_valid
      end
    end

    %w[ACTIVE terminated].each do |value|
      it "rejects #{value}" do
        employee = build_employee(status: value)
        expect(employee).not_to be_valid
        expect(employee.errors[:status]).to be_present
      end
    end
  end

  describe "database constraints" do
    it "rejects duplicate employee numbers" do
      insert_row
      expect { insert_row(email: "other@example.com") }.to raise_error(ActiveRecord::RecordNotUnique, /index_employees_on_employee_number/)
    end

    it "rejects emails that differ only by case via the unique index" do
      insert_row
      expect {
        insert_row(employee_number: "EMP00002", email: "ASHA.RAO@EXAMPLE.COM")
      }.to raise_error(ActiveRecord::RecordNotUnique, /index_employees_on_lower_email/)
    end

    it "rejects EMP00000" do
      expect { insert_row(employee_number: "EMP00000") }
        .to raise_error(ActiveRecord::StatementInvalid, /employees_employee_number_format/)
    end

    it "rejects a malformed employee number" do
      expect { insert_row(employee_number: "EMP1") }
        .to raise_error(ActiveRecord::StatementInvalid, /employees_employee_number_format/)
    end

    it "accepts the boundary employee numbers" do
      expect {
        insert_row(employee_number: "EMP00001")
        insert_row(employee_number: "EMP99999", email: "b@example.com")
      }.to change(Employee, :count).by(2)
    end

    it "rejects an invalid status" do
      expect { insert_row(status: "retired") }
        .to raise_error(ActiveRecord::StatementInvalid, /employees_status_allowed/)
    end

    it "rejects a lowercase country code" do
      expect { insert_row(country_code: "in") }
        .to raise_error(ActiveRecord::StatementInvalid, /employees_country_code_format/)
    end

    it "defaults status to active at the database level" do
      Employee.connection.execute(
        "INSERT INTO employees (employee_number, name, email, country_code, department, created_at, updated_at) " \
        "VALUES ('EMP00001', 'Asha Rao', 'asha.rao@example.com', 'IN', 'Engineering', NOW(), NOW())"
      )
      expect(Employee.first.status).to eq("active")
    end
  end
end
