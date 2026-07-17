require "rails_helper"

RSpec.describe "Passkey authentication", type: :request do
  describe "registration" do
    it "creates a user with a passkey and signs them in" do
      expect do
        register_passkey(username: "alice")
      end.to change(User, :count).by(1).and change(Credential, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["redirect_url"]).to eq(root_path)

      user = User.find_by(username: "alice")
      expect(user.default_organization).to be_present

      # Session is authenticated: a login-required page now renders.
      get projects_path
      expect(response).to have_http_status(:ok)
    end

    it "rejects a duplicate username" do
      create(:user, username: "alice")

      post signup_options_path, params: { username: "alice" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a duplicate username that differs only in case" do
      create(:user, username: "alice")

      post signup_options_path, params: { username: "ALICE" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "sign in" do
    it "authenticates a registered passkey" do
      client = WebAuthn::FakeClient.new(webauthn_origin)
      register_passkey(username: "bob", client: client)

      # Drop the authenticated session so we exercise a real sign-in.
      delete logout_path

      authenticate_passkey(username: "bob", client: client)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["redirect_url"]).to eq(root_path)

      get projects_path
      expect(response).to have_http_status(:ok)
    end

    it "rejects an unknown username" do
      post login_options_path, params: { username: "nobody" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "authenticates regardless of username casing" do
      client = WebAuthn::FakeClient.new(webauthn_origin)
      register_passkey(username: "Bob", client: client)
      delete logout_path

      authenticate_passkey(username: "bob", client: client)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["redirect_url"]).to eq(root_path)
    end
  end

  describe "sign out" do
    it "clears the session" do
      register_passkey(username: "carol")

      delete logout_path
      expect(response).to redirect_to(login_path)

      get projects_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "authentication requirement" do
    it "redirects anonymous users away from projects" do
      get projects_path
      expect(response).to redirect_to(login_path)
    end
  end
end
