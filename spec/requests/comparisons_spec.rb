require "rails_helper"

RSpec.describe "Comparisons", type: :request do
  context "when signed in" do
    before { register_passkey(username: "owner") }

    let(:organization) { User.find_by(username: "owner").default_organization }
    let(:project) { organization.projects.create!(name: "Tracker") }

    describe "GET /prioritize" do
      it "shows two distinct open items from the organization to compare" do
        first = create(:item, project: project, title: "First matters")
        second = create(:item, project: project, title: "Second matters")

        get prioritize_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("First matters")
        expect(response.body).to include("Second matters")
        expect([ first, second ].map(&:title)).to all(satisfy { |title| response.body.include?(title) })
      end

      it "never surfaces another organization's items" do
        create(:item, project: project, title: "Mine one")
        create(:item, project: project, title: "Mine two")
        foreign_item = create(:item, title: "Foreign secret")

        get prioritize_path

        expect(response.body).not_to include(foreign_item.title)
      end

      it "shows a friendly empty state with fewer than two open items" do
        create(:item, project: project, title: "Lonely")

        get prioritize_path

        expect(response.body).to include("at least two open items")
      end

      it "excludes done items from the pair" do
        create(:item, project: project, title: "Open work")
        done_status = organization.statuses.find_by(category: "done")
        create(:item, project: project, title: "Finished work", status: done_status)

        get prioritize_path

        expect(response.body).to include("at least two open items")
      end
    end

    describe "POST /comparisons" do
      let!(:item_a) { create(:item, project: project, title: "Item A") }
      let!(:item_b) { create(:item, project: project, title: "Item B") }

      it "creates the comparison and persists recomputed strengths" do
        expect do
          post comparisons_path, params: { item_a_id: item_a.id, item_b_id: item_b.id, outcome: "a_wins" }
        end.to change(Comparison, :count).by(1)

        expect(response).to redirect_to(prioritize_path)
        expect(item_a.reload.strength).to be > item_b.reload.strength
      end

      it "records a draw" do
        post comparisons_path, params: { item_a_id: item_a.id, item_b_id: item_b.id, outcome: "draw" }

        expect(Comparison.last.outcome).to eq("draw")
        expect(item_a.reload.strength).to be_within(1e-9).of(item_b.reload.strength)
      end

      it "404s when an item belongs to another organization" do
        foreign_item = create(:item, title: "Foreign")

        expect do
          post comparisons_path, params: { item_a_id: item_a.id, item_b_id: foreign_item.id, outcome: "a_wins" }
        end.not_to change(Comparison, :count)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context "when signed out" do
    it "redirects the prioritize page to login" do
      get prioritize_path
      expect(response).to redirect_to(login_path)
    end

    it "redirects a comparison POST to login" do
      post comparisons_path, params: { item_a_id: 1, item_b_id: 2, outcome: "a_wins" }
      expect(response).to redirect_to(login_path)
    end
  end
end
