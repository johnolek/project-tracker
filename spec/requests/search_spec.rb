require "rails_helper"

RSpec.describe "Search", type: :request do
  context "when signed out" do
    it "redirects to the login page" do
      get search_path, params: { q: "anything" }
      expect(response).to redirect_to(login_path)
    end
  end

  context "when signed in" do
    before { register_passkey(username: "owner") }

    let(:organization) { User.find_by(username: "owner").default_organization }
    let(:project) { organization.projects.create!(name: "Website") }

    it "finds items by case-insensitive title substring" do
      match = create(:item, project: project, title: "Fix Login Bug")
      create(:item, project: project, title: "Dashboard redesign")

      get search_path, params: { q: "login" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fix Login Bug")
      expect(response.body).not_to include("Dashboard redesign")
      expect(response.body).to include(project_item_path(project, match))
    end

    it "finds an item by its key, case-insensitively (e.g. proj-47)" do
      match = create(:item, project: project, title: "Unrelated title")
      other = create(:item, project: project, title: "Also unrelated")

      get search_path, params: { q: match.key.downcase }

      expect(response.body).to include(project_item_path(project, match))
      expect(response.body).not_to include(project_item_path(project, other))
    end

    it "matches a partial key such as the project slug" do
      match = create(:item, project: project, title: "Nothing matching in the title")

      get search_path, params: { q: project.slug.downcase }

      expect(response.body).to include(project_item_path(project, match))
    end

    it "never returns items belonging to another organization" do
      mine = create(:item, project: project, title: "Login here")

      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      create(:item, project: other_project, title: "Login elsewhere")

      get search_path, params: { q: "login" }

      expect(response.body).to include("Login here")
      expect(response.body).not_to include("Login elsewhere")
      expect(response.body).to include(project_item_path(project, mine))
    end

    it "finds projects by case-insensitive name substring" do
      matching = organization.projects.create!(name: "Garden Redesign")
      organization.projects.create!(name: "Unrelated")

      get search_path, params: { q: "garden" }

      expect(response.body).to include("Garden Redesign")
      expect(response.body).to include(project_path(matching))
      expect(response.body).not_to include("Unrelated")
    end

    it "never returns projects belonging to another organization" do
      other_org = create(:organization)
      create(:project, organization: other_org, name: "Garden Elsewhere")

      get search_path, params: { q: "garden" }

      expect(response.body).not_to include("Garden Elsewhere")
    end

    it "treats LIKE metacharacters in the query literally" do
      literal = create(:item, project: project, title: "draft_final")
      create(:item, project: project, title: "draftXfinal")

      get search_path, params: { q: "draft_final" }

      expect(response.body).to include("draft_final")
      expect(response.body).not_to include("draftXfinal")
      expect(response.body).to include(project_item_path(project, literal))
    end

    it "renders fine with a blank query" do
      create(:item, project: project, title: "Some item")

      get search_path, params: { q: "   " }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Some item")
    end
  end
end
