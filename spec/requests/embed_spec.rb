require "rails_helper"

RSpec.describe "Embed feedback widget", type: :request do
  let(:organization) { create(:organization) }
  let(:project) { create(:project, organization: organization) }
  let!(:embed_domain) { create(:embed_domain, organization: organization, project: project, host: "good.example.com") }

  def pixel_upload
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/pixel.png"), "image/png")
  end

  describe "GET /embed.js" do
    it "serves the loader as JavaScript without requiring a session" do
      get embed_loader_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/javascript")
      expect(response.body).to include("pt-embed:size")
    end
  end

  describe "GET /embed/frame" do
    it "404s for an unknown host" do
      get embed_frame_path, params: { origin: "https://unknown.example.com" }

      expect(response).to have_http_status(:not_found)
    end

    it "renders the widget and scopes framing to the allowlisted origin" do
      get embed_frame_path, params: { origin: "https://good.example.com" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("FeedbackWidget")
      expect(response.headers["Content-Security-Policy"]).to eq("frame-ancestors https://good.example.com")
      expect(response.headers["X-Frame-Options"]).to be_nil
    end

    it "passes the organization's configured item types to the widget props" do
      get embed_frame_path, params: { origin: "https://good.example.com" }

      props = JSON.parse(Nokogiri::HTML(response.body).at_css("[data-props]")["data-props"])
      expect(props["itemTypes"]).to eq(organization.item_types.ordered.map(&:name))
      expect(props["itemTypes"]).to eq(%w[bug feature idea])
    end

    it "passes the embed's default item type to the widget props" do
      embed_domain.update!(default_item_type: "feature")

      get embed_frame_path, params: { origin: "https://good.example.com" }

      props = JSON.parse(Nokogiri::HTML(response.body).at_css("[data-props]")["data-props"])
      expect(props["defaultType"]).to eq("feature")
    end

    it "passes no default type when the configured one has since been removed" do
      embed_domain.update_column(:default_item_type, "banana")

      get embed_frame_path, params: { origin: "https://good.example.com" }

      props = JSON.parse(Nokogiri::HTML(response.body).at_css("[data-props]")["data-props"])
      expect(props["defaultType"]).to be_nil
    end

    it "matches an allowlisted host:port exactly" do
      create(:embed_domain, organization: organization, project: project, host: "localhost:5173")

      get embed_frame_path, params: { origin: "http://localhost:5173" }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Security-Policy"]).to eq("frame-ancestors http://localhost:5173")
    end
  end

  describe "the loader tag in the app layout (PROJ-104)" do
    let(:loader_tag) { %(<script src="#{embed_loader_url}" async></script>) }

    it "renders the loader for the admin (first-registered) user" do
      register_passkey(username: "owner")

      get projects_path

      expect(response.body).to include(loader_tag)
    end

    it "omits the loader for a non-admin user" do
      register_passkey(username: "owner")
      register_passkey(username: "member", client: WebAuthn::FakeClient.new(webauthn_origin))

      get projects_path

      expect(response.body).not_to include("embed.js")
    end

    it "omits the loader for signed-out visitors" do
      get login_path

      expect(response.body).not_to include("embed.js")
    end
  end

  describe "POST /embed/items" do
    let(:params) do
      {
        title: "Board does not scroll",
        description: "Steps to reproduce...",
        item_type: "bug",
        origin: "https://good.example.com",
        page_url: "https://good.example.com/board",
        viewport: "1440x900",
        user_agent: "Mozilla/5.0 (Test)"
      }
    end

    it "creates a published item in the mapped project with the submitted context" do
      expect do
        post embed_items_path, params: params.merge(screenshot: pixel_upload)
      end.to change(project.items, :count).by(1)

      expect(response).to have_http_status(:created)

      item = project.items.order(:created_at).last
      expect(item.draft).to be(false)
      expect(item.source).to eq("embed")
      expect(item.item_type).to eq("bug")
      expect(item.status).to eq(organization.statuses.ordered.first)
      expect(item.metadata).to eq(
        "page_url" => "https://good.example.com/board",
        "viewport" => "1440x900",
        "user_agent" => "Mozilla/5.0 (Test)"
      )
      expect(item.notes.to_plain_text).to include("Steps to reproduce")
      expect(item.notes.embeds.count).to eq(1)

      body = response.parsed_body
      expect(body["key"]).to eq(item.key)
      expect(body["url"]).to include(item.key.split("-").first)
    end

    it "creates an item of each configured type" do
      organization.item_types.ordered.map(&:name).each do |type|
        post embed_items_path, params: params.merge(item_type: type)

        expect(response).to have_http_status(:created)
        expect(project.items.order(:created_at).last.item_type).to eq(type)
      end
    end

    it "falls back to idea for an unconfigured type rather than erroring" do
      post embed_items_path, params: params.merge(item_type: "banana")

      expect(response).to have_http_status(:created)
      expect(project.items.order(:created_at).last.item_type).to eq("idea")
    end

    it "creates an item without a screenshot" do
      expect do
        post embed_items_path, params: params.except(:page_url)
      end.to change(project.items, :count).by(1)

      item = project.items.order(:created_at).last
      expect(item.notes.embeds).to be_empty
      expect(item.metadata).not_to have_key("page_url")
    end

    it "refuses a submission from a non-allowlisted host" do
      expect do
        post embed_items_path, params: params.merge(origin: "https://evil.example.com")
      end.not_to change(Item, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "422s when the title is blank" do
      post embed_items_path, params: params.merge(title: "  ")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to be_present
    end
  end
end
