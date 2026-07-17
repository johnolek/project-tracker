require "rails_helper"

RSpec.describe "API v1 authentication", type: :request do
  it "returns 401 without a token" do
    get api_v1_projects_path

    expect(response).to have_http_status(:unauthorized)
    expect(json_body).to eq("error" => "Invalid or missing API token")
  end

  it "returns 401 with a garbage token" do
    get api_v1_projects_path, headers: { "Authorization" => "Bearer pt_garbage" }

    expect(response).to have_http_status(:unauthorized)
    expect(json_body).to eq("error" => "Invalid or missing API token")
  end

  it "returns 200 with a valid token" do
    get api_v1_projects_path, headers: auth_headers

    expect(response).to have_http_status(:ok)
  end

  it "records last_used_at on the key after a request" do
    expect(api_key.last_used_at).to be_nil

    get api_v1_projects_path, headers: auth_headers

    expect(api_key.reload.last_used_at).to be_present
  end
end
