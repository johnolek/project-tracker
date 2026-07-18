require "rails_helper"

RSpec.describe "Settings::Statuses", type: :request do
  context "when signed out" do
    it "redirects the index to the login page" do
      get settings_statuses_path
      expect(response).to redirect_to(login_path)
    end

    it "redirects a create to the login page" do
      post settings_statuses_path, params: { status: { name: "X", category: "open" } }
      expect(response).to redirect_to(login_path)
    end
  end

  context "when signed in" do
    before { register_passkey(username: "boarder") }

    let(:user) { User.find_by(username: "boarder") }
    let(:organization) { user.default_organization }

    def status_named(name)
      organization.statuses.find_by!(name: name)
    end

    def ordered_names
      organization.statuses.ordered.pluck(:name)
    end

    it "lists statuses ordered by position" do
      get settings_statuses_path

      expect(response).to have_http_status(:ok)
      expect(ordered_names).to eq([ "New", "In Progress", "Needs Verification", "Completed" ])
      %w[New In\ Progress Needs\ Verification Completed].each do |name|
        expect(response.body).to include(name)
      end
    end

    describe "create" do
      it "appends a new status at the end of the order" do
        expect do
          post settings_statuses_path, params: { status: { name: "Blocked", category: "in_progress" } }
        end.to change(organization.statuses, :count).by(1)

        expect(response).to redirect_to(settings_statuses_path)
        blocked = status_named("Blocked")
        expect(blocked.category).to eq("in_progress")
        expect(blocked.position).to eq(5)
      end

      it "re-renders with 422 for a blank name" do
        expect do
          post settings_statuses_path, params: { status: { name: "", category: "open" } }
        end.not_to change(organization.statuses, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("can&#39;t be blank").or include("can't be blank")
      end
    end

    describe "update" do
      it "renames a status" do
        status = status_named("New")

        patch settings_status_path(status), params: { status: { name: "Backlog", category: status.category } }

        expect(response).to redirect_to(settings_statuses_path)
        expect(status.reload.name).to eq("Backlog")
      end

      it "changes a status category" do
        status = status_named("New")

        patch settings_status_path(status), params: { status: { name: status.name, category: "in_progress" } }

        expect(response).to redirect_to(settings_statuses_path)
        expect(status.reload.category).to eq("in_progress")
      end

      it "redirects with an alert for a blank name" do
        status = status_named("New")

        patch settings_status_path(status), params: { status: { name: "" } }

        expect(response).to redirect_to(settings_statuses_path)
        expect(flash[:alert]).to be_present
        expect(status.reload.name).to eq("New")
      end
    end

    describe "destroy" do
      it "deletes an unused status" do
        status = status_named("Needs Verification")

        expect do
          delete settings_status_path(status)
        end.to change(organization.statuses, :count).by(-1)

        expect(response).to redirect_to(settings_statuses_path)
      end

      it "blocks deletion with the restrict message when items use the status" do
        status = status_named("New")
        project = organization.projects.create!(name: "Tracker")
        project.items.create!(title: "Uses status", item_type: "feature", status: status)

        expect do
          delete settings_status_path(status)
        end.not_to change(organization.statuses, :count)

        expect(response).to redirect_to(settings_statuses_path)
        expect(flash[:alert]).to eq("Cannot delete record because dependent items exist")
      end
    end

    describe "move" do
      it "swaps positions with the next status when moving down" do
        in_progress = status_named("In Progress")

        patch move_settings_status_path(in_progress, direction: "down")

        expect(response).to redirect_to(settings_statuses_path)
        expect(ordered_names).to eq([ "New", "Needs Verification", "In Progress", "Completed" ])
      end

      it "swaps positions with the previous status when moving up" do
        completed = status_named("Completed")

        patch move_settings_status_path(completed, direction: "up")

        expect(response).to redirect_to(settings_statuses_path)
        expect(ordered_names).to eq([ "New", "In Progress", "Completed", "Needs Verification" ])
      end

      it "is a no-op when moving the first status up" do
        new_status = status_named("New")

        patch move_settings_status_path(new_status, direction: "up")

        expect(response).to redirect_to(settings_statuses_path)
        expect(ordered_names).to eq([ "New", "In Progress", "Needs Verification", "Completed" ])
      end
    end

    describe "organization isolation" do
      let(:foreign_status) { create(:status, name: "Foreign", position: 9) }

      it "404s when acting on another organization's status" do
        patch settings_status_path(foreign_status), params: { status: { name: "Hacked" } }
        expect(response).to have_http_status(:not_found)
        expect(foreign_status.reload.name).to eq("Foreign")

        delete settings_status_path(foreign_status)
        expect(response).to have_http_status(:not_found)
        expect(Status.exists?(foreign_status.id)).to be(true)

        patch move_settings_status_path(foreign_status, direction: "up")
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
