require "rails_helper"

RSpec.describe "API v1 tags", type: :request do
  describe "GET /api/v1/tags" do
    it "lists the organization's tags ordered by name" do
      api_organization.tags.create!(name: "zeta")
      api_organization.tags.create!(name: "alpha")
      create(:api_key).organization.tags.create!(name: "foreign")

      get api_v1_tags_path, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body["tags"].map { |tag| tag["name"] }).to eq(%w[alpha zeta])
      expect(json_body["tags"].first.keys).to match_array(%w[id name])
    end

    it "401s without a token" do
      get api_v1_tags_path

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
