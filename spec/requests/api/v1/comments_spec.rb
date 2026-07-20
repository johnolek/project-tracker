require "rails_helper"

RSpec.describe "API v1 comments", type: :request do
  let(:project) { api_organization.projects.create!(name: "Tracker") }
  let(:item) { create(:item, project: project) }

  describe "GET /api/v1/items/:item_id/comments" do
    it "lists comments chronologically with body, rich-text forms, source, and author" do
      older = create(:comment, item: item, user: api_user, body: "First", source: "api", created_at: 2.hours.ago)
      newer = create(:comment, item: item, user: api_user, body: "Second", source: "web", created_at: 1.hour.ago)

      get api_v1_item_comments_path(item), headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body["comments"].map { |comment| comment["id"] }).to eq([ older.id, newer.id ])

      first = json_body["comments"].first
      expect(first).to include(
        "body" => "First",
        "body_text" => "First",
        "source" => "api",
        "user" => { "id" => api_user.id, "username" => api_user.username }
      )
      expect(first["body_html"]).to include("First")
      expect(first.keys).to match_array(%w[id body body_html body_text source user created_at])
      expect(json_body["comments"].second["source"]).to eq("web")
    end

    it "accepts the item's human key in place of the id" do
      comment = create(:comment, item: item, user: api_user, body: "Keyed")

      get api_v1_item_comments_path(item.key), headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body["comments"].map { |entry| entry["id"] }).to eq([ comment.id ])
    end

    it "404s for another organization's item" do
      get api_v1_item_comments_path(item), headers: auth_headers(create(:api_key))

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/items/:item_id/comments" do
    it "creates a comment authored by the key's user and stamped source: api" do
      expect do
        post api_v1_item_comments_path(item), params: { comment: { body: "Progress: done" } }, headers: auth_headers
      end.to change(item.comments, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_body["body"]).to eq("Progress: done")
      expect(json_body["body_text"]).to eq("Progress: done")
      expect(json_body["body_html"]).to include("Progress: done")
      expect(json_body["source"]).to eq("api")
      expect(json_body["user"]).to eq("id" => api_user.id, "username" => api_user.username)

      last = item.comments.last
      expect(last.user).to eq(api_user)
      expect(last.source).to eq("api")
      expect(last.body.to_plain_text).to eq("Progress: done")
    end

    it "stores an HTML body built from rhino-supported tags" do
      body = '<h1>Findings</h1><ul><li><strong>bold</strong> point</li><li>has <code>inline code</code></li></ul>' \
             '<pre><code>puts :hi</code></pre><p>See <a href="https://example.com">the docs</a>.</p>'

      post api_v1_item_comments_path(item), params: { comment: { body: body } }, headers: auth_headers

      expect(response).to have_http_status(:created)
      html = json_body["body_html"]
      expect(html).to include("Findings</h1>")
      expect(html).to include("<strong>bold</strong>")
      expect(html).to include("<pre><code>puts :hi</code></pre>")
      expect(html).to include('href="https://example.com"')
      expect(json_body["body_text"]).to include("Findings")
    end

    it "strips tags rhino cannot round-trip, keeping their text" do
      post api_v1_item_comments_path(item),
           params: { comment: { body: '<table><tr><td>cell</td></tr></table><p onclick="x">kept</p><script>alert(1)</script>' } },
           headers: auth_headers

      expect(response).to have_http_status(:created)
      html = json_body["body_html"]
      expect(html).to include("cell")
      expect(html).not_to include("<table")
      expect(html).to include("<p>kept</p>")
      expect(html).not_to include("onclick")
      expect(html).not_to include("alert(1)")
    end

    it "422s on a blank body" do
      post api_v1_item_comments_path(item), params: { comment: { body: "" } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["errors"]).to include("Body can't be blank")
    end
  end

  describe "PATCH /api/v1/comments/:id" do
    it "rewrites the body with the same sanitization as create, regardless of author" do
      comment = create(:comment, item: item, user: create(:user), body: "wall of text", source: "api")

      patch api_v1_comment_path(comment),
            params: { comment: { body: "<h1>Findings</h1><table><tr><td>dropped</td></tr></table>" } },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body["body_html"]).to include("Findings</h1>")
      expect(json_body["body_html"]).not_to include("<table")
      expect(comment.reload.body.to_plain_text).to include("Findings")
    end

    it "404s for a comment in another organization" do
      comment = create(:comment)

      patch api_v1_comment_path(comment), params: { comment: { body: "nope" } }, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
