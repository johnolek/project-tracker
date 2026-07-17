require "rails_helper"

RSpec.describe "Comments", type: :request do
  context "when signed in" do
    before { register_passkey(username: "owner") }

    let(:owner) { User.find_by(username: "owner") }
    let(:organization) { owner.default_organization }
    let(:project) { organization.projects.create!(name: "Board") }
    let(:item) { create(:item, project: project) }

    describe "POST create" do
      it "adds a web-sourced comment authored by the current user" do
        expect do
          post project_item_comments_path(project, item), params: { comment: { body: "Looks good" } }
        end.to change(item.comments, :count).by(1)

        comment = item.comments.last
        expect(comment.user).to eq(owner)
        expect(comment.source).to eq("web")
        expect(comment.body.to_plain_text).to eq("Looks good")
        expect(response).to redirect_to(project_item_path(project, item))
      end

      it "redirects back without creating a comment when the body is blank" do
        post project_item_comments_path(project, item), params: { comment: { body: "" } }

        expect(response).to redirect_to(project_item_path(project, item))
        expect(item.comments).to be_empty
      end

      it "404s for an item in another organization's project" do
        foreign_project = create(:project)
        foreign_item = create(:item, project: foreign_project)

        post project_item_comments_path(foreign_project, foreign_item), params: { comment: { body: "hi" } }

        expect(response).to have_http_status(:not_found)
        expect(foreign_item.comments).to be_empty
      end
    end

    describe "the thread on the item detail page" do
      it "renders comments chronologically and badges API-sourced ones" do
        create(:comment, item: item, body: "Human note", source: "web")
        create(:comment, item: item, body: "Robot note", source: "api")

        get project_item_path(project, item)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Human note")
        expect(response.body).to include("Robot note")
        expect(response.body).to include("🤖 API")
        expect(response.body.index("Human note")).to be < response.body.index("Robot note")
      end
    end
  end

  context "when signed out" do
    it "redirects to the login page" do
      project = create(:project)
      item = create(:item, project: project)

      post project_item_comments_path(project, item), params: { comment: { body: "hi" } }

      expect(response).to redirect_to(login_path)
    end
  end
end
