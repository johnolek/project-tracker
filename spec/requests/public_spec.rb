require "rails_helper"

RSpec.describe "Public project surface", type: :request do
  let(:project) { create(:project) }

  describe "GET /p/:public_token" do
    it "renders the read-only board without authentication" do
      status = project.organization.default_status
      project.items.create!(title: "Visible item", status: status)

      get public_project_path(project.public_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(project.name)
      expect(response.body).to include("Visible item")
      expect(response.body).to include("New")
    end

    it "returns 404 for an unknown token" do
      get public_project_path("does-not-exist")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /p/:public_token/submit" do
    it "creates an external-source item in the default status" do
      expect do
        post public_submissions_path(project.public_token),
             params: { item: { title: "Great idea", notes: "Details", item_type: "idea" }, submitter_name: "Jane" }
      end.to change(project.items, :count).by(1)

      item = project.items.last
      expect(item.source).to eq("external")
      expect(item.item_type).to eq("idea")
      expect(item.status).to eq(project.organization.default_status)
      expect(response).to redirect_to(public_project_path(project.public_token))
    end

    it "coerces a disallowed submission type to idea" do
      post public_submissions_path(project.public_token),
           params: { item: { title: "Sneaky", item_type: "enhancement" } }

      expect(project.items.last.item_type).to eq("idea")
    end

    it "silently rejects submissions that trip the honeypot" do
      expect do
        post public_submissions_path(project.public_token),
             params: { item: { title: "Spam" }, website: "http://spam.example" }
      end.not_to change(Item, :count)

      expect(response).to redirect_to(public_project_path(project.public_token))
    end

    it "returns 404 for an unknown token" do
      post public_submissions_path("does-not-exist"), params: { item: { title: "x" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /p/:public_token/submit" do
    it "renders the submission form without authentication" do
      get new_public_submission_path(project.public_token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Submit")
    end
  end
end
