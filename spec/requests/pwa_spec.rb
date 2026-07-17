require "rails_helper"

RSpec.describe "PWA", type: :request do
  describe "GET /manifest.json" do
    it "renders the manifest as JSON while signed out" do
      get pwa_manifest_path(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")

      manifest = response.parsed_body
      expect(manifest["name"]).to eq("Project Tracker")
      expect(manifest["icons"]).to be_present
      expect(manifest["icons"].size).to be >= 1
    end
  end

  describe "GET /service-worker.js" do
    it "renders the service worker as JavaScript while signed out" do
      get pwa_service_worker_path(format: :js)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to include("javascript")
    end
  end
end
