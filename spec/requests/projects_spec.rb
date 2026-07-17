require "rails_helper"

RSpec.describe "Projects", type: :request do
  context "when signed in" do
    before { register_passkey(username: "owner") }

    let(:organization) { User.find_by(username: "owner").default_organization }

    it "lists the organization's projects" do
      project = organization.projects.create!(name: "Website")

      get projects_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Website")
    end

    it "creates a project in the current organization" do
      expect do
        post projects_path, params: { project: { name: "New Project" } }
      end.to change(organization.projects, :count).by(1)

      expect(response).to redirect_to(Project.last)
    end

    it "renders the create flash as a Toasts island (props JSON is HTML-escaped)" do
      post projects_path, params: { project: { name: "Flashy" } }
      follow_redirect!

      expect(response.body).to include('data-svelte-component="Toasts"')
      expect(response.body).to include("&quot;type&quot;:&quot;notice&quot;")
      expect(response.body).to include("&quot;message&quot;:&quot;Project created.&quot;")
    end

    it "shows a project" do
      project = organization.projects.create!(name: "Docs")

      get project_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Docs")
    end

    it "renders the board as a Svelte island with items and statuses in its props" do
      project = organization.projects.create!(name: "Docs")
      create(:item, project: project, title: "Sortable", points: 3)

      get project_path(project)

      expect(response.body).to include('data-svelte-component="Board"')
      expect(response.body).to include("&quot;title&quot;:&quot;Sortable&quot;")
      expect(response.body).to include("&quot;points&quot;:3")
      expect(response.body).to include("&quot;statuses&quot;")
    end

    it "updates a project" do
      project = organization.projects.create!(name: "Old")

      patch project_path(project), params: { project: { name: "Renamed" } }
      expect(response).to redirect_to(project)
      expect(project.reload.name).to eq("Renamed")
    end

    it "destroys a project" do
      project = organization.projects.create!(name: "Trash")

      expect do
        delete project_path(project)
      end.to change(organization.projects, :count).by(-1)
    end

    it "creates an item under a project defaulting to the first open status" do
      project = organization.projects.create!(name: "App")

      expect do
        post project_items_path(project), params: { item: { title: "Fix bug", item_type: "bug" } }
      end.to change(project.items, :count).by(1)

      item = project.items.last
      expect(item.status).to eq(organization.default_status)
    end
  end

  context "when signed out" do
    it "redirects to the login page" do
      get projects_path
      expect(response).to redirect_to(login_path)
    end
  end
end
