require "rails_helper"
require "open3"

# Boots the app in the production environment in a subprocess to exercise production.rb.
RSpec.describe "Production host protection" do
  let(:probe) do
    <<~RUBY
      require "rack/mock"
      app = Rails.application
      call = ->(host, path) { Rack::MockRequest.new(app).get("https://\#{host}\#{path}", "HTTP_HOST" => host).status }
      puts [call.("evil.test", "/api/v1/health"), call.("salary.example.com", "/api/v1/health"),
            call.("evil.test", "/up"), call.("evil.test", "/api/v1/employees")].join(",")
    RUBY
  end

  def run_production(env, script)
    base = { "RAILS_ENV" => "production", "SECRET_KEY_BASE" => "x" * 64,
             "DATABASE_URL" => "postgres://u:p@127.0.0.1:1/none", "RAILS_LOG_LEVEL" => "fatal" }
    Open3.capture3(base.merge(env), "bin/rails", "runner", script, chdir: Rails.root.to_s)
  end

  it "rejects unlisted hosts, serves listed hosts, and keeps /up reachable" do
    out, err, status = run_production({ "RAILS_ALLOWED_HOSTS" => "salary.example.com" }, probe)

    expect(status).to be_success, err
    expect(out.lines.last.strip).to eq("403,200,200,403")
  end

  it "refuses to boot without an explicit host allow-list" do
    _out, err, status = run_production({ "RAILS_ALLOWED_HOSTS" => "" }, "puts 1")

    expect(status).not_to be_success
    expect(err).to include("RAILS_ALLOWED_HOSTS must list")
  end

  it "serves public assets without extra environment variables" do
    out, err, status = run_production({ "RAILS_ALLOWED_HOSTS" => "a.test" },
                                      "puts Rails.application.config.public_file_server.enabled")

    expect(status).to be_success, err
    expect(out.strip).to eq("true")
  end
end
