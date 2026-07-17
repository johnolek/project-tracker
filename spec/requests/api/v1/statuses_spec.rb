require "rails_helper"

RSpec.describe "API v1 statuses", type: :request do
  describe "GET /api/v1/statuses" do
    it "lists the organization's statuses ordered by position" do
      get api_v1_statuses_path, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body["statuses"]).to eq(
        api_organization.statuses.ordered.map do |status|
          {
            "id" => status.id,
            "name" => status.name,
            "category" => status.category,
            "position" => status.position
          }
        end
      )
      expect(json_body["statuses"].map { |status| status["name"] }).to eq([ "New", "In Progress", "Completed" ])
    end

    it "401s without a token" do
      get api_v1_statuses_path

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
