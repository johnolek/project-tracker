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

RSpec.describe "New item form", type: :request do
  before { register_passkey(username: "owner") }

  let(:organization) { User.find_by(username: "owner").default_organization }
  let(:project) { organization.projects.create!(name: "Board") }
  let(:in_progress) { organization.statuses.find_by!(category: "in_progress") }

  def selected_status_id(body)
    Nokogiri::HTML(body).at_css('select[name="item[status_id]"] option[selected]')&.attr("value")
  end

  it "preselects the status named by status_id when it belongs to the org" do
    get new_project_item_path(project, status_id: in_progress.id)

    expect(response).to have_http_status(:ok)
    expect(selected_status_id(response.body)).to eq(in_progress.id.to_s)
  end

  it "falls back to the default status for a status_id from another org" do
    foreign_status = create(:status, category: "open")

    get new_project_item_path(project, status_id: foreign_status.id)

    expect(response).to have_http_status(:ok)
    expect(selected_status_id(response.body)).to eq(organization.default_status.id.to_s)
    expect(response.body).not_to include(%(value="#{foreign_status.id}"))
  end

  it "falls back to the default status when no status_id is given" do
    get new_project_item_path(project)

    expect(selected_status_id(response.body)).to eq(organization.default_status.id.to_s)
  end
end

RSpec.describe "Item creation", type: :request do
  before { register_passkey(username: "owner") }

  let(:organization) { User.find_by(username: "owner").default_organization }
  let(:project) { organization.projects.create!(name: "Board") }
  let(:in_progress) { organization.statuses.find_by!(category: "in_progress") }

  it "creates the item in the status passed through item params" do
    expect {
      post project_items_path(project),
           params: { item: { title: "Ship it", item_type: "task", status_id: in_progress.id } }
    }.to change(Item, :count).by(1)

    item = Item.order(:created_at).last
    expect(response).to redirect_to(project_item_path(project, item))
    expect(item.status).to eq(in_progress)
  end

  it "uses the org default status when item params omit status_id" do
    post project_items_path(project), params: { item: { title: "Later", item_type: "task" } }

    expect(Item.order(:created_at).last.status).to eq(organization.default_status)
  end
end
