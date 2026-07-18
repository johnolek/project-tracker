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

      it "ships each candidate's notes as rendered rich-text HTML" do
        create(:item, project: project, title: "Rich A", notes: "<p>Water <strong>deeply</strong> before noon</p>")
        create(:item, project: project, title: "Rich B", notes: "<p>Plain enough</p>")

        get prioritize_project_path(project, format: :json)

        notes = response.parsed_body["pair"].map { |item| item["notes_html"] }.join
        expect(notes).to include("<strong>deeply</strong>")
        expect(notes).not_to include("truncate")
      end

      it "seeds the island props with the pin from a pinned_item_id deep link" do
        anchor = create(:item, project: project, title: "Anchor me")
        create(:item, project: project, title: "Opponent one")
        create(:item, project: project, title: "Opponent two")

        get prioritize_project_path(project, pinned_item_id: anchor.id)

        island = Nokogiri::HTML(response.body).at_css('[data-svelte-component="Prioritize"]')
        props = JSON.parse(island["data-props"])
        expect(props["pinned"]["id"]).to eq(anchor.id)
        expect(props["pinnedCount"]).to eq(0)
        expect(props["pair"].first["id"]).to eq(anchor.id)
      end

      it "exposes each candidate's key and its item-page and move urls (JSON)" do
        first = create(:item, project: project, title: "First")
        create(:item, project: project, title: "Second")

        get prioritize_project_path(project, format: :json)

        item = response.parsed_body["pair"].find { |candidate| candidate["id"] == first.id }
        expect(item["key"]).to eq(first.key)
        expect(item["url"]).to eq(project_item_path(project, first))
        expect(item["move_url"]).to eq(move_project_item_path(project, first))
      end

      it "exposes the org's done status id in the island props" do
        create(:item, project: project, title: "First")
        create(:item, project: project, title: "Second")

        get prioritize_project_path(project)

        island = Nokogiri::HTML(response.body).at_css('[data-svelte-component="Prioritize"]')
        props = JSON.parse(island["data-props"])
        expect(props["doneStatusId"]).to eq(organization.statuses.find_by(category: "done").id)
      end

      it "excludes an item from the next pair once it is moved to done via its move url" do
        keep_one = create(:item, project: project, title: "Keep one")
        keep_two = create(:item, project: project, title: "Keep two")
        retire = create(:item, project: project, title: "Retire me")
        done_status = organization.statuses.find_by(category: "done")

        patch move_project_item_path(project, retire), params: { status_id: done_status.id }, as: :json
        expect(response).to have_http_status(:no_content)

        get prioritize_project_path(project, format: :json)

        ids = response.parsed_body["pair"].map { |item| item["id"] }
        expect(ids).not_to include(retire.id)
        expect(ids).to all(be_in([ keep_one.id, keep_two.id ]))
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

    describe "pinning an item to compare against many others (JSON)" do
      let!(:pinned) { create(:item, project: project, title: "Anchor") }
      let!(:rival_one) { create(:item, project: project, title: "Rival one") }
      let!(:rival_two) { create(:item, project: project, title: "Rival two") }
      let!(:rival_three) { create(:item, project: project, title: "Rival three") }

      it "always returns the pinned item as item A while the opponent varies among the rest" do
        opponents = []

        15.times do
          get prioritize_project_path(project, format: :json), params: { pinned_item_id: pinned.id }

          payload = response.parsed_body
          expect(payload["pinned_id"]).to eq(pinned.id)
          expect(payload["pair"].first["id"]).to eq(pinned.id)

          opponent_id = payload["pair"].last["id"]
          expect(opponent_id).not_to eq(pinned.id)
          expect([ rival_one, rival_two, rival_three ].map(&:id)).to include(opponent_id)
          opponents << opponent_id
        end

        expect(opponents.uniq.size).to be > 1
      end

      it "echoes the pinned item's running comparison total as pinned_count" do
        create(:comparison, project: project, item_a: pinned, item_b: rival_one, outcome: "a_wins")
        create(:comparison, project: project, item_a: rival_two, item_b: pinned, outcome: "a_wins")

        get prioritize_project_path(project, format: :json), params: { pinned_item_id: pinned.id }

        expect(response.parsed_body["pinned_count"]).to eq(2)
      end

      it "returns a null pair but still echoes the pin when no opponent is left" do
        solo_project = organization.projects.create!(name: "Solo")
        only = create(:item, project: solo_project, title: "Only one")

        get prioritize_project_path(solo_project, format: :json), params: { pinned_item_id: only.id }

        payload = response.parsed_body
        expect(payload["pair"]).to be_nil
        expect(payload["pinned_id"]).to eq(only.id)
        expect(payload["pinned_count"]).to eq(0)
      end

      it "falls back to normal pairing for an unknown pinned_item_id" do
        get prioritize_project_path(project, format: :json), params: { pinned_item_id: 0 }

        payload = response.parsed_body
        expect(payload["pinned_id"]).to be_nil
        expect(payload["pinned_count"]).to be_nil
        expect(payload["pair"].size).to eq(2)
      end

      it "falls back to normal pairing for a done pinned item" do
        done_status = organization.statuses.find_by(category: "done")
        finished = create(:item, project: project, title: "Finished", status: done_status)

        get prioritize_project_path(project, format: :json), params: { pinned_item_id: finished.id }

        payload = response.parsed_body
        expect(payload["pinned_id"]).to be_nil
        expect(payload["pair"].map { |item| item["id"] }).not_to include(finished.id)
      end

      it "falls back to normal pairing for another project's item" do
        other_project = organization.projects.create!(name: "Elsewhere")
        foreign = create(:item, project: other_project, title: "Foreign anchor")

        get prioritize_project_path(project, format: :json), params: { pinned_item_id: foreign.id }

        payload = response.parsed_body
        expect(payload["pinned_id"]).to be_nil
        expect(payload["pair"].map { |item| item["id"] }).not_to include(foreign.id)
      end

      it "keeps the pinned item in the next pair after recording a comparison" do
        post project_comparisons_path(project),
             params: { item_a_id: pinned.id, item_b_id: rival_one.id, outcome: "a_wins", pinned_item_id: pinned.id },
             as: :json

        expect(response).to have_http_status(:ok)
        payload = response.parsed_body
        expect(payload["pinned_id"]).to eq(pinned.id)
        expect(payload["pinned_count"]).to eq(1)
        expect(payload["pair"].first["id"]).to eq(pinned.id)
        expect(payload["pair"].last["id"]).not_to eq(pinned.id)
      end
    end

    describe "filtering the candidate pool" do
      it "returns only items of the requested type (JSON)" do
        bug_one = create(:item, project: project, title: "Bug one", item_type: "bug")
        bug_two = create(:item, project: project, title: "Bug two", item_type: "bug")
        create(:item, project: project, title: "A task", item_type: "task")

        get prioritize_project_path(project, format: :json), params: { item_type: "bug" }

        ids = response.parsed_body["pair"].map { |item| item["id"] }
        expect(ids).to match_array([ bug_one.id, bug_two.id ])
      end

      it "excludes unpointed items once a minimum is set" do
        big = create(:item, project: project, title: "Big", points: 8)
        medium = create(:item, project: project, title: "Medium", points: 5)
        create(:item, project: project, title: "Unestimated")

        get prioritize_project_path(project, format: :json), params: { min_points: 3 }

        ids = response.parsed_body["pair"].map { |item| item["id"] }
        expect(ids).to match_array([ big.id, medium.id ])
      end

      it "passes unpointed items under a maximum" do
        small = create(:item, project: project, title: "Small", points: 2)
        create(:item, project: project, title: "Huge", points: 13)
        unpointed = create(:item, project: project, title: "Unestimated")

        get prioritize_project_path(project, format: :json), params: { max_points: 3 }

        ids = response.parsed_body["pair"].map { |item| item["id"] }
        expect(ids).to match_array([ small.id, unpointed.id ])
      end

      it "requires every selected tag (AND semantics)" do
        both = create(:item, project: project, title: "Both tags", tag_names: [ "urgent", "backend" ])
        create(:item, project: project, title: "One tag", tag_names: [ "urgent" ])
        also_both = create(:item, project: project, title: "Also both", tag_names: [ "backend", "urgent" ])

        get prioritize_project_path(project, format: :json), params: { tags: [ "urgent", "backend" ] }

        ids = response.parsed_body["pair"].map { |item| item["id"] }
        expect(ids).to match_array([ both.id, also_both.id ])
      end

      it "restricts the pool to the requested statuses" do
        in_progress = organization.statuses.find_by(name: "In Progress")
        first = create(:item, project: project, title: "In progress A", status: in_progress)
        second = create(:item, project: project, title: "In progress B", status: in_progress)
        create(:item, project: project, title: "Still new")

        get prioritize_project_path(project, format: :json), params: { status_ids: [ in_progress.id ] }

        ids = response.parsed_body["pair"].map { |item| item["id"] }
        expect(ids).to match_array([ first.id, second.id ])
      end

      it "keeps the next pair within the filtered set after recording" do
        bug_a = create(:item, project: project, title: "Bug A", item_type: "bug")
        bug_b = create(:item, project: project, title: "Bug B", item_type: "bug")
        bug_c = create(:item, project: project, title: "Bug C", item_type: "bug")
        create(:item, project: project, title: "A task", item_type: "task")

        post project_comparisons_path(project),
             params: { item_a_id: bug_a.id, item_b_id: bug_b.id, outcome: "a_wins", item_type: "bug" },
             as: :json

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["pair"].map { |item| item["id"] }
        expect(ids).to all(be_in([ bug_a.id, bug_b.id, bug_c.id ]))
      end

      it "honors a pin outside the filters while its opponent respects them" do
        task_anchor = create(:item, project: project, title: "Task anchor", item_type: "task")
        bug_one = create(:item, project: project, title: "Bug one", item_type: "bug")
        bug_two = create(:item, project: project, title: "Bug two", item_type: "bug")
        create(:item, project: project, title: "Other task", item_type: "task")

        get prioritize_project_path(project, format: :json),
            params: { pinned_item_id: task_anchor.id, item_type: "bug" }

        payload = response.parsed_body
        expect(payload["pinned_id"]).to eq(task_anchor.id)
        expect(payload["pair"].first["id"]).to eq(task_anchor.id)
        expect([ bug_one.id, bug_two.id ]).to include(payload["pair"].last["id"])
      end

      it "returns a null pair when fewer than two items match" do
        create(:item, project: project, title: "Lonely bug", item_type: "bug")
        create(:item, project: project, title: "A task", item_type: "task")
        create(:item, project: project, title: "Another task", item_type: "task")

        get prioritize_project_path(project, format: :json), params: { item_type: "bug" }

        expect(response.parsed_body["pair"]).to be_nil
      end

      it "ignores unparseable filters rather than emptying the pool" do
        first = create(:item, project: project, title: "First")
        second = create(:item, project: project, title: "Second")

        get prioritize_project_path(project, format: :json),
            params: { min_points: "abc", status_ids: [ 999_999 ], item_type: "nonsense" }

        ids = response.parsed_body["pair"].map { |item| item["id"] }
        expect(ids).to match_array([ first.id, second.id ])
      end

      it "exposes the filter vocabulary in the island props" do
        create(:item, project: project, title: "Tagged", tag_names: [ "zeta", "alpha" ])
        create(:item, project: project, title: "Second")

        get prioritize_project_path(project)

        island = Nokogiri::HTML(response.body).at_css('[data-svelte-component="Prioritize"]')
        props = JSON.parse(island["data-props"])
        expect(props["itemTypes"]).to eq(Item::ITEM_TYPES)
        expect(props["allTags"]).to eq([ "alpha", "zeta" ])
        expect(props["statuses"].map { |status| status["name"] }).to eq([ "New", "In Progress", "Needs Verification" ])
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
