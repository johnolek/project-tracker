require "rails_helper"

RSpec.describe "Settings::ApiKeys", type: :request do
  context "when signed out" do
    it "redirects to the login page" do
      get settings_api_keys_path
      expect(response).to redirect_to(login_path)
    end
  end

  context "when signed in" do
    before { register_passkey(username: "keyholder") }

    let(:user) { User.find_by(username: "keyholder") }

    it "lists API keys" do
      create(:api_key, user: user, name: "Deploy bot")

      get settings_api_keys_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Deploy bot")
    end

    it "creates a key and shows the plaintext token once" do
      expect do
        post settings_api_keys_path, params: { api_key: { name: "CI" } }
      end.to change(user.api_keys, :count).by(1)

      expect(response).to redirect_to(settings_api_keys_path)
      follow_redirect!
      expect(response.body).to match(/pt_[a-zA-Z0-9]{32}/)

      get settings_api_keys_path
      expect(response.body).not_to match(/pt_[a-zA-Z0-9]{32}/)
    end

    it "offers a copy-to-clipboard button carrying the new token" do
      post settings_api_keys_path, params: { api_key: { name: "CI" } }
      follow_redirect!

      expect(response.body).to match(/data-clipboard-text="pt_[a-zA-Z0-9]{32}"/)
      expect(response.body).to include("Copy to clipboard")
    end

    it "keeps the api_key_token flash out of the Toasts island props" do
      post settings_api_keys_path, params: { api_key: { name: "CI" } }
      follow_redirect!

      toast_props = response.body[/data-svelte-component="Toasts" data-props="([^"]*)"/, 1]

      expect(toast_props).to be_present
      # The "API key created." notice still surfaces as a toast...
      expect(toast_props).to include("&quot;message&quot;:&quot;API key created.&quot;")
      # ...but the secret token (shown inline by the view) never leaks into props.
      expect(toast_props).not_to include("api_key_token")
      expect(toast_props).not_to match(/pt_[a-zA-Z0-9]{32}/)
      # It is still rendered inline elsewhere on the page.
      expect(response.body).to match(/pt_[a-zA-Z0-9]{32}/)
    end

    it "revokes a key" do
      api_key = create(:api_key, user: user)

      expect do
        delete settings_api_key_path(api_key)
      end.to change(user.api_keys, :count).by(-1)

      expect(response).to redirect_to(settings_api_keys_path)
    end

    it "renders 422 for a blank name" do
      expect do
        post settings_api_keys_path, params: { api_key: { name: "" } }
      end.not_to change(ApiKey, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
