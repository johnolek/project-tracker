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

    it "requires an email address" do
      post signup_options_path, params: { username: "eve" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    describe "email-only (passkey optional)" do
      it "creates an account and emails a link without signing in or a passkey" do
        expect { post signup_path, params: { username: "emailer", email: "emailer@example.com" } }
          .to change(User, :count).by(1)
          .and change { ActionMailer::Base.deliveries.count }.by(1)

        user = User.find_by(username: "emailer")
        expect(user.credentials).to be_empty
        expect(user.email_verified?).to be(false)
        expect(response).to redirect_to(login_path)

        # Not signed in yet — the emailed link verifies and signs in.
        get projects_path
        expect(response).to redirect_to(login_path)
      end

      it "re-renders with errors on a duplicate username" do
        create(:user, username: "taken", email: "taken@example.com")

        expect { post signup_path, params: { username: "taken", email: "fresh@example.com" } }
          .not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "requires an email" do
        expect { post signup_path, params: { username: "noemail" } }.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "sign in" do
    it "authenticates a registered passkey without a username" do
      client = WebAuthn::FakeClient.new(webauthn_origin)
      register_passkey(username: "bob", client: client)

      # Drop the authenticated session so we exercise a real sign-in.
      delete logout_path

      authenticate_passkey(client: client)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["redirect_url"]).to eq(root_path)

      get projects_path
      expect(response).to have_http_status(:ok)
    end

    it "rejects a sign-in with no pending challenge" do
      post login_path, params: { credential: { type: "public-key" } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
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

  describe "signed-in navbar" do
    it "renders the username as a dropdown holding API keys and Sign out" do
      register_passkey(username: "dana")

      get projects_path
      expect(response).to have_http_status(:ok)

      page = Nokogiri::HTML(response.body)
      dropdown = page.at_css(".navbar-end .navbar-item.has-dropdown")
      expect(dropdown).to be_present

      trigger = dropdown.at_css(".navbar-link")
      expect(trigger).to be_present
      expect(trigger.text.strip).to eq("dana")
      expect(trigger["aria-expanded"]).to eq("false")

      menu = dropdown.at_css(".navbar-dropdown")
      expect(menu).to be_present

      api_keys_link = menu.at_css("a[href='#{settings_api_keys_path}']")
      expect(api_keys_link).to be_present
      expect(api_keys_link.text.strip).to eq("API keys")

      sign_out = menu.at_css("form[action='#{logout_path}'] button.navbar-item")
      expect(sign_out).to be_present
      expect(sign_out.text.strip).to eq("Sign out")

      # The API keys link and Sign out control now live only inside the dropdown,
      # not as bare navbar items alongside it.
      expect(page.css(".navbar-end > a[href='#{settings_api_keys_path}']")).to be_empty
      expect(page.css(".navbar-end > .navbar-item > form[action='#{logout_path}']")).to be_empty
    end
  end
end
