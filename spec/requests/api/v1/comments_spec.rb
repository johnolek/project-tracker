require "rails_helper"

RSpec.describe "API v1 comments", type: :request do
  let(:project) { api_organization.projects.create!(name: "Tracker") }
  let(:item) { create(:item, project: project) }

  describe "GET /api/v1/items/:item_id/comments" do
    it "lists comments chronologically with author details" do
      older = create(:comment, item: item, user: api_user, body: "First", created_at: 2.hours.ago)
      newer = create(:comment, item: item, user: api_user, body: "Second", created_at: 1.hour.ago)

      get api_v1_item_comments_path(item), headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body["comments"].map { |comment| comment["id"] }).to eq([ older.id, newer.id ])
      expect(json_body["comments"].first).to include(
        "body" => "First",
        "user" => { "id" => api_user.id, "username" => api_user.username }
      )
      expect(json_body["comments"].first.keys).to match_array(%w[id body user created_at])
    end

    it "404s for another organization's item" do
      get api_v1_item_comments_path(item), headers: auth_headers(create(:api_key))

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/items/:item_id/comments" do
    it "creates a comment authored by the key's user" do
      expect do
        post api_v1_item_comments_path(item), params: { comment: { body: "Progress: done" } }, headers: auth_headers
      end.to change(item.comments, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_body["body"]).to eq("Progress: done")
      expect(json_body["user"]).to eq("id" => api_user.id, "username" => api_user.username)
      expect(item.comments.last.user).to eq(api_user)
    end

    it "422s on a blank body" do
      post api_v1_item_comments_path(item), params: { comment: { body: "" } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["errors"]).to include("Body can't be blank")
    end
  end
end
