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

  describe "the Jira-style item detail page" do
    before { register_passkey(username: "owner") }

    let(:organization) { User.find_by(username: "owner").default_organization }
    let(:project) { organization.projects.create!(name: "Board") }

    it "renders a breadcrumb and mounts the inline-editing islands with their props" do
      item = create(:item, project: project, item_type: "bug", points: 5)
      item.update!(tag_names: [ "urgent" ])

      get project_item_path(project, item)

      expect(response).to have_http_status(:ok)

      breadcrumb = Nokogiri::HTML(response.body).at_css("nav.breadcrumb")
      expect(breadcrumb).to be_present
      expect(breadcrumb.at_css("a[href='#{projects_path}']")).to be_present
      expect(breadcrumb.at_css("a[href='#{project_path(project)}']").text).to eq("Board")
      expect(breadcrumb.at_css("li.is-active").text).to include(item.key)

      document = Nokogiri::HTML(response.body)
      expect(document.at_css("title").text).to eq("Board | #{item.key}")

      editor = document.at_css('[data-svelte-component="ItemEditor"]')
      expect(editor).to be_present
      editor_props = JSON.parse(editor["data-props"])
      expect(editor_props["item"]["title"]).to eq(item.title)
      expect(editor_props["updateUrl"]).to eq(project_item_path(project, item))

      sidebar = document.at_css('[data-svelte-component="ItemSidebar"]')
      expect(sidebar).to be_present
      sidebar_props = JSON.parse(sidebar["data-props"])
      expect(sidebar_props["item"]["points"]).to eq(5)
      expect(sidebar_props["item"]["tags"]).to eq([ "urgent" ])
      expect(sidebar_props["pointOptions"]).to eq([ 1, 2, 3, 5, 8, 13 ])
      expect(sidebar_props["statuses"].map { |status| status["name"] }).to include(item.status.name)
      expect(sidebar_props["allTags"]).to include("urgent")
    end

    it "links straight into prioritize mode with the item pinned, unless the item is done" do
      item = create(:item, project: project)

      get project_item_path(project, item)
      expect(response.body).to include(prioritize_project_path(project, pinned_item_id: item.id))

      done = organization.statuses.find_by!(category: "done")
      item.update!(status: done)

      get project_item_path(project, item)
      expect(response.body).not_to include("Prioritize this")
    end
  end

  describe "PATCH update from the inline-editing islands" do
    before { register_passkey(username: "owner") }

    let(:organization) { User.find_by(username: "owner").default_organization }
    let(:project) { organization.projects.create!(name: "Board") }
    let(:in_progress) { organization.statuses.find_by!(category: "in_progress") }

    it "changes only the status and redirects back to the item (form fallback)" do
      item = create(:item, project: project)

      patch project_item_path(project, item), params: { item: { status_id: in_progress.id } }

      expect(response).to redirect_to(project_item_path(project, item))
      expect(item.reload.status).to eq(in_progress)
    end

    it "saves inline JSON edits and returns the fresh detail payload" do
      item = create(:item, project: project, title: "Old title")

      patch project_item_path(project, item),
            params: { item: { title: "New title", points: 8, notes: "<p>Inline notes</p>" } },
            as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload["title"]).to eq("New title")
      expect(payload["points"]).to eq(8)
      expect(payload["notes_html"]).to include("Inline notes")
      expect(item.reload.title).to eq("New title")
    end

    it "replaces the tag set from a JSON array and echoes it back sorted" do
      item = create(:item, project: project)
      item.update!(tag_names: [ "old" ])

      patch project_item_path(project, item),
            params: { item: { tag_names: [ "urgent", "board" ] } },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["tags"]).to match_array(%w[urgent board])
      expect(item.reload.tag_names).to match_array(%w[urgent board])
    end

    it "returns validation errors as JSON" do
      item = create(:item, project: project)

      patch project_item_path(project, item), params: { item: { title: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to be_present
      expect(item.reload.title).to be_present
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
           params: { item: { title: "Ship it", item_type: "feature", status_id: in_progress.id } }
    }.to change(Item, :count).by(1)

    item = Item.order(:created_at).last
    expect(response).to redirect_to(project_item_path(project, item))
    expect(item.status).to eq(in_progress)
  end

  it "uses the org default status when item params omit status_id" do
    post project_items_path(project), params: { item: { title: "Later", item_type: "feature" } }

    expect(Item.order(:created_at).last.status).to eq(organization.default_status)
  end
end
