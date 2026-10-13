require "rails_helper"

RSpec.describe "HR sessions API", type: :request do
  let(:email) { "hr.manager@example.com" }
  let(:password) { "secure-test-password" }

  def create_hr_user
    User.create!(email:, password:)
  end

  def csrf_token
    get "/api/v1/session"
    response.parsed_body.fetch("csrf_token")
  end

  def login(user_email: email, user_password: password, token: csrf_token)
    post "/api/v1/session",
      params: { email: user_email, password: user_password },
      headers: { "X-CSRF-Token" => token },
      as: :json
  end

  describe "GET /api/v1/session" do
    it "returns an anonymous session and a CSRF token before login" do
      get "/api/v1/session"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]).to be_nil
      expect(response.parsed_body.fetch("csrf_token")).to be_present
    end

    it "returns only safe fields for the authenticated user" do
      user = create_hr_user
      login
      get "/api/v1/session"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("user")).to eq("id" => user.id, "email" => email)
      expect(response.parsed_body.keys).to match_array(%w[user csrf_token])
      expect(response.parsed_body.fetch("user").keys).to match_array(%w[id email])
    end
  end

  describe "POST /api/v1/session" do
    it "authenticates valid credentials, rotates the session, and sets protected cookie attributes" do
      user = create_hr_user
      get "/api/v1/session"
      token = response.parsed_body.fetch("csrf_token")
      original_session_cookie = response.headers["Set-Cookie"].split(";", 2).first

      login(token:)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("user")).to eq("id" => user.id, "email" => email)
      expect(response.parsed_body.fetch("csrf_token")).to be_present
      expect(response.headers["Set-Cookie"].downcase).to include("httponly", "samesite=lax")
      expect(response.headers["Set-Cookie"].split(";", 2).first).not_to eq(original_session_cookie)
      expect(response.body).not_to include("password_digest", "secure-test-password")
      expect(ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM sessions").to_i).to be_positive

      get "/api/v1/session"
      expect(response.parsed_body.dig("user", "id")).to eq(user.id)
      expect(response.parsed_body.fetch("csrf_token")).not_to eq(token)
    end

    it "rejects invalid credentials with the consistent 401 error" do
      create_hr_user

      login(user_password: "wrong-password")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq(
        "errors" => { "base" => [ "Invalid email or password" ] }
      )
    end

    it "rejects login without a CSRF token" do
      create_hr_user
      get "/api/v1/session"

      post "/api/v1/session",
        params: { email:, password: },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq(
        "errors" => { "base" => [ "Invalid CSRF token" ] }
      )
    end

    it "rejects login with an invalid CSRF token" do
      create_hr_user

      login(token: "invalid-token")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to include("errors")
    end
  end

  describe "DELETE /api/v1/session" do
    it "logs out and invalidates the session" do
      user = create_hr_user
      login

      delete "/api/v1/session", headers: { "X-CSRF-Token" => response.parsed_body.fetch("csrf_token") }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]).to be_nil
      expect(response.parsed_body.fetch("csrf_token")).to be_present
      get "/api/v1/session"
      expect(response.parsed_body["user"]).to be_nil
      get "/api/v1/employees"
      expect(response).to have_http_status(:unauthorized)
      expect(User.find(user.id)).to be_present
    end

    it "rejects logout without a CSRF token without ending the session" do
      create_hr_user
      login

      delete "/api/v1/session"

      expect(response).to have_http_status(:unprocessable_entity)
      get "/api/v1/session"
      expect(response.parsed_body["user"]).to be_present
    end
  end

  describe "protected endpoints" do
    it "rejects anonymous reads across employee, salary, and insights APIs" do
      [
        "/api/v1/employees",
        "/api/v1/employees/1",
        "/api/v1/employees/1/salary_records",
        "/api/v1/insights/average_salary_by_country",
        "/api/v1/insights/total_salary_by_department",
        "/api/v1/insights/salary_increases?start=2026-01-01&end=2026-02-01"
      ].each do |path|
        get path

        expect(response).to have_http_status(:unauthorized), "expected #{path} to require authentication"
        expect(response.parsed_body).to include("errors")
      end
    end

    it "returns 401 for an anonymous state change with a valid CSRF token" do
      get "/api/v1/session"
      token = response.parsed_body.fetch("csrf_token")

      post "/api/v1/employees",
        params: { employee: { employee_number: "EMP00001" } },
        headers: { "X-CSRF-Token" => token },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects state-changing requests with missing or invalid CSRF tokens" do
      create_hr_user
      login

      post "/api/v1/employees",
        params: { employee: { employee_number: "EMP00001" } },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      post "/api/v1/employees",
        params: { employee: { employee_number: "EMP00001" } },
        headers: { "X-CSRF-Token" => "invalid-token" },
        as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
