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

    it "walks ancestors in the breadcrumb and lists sub-items with an add button" do
      root = create(:item, project: project, title: "Epic")
      middle = create(:item, project: project, parent: root)
      leaf = create(:item, project: project, parent: middle, title: "Leaf task")

      get project_item_path(project, leaf)

      breadcrumb = Nokogiri::HTML(response.body).at_css("nav.breadcrumb")
      expect(breadcrumb.css("a").map(&:text)).to include(root.key, middle.key)

      get project_item_path(project, middle)

      document = Nokogiri::HTML(response.body)
      sub_items = document.at_css(".sub-items")
      expect(sub_items.text).to include(leaf.key, "Leaf task")
      expect(response.body).to include(new_project_item_path(project, parent_id: middle.id))

      sidebar_props = JSON.parse(document.at_css('[data-svelte-component="ItemSidebar"]')["data-props"])
      expect(sidebar_props["item"]["parent_id"]).to eq(root.id)
      expect(sidebar_props["parentOptions"].map { |option| option["id"] }).to contain_exactly(root.id)
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

    it "sets and clears the parent from the sidebar select" do
      epic = create(:item, project: project)
      item = create(:item, project: project)

      patch project_item_path(project, item), params: { item: { parent_id: epic.id } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["parent_id"]).to eq(epic.id)
      expect(item.reload.parent).to eq(epic)

      patch project_item_path(project, item), params: { item: { parent_id: nil } }, as: :json
      expect(item.reload.parent).to be_nil
    end

    it "rejects a cycle-creating parent as a JSON validation error" do
      epic = create(:item, project: project)
      child = create(:item, project: project, parent: epic)

      patch project_item_path(project, epic), params: { item: { parent_id: child.id } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(epic.reload.parent).to be_nil
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
    expect(item.provenance).to eq("user_created")
  end

  it "uses the org default status when item params omit status_id" do
    post project_items_path(project), params: { item: { title: "Later", item_type: "feature" } }

    expect(Item.order(:created_at).last.status).to eq(organization.default_status)
  end

  it "flashes a sticky Add another toast preserving status and parent (PROJ-67)" do
    parent = create(:item, project: project)

    post project_items_path(project),
         params: { item: { title: "Ship it", item_type: "feature", status_id: in_progress.id, parent_id: parent.id } }
    follow_redirect!

    props = Nokogiri::HTML(response.body).at_css('[data-svelte-component="Toasts"]')["data-props"]
    toast = JSON.parse(props).fetch("toasts").sole

    expect(toast).to include("type" => "notice", "message" => "Item created.", "sticky" => true)
    expect(toast.dig("action", "label")).to eq("Add another")
    expect(toast.dig("action", "href")).to eq(new_project_item_path(project, parent_id: parent.id, status_id: in_progress.id))
  end
end

RSpec.describe "Item review flag (PROJ-65)", type: :request do
  before { register_passkey(username: "owner") }

  let(:organization) { User.find_by(username: "owner").default_organization }
  let(:project) { organization.projects.create!(name: "Board") }

  describe "PATCH review" do
    it "flags the item with a note and echoes the detail payload as JSON" do
      item = create(:item, project: project, title: "Fuzzy")

      patch review_project_item_path(project, item), params: { review_note: "needs more details" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("needs_review" => true, "review_note" => "needs more details")
      expect(item.reload).to be_needs_review
    end

    it "allows a blank note" do
      item = create(:item, project: project)

      patch review_project_item_path(project, item), params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(item.reload).to be_needs_review
      expect(item.review_note).to be_nil
    end
  end

  describe "DELETE review (unreview)" do
    it "clears the flag and note" do
      item = create(:item, project: project)
      item.flag_for_review!(note: "later")

      delete review_project_item_path(project, item), as: :json

      expect(response).to have_http_status(:ok)
      expect(item.reload).not_to be_needs_review
      expect(item.review_note).to be_nil
    end
  end

  describe "the item detail page" do
    it "mounts the ReviewBanner island with the note when flagged" do
      item = create(:item, project: project, title: "Fuzzy")
      item.flag_for_review!(note: "needs more details")

      get project_item_path(project, item)

      island = Nokogiri::HTML(response.body).at_css('[data-svelte-component="ReviewBanner"]')
      props = JSON.parse(island["data-props"])
      expect(props["note"]).to eq("needs more details")
      expect(props["reviewUrl"]).to eq(review_project_item_path(project, item))
    end

    it "mounts no review banner when the item is not flagged" do
      item = create(:item, project: project, title: "Clear")

      get project_item_path(project, item)

      expect(Nokogiri::HTML(response.body).at_css('[data-svelte-component="ReviewBanner"]')).to be_nil
    end
  end

  # The review queue is the board filtered to flagged items (?review=1, read by
  # the Board island); the server's job is shipping the flag + note in its props.
  describe "the board's review data" do
    it "ships needs_review and review_note in the Board island props" do
      flagged = create(:item, project: project, title: "Fuzzy")
      flagged.flag_for_review!(note: "ambiguous title")
      create(:item, project: project, title: "Plain")

      get project_path(project)

      island = Nokogiri::HTML(response.body).at_css('[data-svelte-component="Board"]')
      board_items = JSON.parse(island["data-props"])["items"]
      expect(board_items.find { |item| item["id"] == flagged.id })
        .to include("needs_review" => true, "review_note" => "ambiguous title")
      expect(board_items.find { |item| item["title"] == "Plain" })
        .to include("needs_review" => false, "review_note" => nil)
    end
  end

  describe "editing the note (PATCH review on an already-flagged item)" do
    it "updates the note while keeping the original flag time" do
      item = create(:item, project: project)
      item.flag_for_review!(note: "first thought")
      original_time = item.reload.review_requested_at

      travel 1.hour do
        patch review_project_item_path(project, item), params: { review_note: "sharper thought" }, as: :json
      end

      expect(response).to have_http_status(:ok)
      expect(item.reload.review_note).to eq("sharper thought")
      expect(item.review_requested_at).to eq(original_time)
    end
  end

  describe "the priorities list" do
    it "marks flagged items with a review chip" do
      flagged = create(:item, project: project, title: "Fuzzy ranked")
      flagged.flag_for_review!(note: "may already be done")
      create(:item, project: project, title: "Plain ranked")

      get priorities_project_path(project)

      row = Nokogiri::HTML(response.body).css("tr").find { |tr| tr.text.include?("Fuzzy ranked") }
      expect(row.text).to include("review")
      plain_row = Nokogiri::HTML(response.body).css("tr").find { |tr| tr.text.include?("Plain ranked") }
      expect(plain_row.text).not_to include("review")
    end
  end
end
