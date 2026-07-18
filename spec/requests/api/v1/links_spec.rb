require "rails_helper"

RSpec.describe "API v1 links", type: :request do
  let(:project) { api_organization.projects.create!(name: "Tracker") }
  let(:item) { create(:item, project: project, title: "Ship it") }
  let(:other) { create(:item, project: project, title: "Groundwork") }

  describe "POST /api/v1/items/:item_id/links" do
    it "creates a blocks link by target key and returns the item with links buckets" do
      post api_v1_item_links_path(item), headers: auth_headers,
           params: { link: { kind: "blocks", target: other.key } }

      expect(response).to have_http_status(:created)
      link = ItemLink.sole
      expect(link).to have_attributes(source: item, target: other, kind: "blocks")
      expect(json_body["links"]["blocks"]).to contain_exactly(
        "id" => other.id, "key" => other.key, "title" => "Groundwork", "link_id" => link.id
      )
      expect(json_body["links"]["blocked_by"]).to eq([])
    end

    it "stores blocked_by as the reversed blocks edge" do
      post api_v1_item_links_path(item), headers: auth_headers,
           params: { link: { kind: "blocked_by", target: other.id } }

      expect(response).to have_http_status(:created)
      expect(ItemLink.sole).to have_attributes(source: other, target: item, kind: "blocks")
      expect(json_body["links"]["blocked_by"].sole["key"]).to eq(other.key)
    end

    it "reads relates_to from both endpoints" do
      post api_v1_item_links_path(item), headers: auth_headers,
           params: { link: { kind: "relates_to", target: other.key } }

      get api_v1_item_path(other), headers: auth_headers
      expect(json_body["links"]["relates_to"].sole["key"]).to eq(item.key)
    end

    it "links across projects within the organization" do
      elsewhere = create(:item, project: api_organization.projects.create!(name: "Other"))

      post api_v1_item_links_path(item), headers: auth_headers,
           params: { link: { kind: "blocks", target: elsewhere.key } }

      expect(response).to have_http_status(:created)
    end

    it "422s on an unknown kind" do
      post api_v1_item_links_path(item), headers: auth_headers,
           params: { link: { kind: "duplicates", target: other.key } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["error"]).to start_with("Unknown kind: duplicates")
    end

    it "422s on an unresolvable target and on a target in another organization" do
      post api_v1_item_links_path(item), headers: auth_headers,
           params: { link: { kind: "blocks", target: "NOPE-1" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to eq("error" => "Unknown target: NOPE-1")

      foreign = create(:item)
      post api_v1_item_links_path(item), headers: auth_headers,
           params: { link: { kind: "blocks", target: foreign.id } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to eq("error" => "Unknown target: #{foreign.id}")
    end

    it "422s with validation errors on a duplicate link" do
      create(:item_link, source: item, target: other, kind: "blocks")

      post api_v1_item_links_path(item), headers: auth_headers,
           params: { link: { kind: "blocks", target: other.key } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["errors"]).to include("Target is already linked")
    end

    it "404s for a source item in another organization" do
      foreign = create(:item)

      post api_v1_item_links_path(foreign), headers: auth_headers,
           params: { link: { kind: "blocks", target: other.key } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/links/:id" do
    it "removes the link" do
      link = create(:item_link, source: item, target: other)

      delete api_v1_link_path(link), headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(ItemLink.exists?(link.id)).to be(false)
    end

    it "404s for a link in another organization" do
      foreign_link = create(:item_link)

      delete api_v1_link_path(foreign_link), headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(ItemLink.exists?(foreign_link.id)).to be(true)
    end
  end
end
