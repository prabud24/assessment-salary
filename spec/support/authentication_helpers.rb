module AuthenticationHelpers
  HR_MANAGER_PASSWORD = "spec-password-2026"

  def authenticate_as_hr_manager
    user = User.create!(email: "hr.manager@example.com", password: HR_MANAGER_PASSWORD)
    get "/api/v1/session"
    token = response.parsed_body.fetch("csrf_token")

    post "/api/v1/session",
      params: { email: user.email, password: HR_MANAGER_PASSWORD },
      headers: { "X-CSRF-Token" => token },
      as: :json

    @csrf_token = response.parsed_body.fetch("csrf_token")
    user
  end

  def csrf_headers
    { "X-CSRF-Token" => @csrf_token }
  end
end
