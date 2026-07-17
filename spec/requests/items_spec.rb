require "rails_helper"

RSpec.describe "Item moves", type: :request do
  context "when signed in" do
    before { register_passkey(username: "owner") }

    let(:organization) { User.find_by(username: "owner").default_organization }
    let(:project) { organization.projects.create!(name: "Board") }
    let(:in_progress) { organization.statuses.find_by!(category: "in_progress") }

    it "moves an item to another status within the organization" do
      item = create(:item, project: project)

      patch move_project_item_path(project, item), params: { status_id: in_progress.id }

      expect(response).to have_http_status(:no_content)
      expect(item.reload.status).to eq(in_progress)
    end

    it "404s for an item in another organization's project" do
      foreign_project = create(:project)
      foreign_item = create(:item, project: foreign_project)

      patch move_project_item_path(foreign_project, foreign_item), params: { status_id: in_progress.id }

      expect(response).to have_http_status(:not_found)
    end

    it "404s for a status belonging to another organization, leaving the item unchanged" do
      item = create(:item, project: project)
      original_status = item.status
      foreign_status = create(:status, category: "open")

      patch move_project_item_path(project, item), params: { status_id: foreign_status.id }

      expect(response).to have_http_status(:not_found)
      expect(item.reload.status).to eq(original_status)
    end
  end

  context "when signed out" do
    it "redirects to the login page" do
      project = create(:project)
      item = create(:item, project: project)
      status = project.organization.statuses.find_by!(category: "in_progress")

      patch move_project_item_path(project, item), params: { status_id: status.id }

      expect(response).to redirect_to(login_path)
    end
  end
end
