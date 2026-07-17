require "rails_helper"

RSpec.describe "Priorities", type: :request do
  context "when signed in" do
    before { register_passkey(username: "owner") }

    let(:organization) { User.find_by(username: "owner").default_organization }
    let(:project) { organization.projects.create!(name: "Tracker") }

    it "lists open items ordered by strength descending" do
      low = create(:item, project: project, title: "Low priority")
      high = create(:item, project: project, title: "High priority")
      low.update_column(:strength, -1.0)
      high.update_column(:strength, 2.0)

      get priorities_path

      expect(response).to have_http_status(:ok)
      expect(response.body.index("High priority")).to be < response.body.index("Low priority")
    end

    it "excludes done items" do
      create(:item, project: project, title: "Still open")
      done_status = organization.statuses.find_by(category: "done")
      create(:item, project: project, title: "All done", status: done_status)

      get priorities_path

      expect(response.body).to include("Still open")
      expect(response.body).not_to include("All done")
    end

    it "shows how many comparisons each item has been in" do
      winner = create(:item, project: project, title: "Compared item")
      loser = create(:item, project: project, title: "Other item")
      create(:comparison, item_a: winner, item_b: loser, outcome: "a_wins", user: create(:user))

      get priorities_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Compared item")
    end
  end

  context "when signed out" do
    it "redirects to login" do
      get priorities_path
      expect(response).to redirect_to(login_path)
    end
  end
end
