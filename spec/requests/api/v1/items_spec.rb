require "rails_helper"

RSpec.describe "API v1 items", type: :request do
  let(:project) { api_organization.projects.create!(name: "Tracker") }

  def item_ids
    json_body["items"].map { |item| item["id"] }
  end

  def status_named(name)
    api_organization.statuses.find_by!(name: name)
  end

  describe "GET /api/v1/items filtering" do
    let!(:crash) do
      create(:item, project: project, title: "Fix login crash", item_type: "bug", points: 1, tag_names: %w[urgent backend])
    end
    let!(:docs) do
      create(:item, project: project, title: "Write docs", item_type: "feature", points: 3, tag_names: %w[backend],
                    status: status_named("In Progress"))
    end
    let!(:dark_mode) do
      create(:item, project: project, title: "Add dark mode", item_type: "feature", points: 5, tag_names: %w[frontend urgent])
    end
    let!(:polish) do
      create(:item, project: project, title: "Login page polish", item_type: "idea", status: status_named("Completed"))
    end

    it "returns the paginated envelope with all items by default, newest first" do
      get api_v1_items_path, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(item_ids).to eq([ polish.id, dark_mode.id, docs.id, crash.id ])
      expect(json_body).to include("page" => 1, "per_page" => 25, "total" => 4)
    end

    it "filters by status name case-insensitively" do
      get api_v1_items_path, params: { status: "in PROGRESS" }, headers: auth_headers

      expect(item_ids).to eq([ docs.id ])
    end

    it "filters by item_type" do
      get api_v1_items_path, params: { item_type: "bug" }, headers: auth_headers

      expect(item_ids).to eq([ crash.id ])
    end

    it "maps legacy item_type filters onto their consolidated replacement" do
      get api_v1_items_path, params: { item_type: "enhancement" }, headers: auth_headers

      expect(item_ids).to match_array([ docs.id, dark_mode.id ])
    end

    it "filters by tags with ANY match by default, case-insensitively and without duplicates" do
      get api_v1_items_path, params: { tags: "URGENT,backend" }, headers: auth_headers

      expect(item_ids).to match_array([ crash.id, docs.id, dark_mode.id ])
      expect(json_body["total"]).to eq(3)
    end

    it "filters by tags with tags_match=all" do
      get api_v1_items_path, params: { tags: "urgent,backend", tags_match: "all" }, headers: auth_headers

      expect(item_ids).to eq([ crash.id ])
    end

    it "filters by exact points" do
      get api_v1_items_path, params: { points: 3 }, headers: auth_headers

      expect(item_ids).to eq([ docs.id ])
    end

    it "filters by points_lt" do
      get api_v1_items_path, params: { points_lt: 3 }, headers: auth_headers

      expect(item_ids).to eq([ crash.id ])
    end

    it "filters by points_lte" do
      get api_v1_items_path, params: { points_lte: 3 }, headers: auth_headers

      expect(item_ids).to match_array([ crash.id, docs.id ])
    end

    it "filters by points_gt" do
      get api_v1_items_path, params: { points_gt: 3 }, headers: auth_headers

      expect(item_ids).to eq([ dark_mode.id ])
    end

    it "filters by points_gte" do
      get api_v1_items_path, params: { points_gte: 3 }, headers: auth_headers

      expect(item_ids).to match_array([ docs.id, dark_mode.id ])
    end

    it "searches titles with q, case-insensitively" do
      get api_v1_items_path, params: { q: "LOGIN" }, headers: auth_headers

      expect(item_ids).to match_array([ crash.id, polish.id ])
    end

    it "sorts by points ascending with nulls last" do
      get api_v1_items_path, params: { sort: "points", direction: "asc" }, headers: auth_headers

      expect(item_ids).to eq([ crash.id, docs.id, dark_mode.id, polish.id ])
    end

    it "sorts by title" do
      get api_v1_items_path, params: { sort: "title" }, headers: auth_headers

      expect(item_ids).to eq([ dark_mode.id, crash.id, polish.id, docs.id ])
    end

    it "sorts by strength descending" do
      crash.update_column(:strength, 2.5)
      dark_mode.update_column(:strength, -1.5)

      get api_v1_items_path, params: { sort: "strength", direction: "desc" }, headers: auth_headers

      expect(item_ids.first).to eq(crash.id)
      expect(item_ids.last).to eq(dark_mode.id)
    end

    it "paginates with page and per_page" do
      get api_v1_items_path, params: { sort: "title", per_page: 2, page: 2 }, headers: auth_headers

      expect(item_ids).to eq([ polish.id, docs.id ])
      expect(json_body).to include("page" => 2, "per_page" => 2, "total" => 4)
    end

    it "caps per_page at 100" do
      get api_v1_items_path, params: { per_page: 500 }, headers: auth_headers

      expect(json_body["per_page"]).to eq(100)
    end

    it "filters by project_id on the org-wide index" do
      other_project = api_organization.projects.create!(name: "Side Quest")
      side_item = create(:item, project: other_project, title: "Side task")

      get api_v1_items_path, params: { project_id: other_project.id }, headers: auth_headers

      expect(item_ids).to eq([ side_item.id ])
    end

    it "combines filters" do
      get api_v1_items_path, params: { tags: "urgent", points_gte: 2 }, headers: auth_headers

      expect(item_ids).to eq([ dark_mode.id ])
    end
  end

  describe "GET /api/v1/projects/:project_id/items" do
    it "lists only that project's items in the paginated envelope" do
      item = create(:item, project: project)
      other_project = api_organization.projects.create!(name: "Other")
      create(:item, project: other_project)

      get api_v1_project_items_path(project), headers: auth_headers

      expect(item_ids).to eq([ item.id ])
      expect(json_body).to include("page" => 1, "per_page" => 25, "total" => 1)
    end

    it "404s for another organization's project" do
      foreign_project = create(:api_key).organization.projects.create!(name: "Foreign")

      get api_v1_project_items_path(foreign_project), headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/items/:id" do
    it "returns the full item shape" do
      item = create(:item, project: project, title: "Shaped", points: 2, tag_names: %w[beta alpha],
                           notes: "<p>Hello <strong>world</strong></p>")

      get api_v1_item_path(item), headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body.keys).to match_array(
        %w[id key number title item_type points strength status project tags notes_html notes_text created_at updated_at]
      )
      expect(json_body).to include(
        "id" => item.id,
        "key" => "#{project.slug}-#{item.number}",
        "number" => item.number,
        "title" => "Shaped",
        "item_type" => "feature",
        "points" => 2,
        "strength" => 0.0,
        "tags" => %w[alpha beta],
        "notes_text" => "Hello world"
      )
      expect(json_body["notes_html"]).to include("<strong>world</strong>")
      expect(json_body["status"]).to include("name" => "New", "category" => "open", "position" => 1)
      expect(json_body["project"]).to eq("id" => project.id, "name" => "Tracker", "slug" => project.slug)
    end
  end

  describe "addressing items by key" do
    let!(:item) { create(:item, project: project, title: "Keyed") }

    it "shows an item by its human key, case-insensitively" do
      get api_v1_item_path("trac-#{item.number}"), headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body).to include("id" => item.id, "key" => "TRAC-#{item.number}")
    end

    it "updates and advances by key" do
      patch api_v1_item_path(item.key), headers: auth_headers, params: { item: { points: 5 } }
      expect(json_body["points"]).to eq(5)

      post advance_api_v1_item_path(item.key), headers: auth_headers
      expect(json_body["status"]).to include("name" => "In Progress")
    end

    it "404s for a number that was never assigned" do
      get api_v1_item_path("TRAC-999"), headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "404s for another organization's key" do
      foreign_org = create(:api_key).organization
      foreign_project = foreign_org.projects.create!(name: "Secret Base")
      foreign_item = create(:item, project: foreign_project)

      get api_v1_item_path(foreign_item.key), headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/projects/:project_id/items" do
    it "creates an item with tags and a status resolved by name" do
      post api_v1_project_items_path(project), headers: auth_headers, params: {
        item: {
          title: "Ship the API",
          notes: "<p>Do it <em>soon</em></p>",
          item_type: "feature",
          points: 3,
          status: "in progress",
          tags: %w[api Urgent]
        }
      }

      expect(response).to have_http_status(:created)
      expect(json_body["status"]["name"]).to eq("In Progress")
      expect(json_body["tags"]).to eq(%w[Urgent api].sort)
      expect(json_body["notes_text"]).to eq("Do it soon")

      item = project.items.find(json_body["id"])
      expect(item.points).to eq(3)
      expect(item.tag_names).to match_array(%w[api Urgent])
    end

    it "accepts tags as a comma-separated string" do
      post api_v1_project_items_path(project), headers: auth_headers,
           params: { item: { title: "Comma tags", tags: "alpha, beta" } }

      expect(response).to have_http_status(:created)
      expect(json_body["tags"]).to eq(%w[alpha beta])
    end

    it "defaults to the organization's default status when status is omitted" do
      post api_v1_project_items_path(project), headers: auth_headers,
           params: { item: { title: "Defaulted" } }

      expect(response).to have_http_status(:created)
      expect(json_body["status"]["name"]).to eq("New")
    end

    it "422s on an unknown status name" do
      expect do
        post api_v1_project_items_path(project), headers: auth_headers,
             params: { item: { title: "Nope", status: "Bogus" } }
      end.not_to change(Item, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to eq("error" => "Unknown status: Bogus")
    end

    it "422s with validation errors on a blank title" do
      post api_v1_project_items_path(project), headers: auth_headers, params: { item: { title: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["errors"]).to include("Title can't be blank")
    end

    it "422s when the item param is missing" do
      post api_v1_project_items_path(project), headers: auth_headers, params: {}

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["error"]).to include("item")
    end
  end

  describe "PATCH /api/v1/items/:id" do
    it "updates fields and moves status by name" do
      item = create(:item, project: project, title: "Before")

      patch api_v1_item_path(item), headers: auth_headers,
            params: { item: { title: "After", points: 8, status: "Completed" } }

      expect(response).to have_http_status(:ok)
      expect(item.reload).to have_attributes(title: "After", points: 8)
      expect(item.status.name).to eq("Completed")
    end

    it "replaces the full tag set" do
      item = create(:item, project: project, tag_names: %w[old stale])

      patch api_v1_item_path(item), headers: auth_headers, params: { item: { tags: %w[fresh new] } }

      expect(response).to have_http_status(:ok)
      expect(json_body["tags"]).to eq(%w[fresh new])
      expect(item.reload.tag_names).to match_array(%w[fresh new])
    end

    it "leaves tags untouched when the tags key is absent" do
      item = create(:item, project: project, tag_names: %w[keeper])

      patch api_v1_item_path(item), headers: auth_headers, params: { item: { title: "Renamed" } }

      expect(item.reload.tag_names).to eq(%w[keeper])
    end

    it "422s on an unknown status name without changing the item" do
      item = create(:item, project: project, title: "Stable")

      patch api_v1_item_path(item), headers: auth_headers, params: { item: { title: "Changed", status: "Bogus" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to eq("error" => "Unknown status: Bogus")
      expect(item.reload.title).to eq("Stable")
    end
  end

  describe "POST /api/v1/items/:id/advance" do
    it "walks the item through the ordered statuses and 422s at the end" do
      item = create(:item, project: project)
      expect(item.status.name).to eq("New")

      post advance_api_v1_item_path(item), headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_body["status"]["name"]).to eq("In Progress")

      post advance_api_v1_item_path(item), headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_body["status"]["name"]).to eq("Needs Verification")

      post advance_api_v1_item_path(item), headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_body["status"]["name"]).to eq("Completed")

      post advance_api_v1_item_path(item), headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to eq("error" => "Item is already in the final status")
      expect(item.reload.status.name).to eq("Completed")
    end
  end

  describe "DELETE /api/v1/items/:id" do
    it "destroys the item" do
      item = create(:item, project: project)

      expect do
        delete api_v1_item_path(item), headers: auth_headers
      end.to change(Item, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "cross-organization isolation" do
    let(:foreign_item) { create(:item, project: project, title: "Foreign") }
    let(:other_key) { create(:api_key) }

    it "hides another organization's items from the org-wide index" do
      foreign_item

      get api_v1_items_path, headers: auth_headers(other_key)

      expect(json_body["items"]).to eq([])
    end

    it "404s on show, update, destroy, and advance" do
      get api_v1_item_path(foreign_item), headers: auth_headers(other_key)
      expect(response).to have_http_status(:not_found)

      patch api_v1_item_path(foreign_item), params: { item: { title: "Hacked" } }, headers: auth_headers(other_key)
      expect(response).to have_http_status(:not_found)

      delete api_v1_item_path(foreign_item), headers: auth_headers(other_key)
      expect(response).to have_http_status(:not_found)

      post advance_api_v1_item_path(foreign_item), headers: auth_headers(other_key)
      expect(response).to have_http_status(:not_found)

      expect(foreign_item.reload).to have_attributes(title: "Foreign")
      expect(foreign_item.status.name).to eq("New")
    end

    it "404s when creating an item under another organization's project" do
      expect do
        post api_v1_project_items_path(project), params: { item: { title: "Sneaky" } }, headers: auth_headers(other_key)
      end.not_to change(Item, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
