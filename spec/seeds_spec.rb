require "rails_helper"

RSpec.describe "HR manager seed configuration" do
  around do |example|
    original_email = ENV.delete("HR_MANAGER_EMAIL")
    original_password = ENV.delete("HR_MANAGER_PASSWORD")
    example.run
  ensure
    ENV["HR_MANAGER_EMAIL"] = original_email if original_email
    ENV["HR_MANAGER_PASSWORD"] = original_password if original_password
  end

  it "fails clearly if either required environment variable is missing" do
    ENV["HR_MANAGER_EMAIL"] = "hr@example.com"

    expect { load Rails.root.join("db/seeds.rb") }
      .to raise_error(SystemExit) { |error| expect(error.message).to include("HR_MANAGER_EMAIL and HR_MANAGER_PASSWORD") }
  end

  it "creates or updates the configured user idempotently without storing a plain password" do
    ENV["HR_MANAGER_EMAIL"] = " HR@Example.com "
    ENV["HR_MANAGER_PASSWORD"] = "seed-password"

    expect { load Rails.root.join("db/seeds.rb") }.to change(User, :count).by(1)
    user = User.find_by!(email: "hr@example.com")
    digest = user.password_digest

    expect(user.authenticate("seed-password")).to eq(user)
    expect(digest).not_to eq("seed-password")
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(User, :count)
  end
end
