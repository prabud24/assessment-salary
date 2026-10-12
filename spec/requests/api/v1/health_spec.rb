require "rails_helper"

RSpec.describe "GET /api/v1/health", type: :request do
  before { get "/api/v1/health" }

  it "returns HTTP 200" do
    expect(response).to have_http_status(:ok)
  end

  it "returns a JSON content type" do
    expect(response.media_type).to eq("application/json")
  end

  it "returns the status body" do
    expect(response.parsed_body).to eq({ "status" => "ok" })
  end
end
