require "rails_helper"

RSpec.describe "API v1 projects", type: :request do
  describe "GET /api/v1/projects" do
    it "lists the organization's projects ordered by name" do
      api_organization.projects.create!(name: "Zebra")
      api_organization.projects.create!(name: "Alpha")

      get api_v1_projects_path, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body["projects"].map { |project| project["name"] }).to eq(%w[Alpha Zebra])
    end
  end

  describe "GET /api/v1/projects/:id" do
    it "shows a project" do
      project = api_organization.projects.create!(name: "Docs")

      get api_v1_project_path(project), headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body).to include("id" => project.id, "name" => "Docs", "slug" => "DOCS")
      expect(json_body.keys).to match_array(%w[id name slug created_at updated_at])
    end
  end

  describe "POST /api/v1/projects" do
    it "creates a project in the key's organization" do
      expect do
        post api_v1_projects_path, params: { project: { name: "New API Project" } }, headers: auth_headers
      end.to change(api_organization.projects, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_body["name"]).to eq("New API Project")
      expect(json_body["slug"]).to eq("NEW")
    end

    it "accepts an explicit slug" do
      post api_v1_projects_path, params: { project: { name: "Website Redesign", slug: "web" } }, headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(json_body["slug"]).to eq("WEB")
    end

    it "returns validation errors for a blank name" do
      post api_v1_projects_path, params: { project: { name: "" } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["errors"]).to include("Name can't be blank")
    end

    it "returns 422 when the project param is missing" do
      post api_v1_projects_path, params: {}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["error"]).to include("project")
    end
  end

  describe "PATCH /api/v1/projects/:id" do
    it "renames a project" do
      project = api_organization.projects.create!(name: "Old")

      patch api_v1_project_path(project), params: { project: { name: "Renamed" } }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(project.reload.name).to eq("Renamed")
    end

    it "changes the slug while the project has no items" do
      project = api_organization.projects.create!(name: "Old")

      patch api_v1_project_path(project), params: { project: { slug: "FRESH" } }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(project.reload.slug).to eq("FRESH")
    end

    it "changes the slug even when the project has items, retiring the old one" do
      project = api_organization.projects.create!(name: "Old", slug: "OLD")
      create(:item, project: project)

      patch api_v1_project_path(project), params: { project: { slug: "NEW" } }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(project.reload.slug).to eq("NEW")
      expect(project.slug_aliases.pluck(:slug)).to include("OLD")
    end
  end

  describe "retired slugs" do
    it "resolves a retired slug and 301s to the current one" do
      project = api_organization.projects.create!(name: "Old", slug: "OLD")
      project.update!(slug: "NEW")

      get api_v1_project_path("OLD"), headers: auth_headers

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(api_v1_project_path("NEW"))
    end

    it "still resolves an item by its old key after a slug change" do
      project = api_organization.projects.create!(name: "Old", slug: "OLD")
      item = create(:item, project: project)
      old_key = item.key
      project.update!(slug: "NEW")

      get api_v1_item_path(old_key), headers: auth_headers

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(api_v1_item_path(item.reload.key))
    end
  end

  describe "DELETE /api/v1/projects/:id" do
    it "destroys a project" do
      project = api_organization.projects.create!(name: "Trash")

      expect do
        delete api_v1_project_path(project), headers: auth_headers
      end.to change(api_organization.projects, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "cross-organization isolation" do
    let(:foreign_project) { api_organization.projects.create!(name: "Secret") }
    let(:other_key) { create(:api_key) }

    it "hides another organization's projects from the index" do
      foreign_project

      get api_v1_projects_path, headers: auth_headers(other_key)

      expect(json_body["projects"]).to eq([])
    end

    it "404s on show, update, and destroy of another organization's project" do
      get api_v1_project_path(foreign_project), headers: auth_headers(other_key)
      expect(response).to have_http_status(:not_found)
      expect(json_body).to eq("error" => "Not found")

      patch api_v1_project_path(foreign_project), params: { project: { name: "Hacked" } }, headers: auth_headers(other_key)
      expect(response).to have_http_status(:not_found)
      expect(foreign_project.reload.name).to eq("Secret")

      delete api_v1_project_path(foreign_project), headers: auth_headers(other_key)
      expect(response).to have_http_status(:not_found)
      expect(Project.exists?(foreign_project.id)).to be(true)
    end
  end
end
