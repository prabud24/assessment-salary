require "rails_helper"

RSpec.describe "Single-page app fallback", type: :request do
  before do
    @public_dir = Dir.mktmpdir
    File.write(File.join(@public_dir, "index.html"), "<!doctype html><div id=\"root\"></div>")
    allow(Rails).to receive(:public_path).and_return(Pathname.new(@public_dir))
  end

  after { FileUtils.remove_entry(@public_dir) }

  it "serves the app shell for client-side deep links without authentication" do
    get "/employees/12/edit", headers: { "Accept" => "text/html" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include('id="root"')
  end

  it "keeps API routes protected and returning JSON" do
    get "/api/v1/employees"

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq("errors" => { "base" => [ "Authentication required" ] })
  end

  it "does not fall back for unknown API paths or missing asset files" do
    get "/api/v1/nope", headers: { "Accept" => "text/html" }
    expect(response).to have_http_status(:not_found)

    get "/assets/missing.js", headers: { "Accept" => "text/html" }
    expect(response).to have_http_status(:not_found)

    get "/assets/missing.css", headers: { "Accept" => "*/*" }
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include('id="root"')
  end

  it "keeps the health endpoint public" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
