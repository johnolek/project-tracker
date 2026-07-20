require "rails_helper"

RSpec.describe "API v1 statuses", type: :request do
  def status_named(name)
    api_organization.statuses.find_by!(name: name)
  end

  describe "GET /api/v1/statuses" do
    it "lists the organization's statuses ordered by position" do
      get api_v1_statuses_path, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body["statuses"]).to eq(
        api_organization.statuses.ordered.map do |status|
          {
            "id" => status.id,
            "name" => status.name,
            "category" => status.category,
            "position" => status.position
          }
        end
      )
      expect(json_body["statuses"].map { |status| status["name"] }).to eq(
        [ "New", "In Progress", "Needs Verification", "Completed" ]
      )
    end

    it "401s without a token" do
      get api_v1_statuses_path

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/statuses" do
    it "creates a status appended at the end of the order" do
      expect do
        post api_v1_statuses_path, params: { status: { name: "Blocked", category: "in_progress" } }, headers: auth_headers
      end.to change(api_organization.statuses, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_body).to include("name" => "Blocked", "category" => "in_progress", "position" => 5)
      expect(json_body.keys).to match_array(%w[id name category position])
    end

    it "honours an explicit unused position" do
      post api_v1_statuses_path, params: { status: { name: "Triage", category: "open", position: 42 } }, headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(json_body["position"]).to eq(42)
    end

    it "rejects a position already in use" do
      post api_v1_statuses_path, params: { status: { name: "Triage", category: "open", position: 1 } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["errors"]).to include("Position has already been taken")
    end

    it "returns validation errors for a blank name" do
      post api_v1_statuses_path, params: { status: { name: "", category: "open" } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["errors"]).to include("Name can't be blank")
    end

    it "returns validation errors for an invalid category" do
      post api_v1_statuses_path, params: { status: { name: "Nope", category: "bogus" } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["errors"]).to include("Category is not included in the list")
    end

    it "returns 422 when the status param is missing" do
      post api_v1_statuses_path, params: {}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["error"]).to include("status")
    end
  end

  describe "PATCH /api/v1/statuses/:id" do
    it "renames a status and changes its category" do
      status = status_named("New")

      patch api_v1_status_path(status), params: { status: { name: "Backlog", category: "in_progress" } }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body).to include("name" => "Backlog", "category" => "in_progress")
      expect(status.reload.name).to eq("Backlog")
    end

    it "returns validation errors for a blank name" do
      status = status_named("New")

      patch api_v1_status_path(status), params: { status: { name: "" } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["errors"]).to include("Name can't be blank")
      expect(status.reload.name).to eq("New")
    end
  end

  describe "DELETE /api/v1/statuses/:id" do
    it "destroys an unused status" do
      status = status_named("Needs Verification")

      expect do
        delete api_v1_status_path(status), headers: auth_headers
      end.to change(api_organization.statuses, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 422 with the restrict message when items still use the status" do
      status = status_named("New")
      project = api_organization.projects.create!(name: "Tracker")
      project.items.create!(title: "Uses status", status: status)

      expect do
        delete api_v1_status_path(status), headers: auth_headers
      end.not_to change(api_organization.statuses, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["error"]).to eq("Cannot delete record because dependent items exist")
    end
  end

  describe "cross-organization isolation" do
    let(:other_key) { create(:api_key) }

    it "404s on update and destroy of another organization's status" do
      foreign_status = status_named("New")

      patch api_v1_status_path(foreign_status), params: { status: { name: "Hacked" } }, headers: auth_headers(other_key)
      expect(response).to have_http_status(:not_found)
      expect(foreign_status.reload.name).to eq("New")

      delete api_v1_status_path(foreign_status), headers: auth_headers(other_key)
      expect(response).to have_http_status(:not_found)
      expect(Status.exists?(foreign_status.id)).to be(true)
    end
  end
end
