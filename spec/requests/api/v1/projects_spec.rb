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
      expect(json_body).to include("id" => project.id, "name" => "Docs")
      expect(json_body.keys).to match_array(%w[id name created_at updated_at])
    end
  end

  describe "POST /api/v1/projects" do
    it "creates a project in the key's organization" do
      expect do
        post api_v1_projects_path, params: { project: { name: "New API Project" } }, headers: auth_headers
      end.to change(api_organization.projects, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_body["name"]).to eq("New API Project")
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
