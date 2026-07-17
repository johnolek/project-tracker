require "rails_helper"

RSpec.describe "Comparisons", type: :request do
  context "when signed in" do
    before { register_passkey(username: "owner") }

    let(:organization) { User.find_by(username: "owner").default_organization }
    let(:project) { organization.projects.create!(name: "Tracker") }

    describe "GET /projects/:id/prioritize" do
      it "shows two distinct open items from the project to compare" do
        first = create(:item, project: project, title: "First matters")
        second = create(:item, project: project, title: "Second matters")

        get prioritize_project_path(project)

        expect(response).to have_http_status(:ok)
        expect([ first, second ].map(&:title)).to all(satisfy { |title| response.body.include?(title) })
      end

      it "never pairs items from another project" do
        create(:item, project: project, title: "Mine one")
        other_project = organization.projects.create!(name: "Elsewhere")
        create(:item, project: other_project, title: "Neighbor item")

        get prioritize_project_path(project)

        expect(response.body).not_to include("Neighbor item")
        expect(response.body).to include("at least two open items")
      end

      it "404s for another organization's project" do
        foreign_project = create(:project)

        get prioritize_project_path(foreign_project)

        expect(response).to have_http_status(:not_found)
      end

      it "shows a friendly empty state with fewer than two open items" do
        create(:item, project: project, title: "Lonely")

        get prioritize_project_path(project)

        expect(response.body).to include("at least two open items")
      end

      it "excludes done items from the pair" do
        create(:item, project: project, title: "Open work")
        done_status = organization.statuses.find_by(category: "done")
        create(:item, project: project, title: "Finished work", status: done_status)

        get prioritize_project_path(project)

        expect(response.body).to include("at least two open items")
      end

      it "serves the current pair and count as JSON for skip refreshes" do
        create(:item, project: project, title: "First matters")
        create(:item, project: project, title: "Second matters")

        get prioritize_project_path(project, format: :json)

        payload = response.parsed_body
        expect(payload["pair"].map { |item| item["title"] }).to match_array([ "First matters", "Second matters" ])
        expect(payload["count"]).to eq(0)
      end
    end

    describe "POST /projects/:project_id/comparisons" do
      let!(:item_a) { create(:item, project: project, title: "Item A") }
      let!(:item_b) { create(:item, project: project, title: "Item B") }

      it "creates the comparison and persists recomputed strengths" do
        expect do
          post project_comparisons_path(project), params: { item_a_id: item_a.id, item_b_id: item_b.id, outcome: "a_wins" }
        end.to change(Comparison, :count).by(1)

        expect(response).to redirect_to(prioritize_project_path(project))
        expect(item_a.reload.strength).to be > item_b.reload.strength
      end

      it "records a draw" do
        post project_comparisons_path(project), params: { item_a_id: item_a.id, item_b_id: item_b.id, outcome: "draw" }

        expect(Comparison.last.outcome).to eq("draw")
        expect(item_a.reload.strength).to be_within(1e-9).of(item_b.reload.strength)
      end

      it "returns the next pair and count as JSON so the island continues without a reload" do
        post project_comparisons_path(project),
             params: { item_a_id: item_a.id, item_b_id: item_b.id, outcome: "a_wins" },
             as: :json

        expect(response).to have_http_status(:ok)
        payload = response.parsed_body
        expect(payload["count"]).to eq(1)
        expect(payload["pair"].map { |item| item["title"] }).to match_array([ "Item A", "Item B" ])
      end

      it "returns validation errors as JSON" do
        post project_comparisons_path(project),
             params: { item_a_id: item_a.id, item_b_id: item_a.id, outcome: "a_wins" },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "404s when an item belongs to a different project" do
        other_project = organization.projects.create!(name: "Elsewhere")
        stray = create(:item, project: other_project, title: "Stray")

        expect do
          post project_comparisons_path(project), params: { item_a_id: item_a.id, item_b_id: stray.id, outcome: "a_wins" }
        end.not_to change(Comparison, :count)

        expect(response).to have_http_status(:not_found)
      end

      it "404s for another organization's project" do
        foreign_project = create(:project)
        foreign_item = create(:item, project: foreign_project)
        other_foreign_item = create(:item, project: foreign_project)

        expect do
          post project_comparisons_path(foreign_project),
               params: { item_a_id: foreign_item.id, item_b_id: other_foreign_item.id, outcome: "a_wins" }
        end.not_to change(Comparison, :count)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context "when signed out" do
    let(:project) { create(:project) }

    it "redirects the prioritize page to login" do
      get prioritize_project_path(project)
      expect(response).to redirect_to(login_path)
    end

    it "redirects a comparison POST to login" do
      post project_comparisons_path(project), params: { item_a_id: 1, item_b_id: 2, outcome: "a_wins" }
      expect(response).to redirect_to(login_path)
    end
  end
end
